# frozen_string_literal: true

require 'net/ssh'
require 'net/scp'
require 'pathname'

module Kdeploy
  # SSH/SCP executor for remote command execution and file operations
  class Executor
    def initialize(host_config)
      @host = host_config[:name]
      @user = host_config[:user]
      @ip = host_config[:ip]
      @password = host_config[:password]
      @key = host_config[:key]
      @port = host_config[:port] # 新增端口支持
      @use_sudo = host_config[:use_sudo] || false
      @sudo_password = host_config[:sudo_password]
      @base_dir = host_config[:base_dir] # Base directory for resolving relative paths
    end

    def execute(command, use_sudo: nil)
      use_sudo = @use_sudo if use_sudo.nil?
      command = wrap_with_sudo(command) if use_sudo

      Net::SSH.start(@ip, @user, ssh_options) do |ssh|
        execute_command_on_ssh(ssh, command)
      end
    rescue Net::SSH::AuthenticationFailed => e
      raise SSHError.new("SSH authentication failed: #{e.message}", e)
    rescue StandardError => e
      raise SSHError.new("SSH execution failed: #{e.message}", e)
    end

    def execute_command_on_ssh(ssh, command)
      stdout = String.new
      stderr = String.new

      ssh.open_channel do |channel|
        channel.exec(command) do |_ch, success|
          raise SSHError, "Could not execute command: #{command}" unless success

          setup_channel_handlers(channel, stdout, stderr)
        end
      end
      ssh.loop
      build_command_result(stdout, stderr, command)
    end

    def setup_channel_handlers(channel, stdout, stderr)
      channel.on_data do |_ch, data|
        stdout << data
      end

      channel.on_extended_data do |_ch, _type, data|
        stderr << data
      end
    end

    def build_command_result(stdout, stderr, command)
      {
        stdout: stdout.strip,
        stderr: stderr.strip,
        command: command
      }
    end

    def upload(source, destination, use_sudo: nil)
      use_sudo = @use_sudo if use_sudo.nil?

      # Resolve relative paths relative to base_dir
      resolved_source = resolve_path(source)

      # If destination requires sudo, upload to temp location first, then move with sudo
      if use_sudo || requires_sudo?(destination)
        upload_with_sudo(resolved_source, destination)
      else
        Net::SCP.start(@ip, @user, ssh_options) do |scp|
          scp.upload!(resolved_source, destination)
        end
      end
    rescue StandardError => e
      raise SCPError.new("SCP upload failed: #{e.message}", e)
    end

    def upload_template(source, destination, variables = {})
      # Resolve relative paths relative to base_dir
      resolved_source = resolve_path(source)
      Template.render_and_upload(self, resolved_source, destination, variables)
    rescue StandardError => e
      raise TemplateError.new("Template upload failed: #{e.message}", e)
    end

    private

    def upload_with_sudo(source, destination)
      # Generate a unique temp file name
      temp_dest = "/tmp/kdeploy_#{File.basename(destination)}_#{Time.now.to_i}_#{rand(10_000)}"

      # Upload to temp location first
      Net::SCP.start(@ip, @user, ssh_options) do |scp|
        scp.upload!(source, temp_dest)
      end

      # Move to final destination with sudo
      move_command = "mv #{temp_dest} #{destination}"
      execute(move_command, use_sudo: true)
    rescue StandardError => e
      # Try to clean up temp file if it exists
      begin
        execute("rm -f #{temp_dest}", use_sudo: false) if defined?(temp_dest)
      rescue StandardError
        # Ignore cleanup errors
      end
      raise SCPError.new("SCP upload failed: #{e.message}", e)
    end

    def resolve_path(path)
      # If path is absolute, return as is
      return path if Pathname.new(path).absolute?

      # If base_dir is set, resolve relative to base_dir
      if @base_dir
        File.expand_path(path, @base_dir)
      else
        # Otherwise, resolve relative to current working directory
        File.expand_path(path)
      end
    end

    def requires_sudo?(path)
      # Check if path is in system directories that typically require sudo
      system_dirs = %w[/etc /usr /var /opt /sbin /bin /lib /lib64 /root]
      system_dirs.any? { |dir| path.start_with?(dir) }
    end

    def ssh_options
      options = base_ssh_options
      add_authentication(options)
      add_port_option(options)
      options
    end

    def base_ssh_options
      {
        verify_host_key: Configuration.default_verify_host_key,
        timeout: Configuration.default_ssh_timeout
      }
    end

    def add_authentication(options)
      if @password
        options[:password] = @password
      elsif @key
        options[:keys] = [@key]
      end
    end

    def add_port_option(options)
      options[:port] = @port if @port
    end

    def wrap_with_sudo(command)
      # 如果命令已经以 sudo 开头，不重复添加
      return command if command.strip.start_with?('sudo')

      # 对于多行命令或包含 shell 控制结构的命令，使用 bash -c 包装
      is_multiline = command.include?("\n") || command.match?(/\b(if|for|while|case|function)\b/)

      if is_multiline
        # 转义命令中的单引号，然后用 bash -c 执行
        escaped_command = command.gsub("'", "'\"'\"'")
        if @sudo_password
          escaped_password = @sudo_password.gsub('\'', "'\"'\"'").gsub('$', '\\$').gsub('`', '\\`')
          "echo '#{escaped_password}' | sudo -S bash -c '#{escaped_command}'"
        else
          "sudo bash -c '#{escaped_command}'"
        end
      elsif @sudo_password
        # 单行命令直接包装
        escaped_password = @sudo_password.gsub('\'', "'\"'\"'").gsub('$', '\\$').gsub('`', '\\`')
        "echo '#{escaped_password}' | sudo -S #{command}"
      else
        "sudo #{command}"
      end
    end
  end
end
