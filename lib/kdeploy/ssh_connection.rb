# frozen_string_literal: true

require 'net/ssh'
require 'net/scp'
require 'timeout'
require 'open3'
require 'fileutils'

module Kdeploy
  class SSHConnection
    attr_reader :host, :session

    def initialize(host)
      @host = host
      @session = nil
      @connected = false
      @mutex = Mutex.new
    end

    # 建立SSH连接
    def connect
      return if connected?

      @mutex.synchronize do
        return if connected?

        Config.logger.debug("Connecting to #{@host}")

        begin
          @session = Net::SSH.start(
            @host.hostname,
            @host.user,
            port: @host.port,
            **@host.connection_options
          )
          @connected = true
          Config.logger.debug("Connected to #{@host}")
        rescue Net::SSH::AuthenticationFailed => e
          raise ExecutionError, "SSH authentication failed for #{@host}: #{e.message}"
        rescue Net::SSH::ConnectionTimeout => e
          raise ExecutionError, "SSH connection timed out for #{@host}: #{e.message}"
        rescue StandardError => e
          raise ExecutionError, "SSH connection failed for #{@host}: #{e.message}"
        end
      end
    end

    # 检查连接状态
    def connected?
      @connected && @session && !@session.closed?
    end

    # 执行命令
    def execute(command, options = {})
      return execute_local(command, options) if @host.hostname == 'localhost'

      ensure_connected

      result = {
        stdout: '',
        stderr: '',
        exit_code: nil,
        success: false
      }

      timeout = options[:timeout] || Config.command_timeout || 300

      Config.logger.debug("Executing on #{@host}: #{command}")

      begin
        Timeout.timeout(timeout) do
          channel = @session.open_channel do |ch|
            if options[:sudo]
              ch.request_pty
              ch.exec("sudo -p 'sudo password: ' #{command}")
            else
              ch.exec(command)
            end

            ch.on_data do |_ch, data|
              if options[:sudo] && data.include?('sudo password: ')
                _ch.send_data("#{options[:sudo_password]}\n")
              else
                result[:stdout] += data
              end
            end

            ch.on_extended_data do |_ch, _type, data|
              result[:stderr] += data
            end

            ch.on_request('exit-status') do |_ch, data|
              result[:exit_code] = data.read_long
            end
          end

          channel.wait
        end
      rescue Timeout::Error
        result[:stderr] = "Command timed out after #{timeout} seconds"
        result[:exit_code] = 1
      end

      result[:success] = result[:exit_code]&.zero? || false

      Config.logger.debug("Command completed on #{@host}: exit_code=#{result[:exit_code]}")

      result
    rescue Net::SSH::Exception => e
      Config.logger.error("SSH execution error on #{@host}: #{e.message}")
      {
        stdout: '',
        stderr: e.message,
        exit_code: 1,
        success: false
      }
    end

    # 上传文件
    def upload(local_path, remote_path, options = {})
      ensure_connected

      Config.logger.debug("Uploading #{local_path} to #{@host}:#{remote_path}")

      begin
        if options[:recursive]
          @session.scp.upload!(local_path, remote_path, recursive: true)
        else
          @session.scp.upload!(local_path, remote_path)
        end

        execute("chmod #{options[:mode]} #{remote_path}") if options[:mode]

        execute("chown #{options[:owner]} #{remote_path}") if options[:owner]

        Config.logger.debug("Upload completed: #{local_path} -> #{@host}:#{remote_path}")
        true
      rescue Net::SCP::Error => e
        Config.logger.error("Upload failed #{local_path} -> #{@host}:#{remote_path}: #{e.message}")
        false
      end
    end

    # 下载文件
    def download(remote_path, local_path, options = {})
      ensure_connected

      Config.logger.debug("Downloading #{@host}:#{remote_path} to #{local_path}")

      begin
        FileUtils.mkdir_p(File.dirname(local_path)) unless File.exist?(File.dirname(local_path))

        if options[:recursive]
          @session.scp.download!(remote_path, local_path, recursive: true)
        else
          @session.scp.download!(remote_path, local_path)
        end

        Config.logger.debug("Download completed: #{@host}:#{remote_path} -> #{local_path}")
        true
      rescue Net::SCP::Error => e
        Config.logger.error("Download failed #{@host}:#{remote_path} -> #{local_path}: #{e.message}")
        false
      end
    end

    # 检查文件是否存在
    def file_exists?(path)
      result = execute("test -f #{path}")
      result[:success]
    end

    # 检查目录是否存在
    def directory_exists?(path)
      result = execute("test -d #{path}")
      result[:success]
    end

    # 创建目录
    def mkdir(path, options = {})
      cmd = ['mkdir']
      cmd << '-p' if options[:parents]
      cmd << path
      result = execute(cmd.join(' '))
      result[:success]
    end

    # 删除文件
    def remove(path, options = {})
      cmd = ['rm']
      cmd << '-f' if options[:force]
      cmd << path
      result = execute(cmd.join(' '))
      result[:success]
    end

    # 删除目录
    def rmdir(path, options = {})
      cmd = ['rm', '-r']
      cmd << '-f' if options[:force]
      cmd << path
      result = execute(cmd.join(' '))
      result[:success]
    end

    # 修改文件权限
    def chmod(path, mode, options = {})
      cmd = ['chmod']
      cmd << '-R' if options[:recursive]
      cmd << mode.to_s
      cmd << path
      result = execute(cmd.join(' '))
      result[:success]
    end

    # 修改文件所有者
    def chown(path, user, group = nil, options = {})
      owner = group ? "#{user}:#{group}" : user
      cmd = ['chown']
      cmd << '-R' if options[:recursive]
      cmd << owner
      cmd << path
      result = execute(cmd.join(' '))
      result[:success]
    end

    # 读取文件内容
    def read_file(path)
      result = execute("cat #{path}")
      result[:success] ? result[:stdout] : nil
    end

    # 写入文件内容
    def write_file(path, content, options = {})
      temp_file = Tempfile.new('kdeploy')
      temp_file.write(content)
      temp_file.close

      success = upload(temp_file.path, path, options)
      temp_file.unlink
      success
    end

    # 追加文件内容
    def append_file(path, content, _options = {})
      temp_file = Tempfile.new('kdeploy')
      temp_file.write(content)
      temp_file.close

      result = execute("cat #{temp_file.path} >> #{path}")
      temp_file.unlink
      result[:success]
    end

    # 获取文件属性
    def stat(path)
      result = execute("stat -c '%A %U %G %s %Y' #{path}")
      return nil unless result[:success]

      mode, user, group, size, mtime = result[:stdout].strip.split
      {
        mode: mode,
        user: user,
        group: group,
        size: size.to_i,
        mtime: Time.at(mtime.to_i)
      }
    end

    # 获取文件列表
    def ls(path = '.')
      result = execute("ls -la #{path}")
      return [] unless result[:success]

      result[:stdout].lines[1..].map(&:strip)
    end

    # 关闭连接
    def disconnect
      return unless @session

      @mutex.synchronize do
        return unless @session

        @session.close unless @session.closed?
        @session = nil
        @connected = false
        Config.logger.debug("Disconnected from #{@host}")
      end
    end

    alias close disconnect

    # 清理连接
    def cleanup
      disconnect
    end

    private

    def ensure_connected
      connect unless connected?
      raise ExecutionError, "Not connected to #{@host}" unless connected?
    end

    def execute_local(command, _options = {})
      Config.logger.debug("Executing locally: #{command}")

      begin
        stdout, stderr, status = Open3.capture3(command)

        result = {
          stdout: stdout,
          stderr: stderr,
          exit_code: status.exitstatus,
          success: status.success?
        }

        Config.logger.debug("Local command completed: exit_code=#{result[:exit_code]}")

        result
      rescue StandardError => e
        Config.logger.error("Local execution error: #{e.message}")
        {
          stdout: '',
          stderr: e.message,
          exit_code: 1,
          success: false
        }
      end
    end
  end
end
