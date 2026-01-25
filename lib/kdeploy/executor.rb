# frozen_string_literal: true

require 'net/ssh'
require 'net/scp'
require 'pathname'
require 'find'
require 'shellwords'
require_relative 'file_filter'

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
      exit_status = nil

      ssh.open_channel do |channel|
        channel.exec(command) do |_ch, success|
          raise SSHError, "Could not execute command: #{command}" unless success

          setup_channel_handlers(channel, stdout, stderr)
          channel.on_request('exit-status') do |_ch, data|
            exit_status = data.read_long
          end
        end
      end
      ssh.loop
      raise_nonzero_exit!(command, exit_status, stdout, stderr)
      build_command_result(stdout, stderr, command, exit_status)
    end

    def setup_channel_handlers(channel, stdout, stderr)
      channel.on_data do |_ch, data|
        stdout << data
      end

      channel.on_extended_data do |_ch, _type, data|
        stderr << data
      end
    end

    def build_command_result(stdout, stderr, command, exit_status)
      {
        stdout: stdout.strip,
        stderr: stderr.strip,
        command: command,
        exit_status: exit_status
      }
    end

    def raise_nonzero_exit!(command, exit_status, stdout, stderr)
      return if exit_status.nil?
      return if exit_status.zero?

      raise SSHError.new(
        "Command exited with status #{exit_status}",
        nil,
        command: command,
        exit_status: exit_status,
        stdout: stdout.strip,
        stderr: stderr.strip
      )
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

    def sync_directory(source, destination, ignore: [], exclude: [], delete: false, use_sudo: nil)
      use_sudo = @use_sudo if use_sudo.nil?

      # Resolve relative paths relative to base_dir
      resolved_source = resolve_path(source)

      # Validate source directory
      raise FileNotFoundError, "Source directory not found: #{resolved_source}" unless File.directory?(resolved_source)

      # Create file filter
      all_patterns = ignore + exclude
      filter = FileFilter.new(ignore_patterns: all_patterns)

      # Collect files to sync
      files_to_sync = collect_files_to_sync(resolved_source, filter)

      # Upload files
      uploaded_count = 0
      source_path = Pathname.new(resolved_source)
      files_to_sync.each do |file_path|
        relative_path = Pathname.new(file_path).relative_path_from(source_path).to_s
        remote_path = File.join(destination, relative_path).gsub(%r{/+}, '/')

        # Ensure remote directory exists
        remote_dir = File.dirname(remote_path)
        ensure_remote_directory(remote_dir, use_sudo: use_sudo)

        # Upload file
        upload(file_path, remote_path, use_sudo: use_sudo)
        uploaded_count += 1
      end

      # Delete extra files if requested
      deleted_count = 0
      deleted_count = delete_extra_files(resolved_source, destination, filter, use_sudo: use_sudo) if delete

      {
        uploaded: uploaded_count,
        deleted: deleted_count,
        total: files_to_sync.size
      }
    rescue StandardError => e
      raise SCPError.new("Directory sync failed: #{e.message}", e)
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

    def collect_files_to_sync(source_dir, filter)
      files = []
      source_path = Pathname.new(source_dir)

      Find.find(source_dir) do |file_path|
        next if File.directory?(file_path)

        relative_path = Pathname.new(file_path).relative_path_from(source_path).to_s
        next if filter.ignored?(relative_path, source_dir)

        files << file_path
      end

      files
    end

    def ensure_remote_directory(remote_dir, use_sudo: nil)
      use_sudo = @use_sudo if use_sudo.nil?
      return if remote_dir.nil? || remote_dir.empty? || remote_dir == '.' || remote_dir == '/'

      # Create directory with -p flag to create parent directories
      mkdir_command = "mkdir -p #{remote_dir.shellescape}"
      execute(mkdir_command, use_sudo: use_sudo)
    rescue StandardError => e
      # Ignore errors if directory already exists
      error_msg = e.message.downcase
      unless error_msg.include?('exists') || error_msg.include?('file exists') || error_msg.include?('already exists')
        raise
      end
    end

    def delete_extra_files(source_dir, destination_dir, filter, use_sudo: nil)
      use_sudo = @use_sudo if use_sudo.nil?

      # Get list of remote files
      list_command = "find #{destination_dir.shellescape} -type f 2>/dev/null || true"
      result = execute(list_command, use_sudo: use_sudo)
      remote_files = result[:stdout].lines.map(&:strip).reject(&:empty?)

      # Get list of local files (relative paths)
      source_path = Pathname.new(source_dir)
      local_files = collect_files_to_sync(source_dir, filter).map do |file_path|
        relative_path = Pathname.new(file_path).relative_path_from(source_path).to_s
        File.join(destination_dir, relative_path).gsub(%r{/+}, '/')
      end

      # Find files to delete
      files_to_delete = remote_files - local_files

      # Delete extra files
      deleted_count = 0
      files_to_delete.each do |file_path|
        delete_command = "rm -f #{file_path.shellescape}"
        execute(delete_command, use_sudo: use_sudo)
        deleted_count += 1
      rescue StandardError
        # Ignore deletion errors
      end

      deleted_count
    end
  end
end
