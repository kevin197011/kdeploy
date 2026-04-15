# frozen_string_literal: true

require 'net/ssh'
require 'net/scp'
require 'pathname'
require 'find'
require 'shellwords'
require 'tempfile'
require 'concurrent'
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
      @port = host_config[:port] # Added custom port support
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

    def sync_directory(source, destination, ignore: [], exclude: [], delete: false, fast: nil, parallel: nil,
                       use_sudo: nil)
      use_sudo = @use_sudo if use_sudo.nil?

      # Resolve relative paths relative to base_dir
      resolved_source = resolve_path(source)

      # Validate source directory
      raise FileNotFoundError, "Source directory not found: #{resolved_source}" unless File.directory?(resolved_source)

      # Create file filter
      all_patterns = ignore + exclude
      filter = FileFilter.new(ignore_patterns: all_patterns)

      if fast
        rsync_result = sync_with_rsync(
          resolved_source,
          destination,
          ignore: ignore,
          exclude: exclude,
          delete: delete,
          use_sudo: use_sudo
        )
        return rsync_result if rsync_result
      end

      # Collect files to sync
      files_to_sync = collect_files_to_sync(resolved_source, filter)

      # Upload files
      uploaded_count = upload_files(
        files_to_sync,
        resolved_source,
        destination,
        parallel: parallel,
        use_sudo: use_sudo
      )

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

    def sync_with_rsync(source, destination, ignore:, exclude:, delete:, use_sudo:)
      return nil unless system('command -v rsync >/dev/null 2>&1')

      exclude_file = build_rsync_excludes(ignore + exclude)

      unless remote_rsync_available?
        File.delete(exclude_file) if exclude_file && File.exist?(exclude_file)
        return nil
      end

      begin
        rsync_cmd = build_rsync_command(source, destination, exclude_file, delete: delete, use_sudo: use_sudo)
        return nil unless system(rsync_cmd)

        {
          uploaded: 0,
          deleted: 0,
          total: 0,
          fast_path: 'rsync'
        }
      ensure
        File.delete(exclude_file) if exclude_file && File.exist?(exclude_file)
      end
    rescue StandardError
      nil
    end

    def build_rsync_excludes(patterns)
      patterns = Array(patterns).compact
      return nil if patterns.empty?

      file = Tempfile.new('kdeploy_rsync_excludes')
      patterns.each { |pattern| file.write("#{pattern}\n") }
      file.close
      file.path
    end

    def build_rsync_command(source, destination, exclude_file, delete:, use_sudo:)
      delete_flag = delete ? '--delete' : ''
      exclude_flag = exclude_file ? "--exclude-from='#{exclude_file}'" : ''
      ssh_cmd = build_rsync_ssh_command
      sudo_flag = if use_sudo || requires_sudo?(destination)
                    '--rsync-path="sudo rsync"'
                  else
                    ''
                  end
      parts = [
        'rsync -az',
        delete_flag,
        exclude_flag,
        sudo_flag,
        "-e \"#{ssh_cmd}\"",
        "#{Shellwords.escape(source)}/",
        "#{@user}@#{@ip}:#{Shellwords.escape(destination)}/"
      ].reject(&:empty?)
      parts.join(' ')
    end

    def build_rsync_ssh_command
      ssh = ['ssh']
      ssh << "-p #{@port}" if @port
      ssh << "-i #{Shellwords.escape(@key)}" if @key
      ssh.join(' ')
    end

    def remote_rsync_available?
      Net::SSH.start(@ip, @user, ssh_options) do |ssh|
        output = ssh.exec!('command -v rsync 2>/dev/null || true')
        return !output.to_s.strip.empty?
      end
    rescue StandardError
      false
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
      # Do not add sudo again if command already starts with sudo
      return command if command.strip.start_with?('sudo')

      # Wrap multi-line/control/compound commands so sudo applies to the full block
      needs_wrap = command.include?("\n") ||
                   command.match?(/\b(if|for|while|case|function)\b/) ||
                   command.match?(/\s(&&|\|\||;)\s/)

      if needs_wrap
        # Escape single quotes in command, then execute via bash -c
        escaped_command = command.gsub("'", "'\"'\"'")
        if @sudo_password
          escaped_password = @sudo_password.gsub('\'', "'\"'\"'").gsub('$', '\\$').gsub('`', '\\`')
          "echo '#{escaped_password}' | sudo -S bash -c '#{escaped_command}'"
        else
          "sudo bash -c '#{escaped_command}'"
        end
      elsif @sudo_password
        # Wrap single-line command directly
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

    def upload_files(files_to_sync, source_dir, destination, parallel:, use_sudo:)
      count = Concurrent::AtomicFixnum.new(0)
      source_path = Pathname.new(source_dir)
      parallel = normalize_parallel(parallel)
      return upload_files_sequential(files_to_sync, source_path, destination, use_sudo, count) if parallel <= 1

      queue = Queue.new
      files_to_sync.each { |path| queue << path }
      workers = Array.new(parallel) do
        Thread.new do
          until queue.empty?
            file_path = begin
              queue.pop(true)
            rescue StandardError
              nil
            end
            next unless file_path

            upload_single_file(file_path, source_path, destination, use_sudo)
            count.increment
          end
        end
      end
      workers.each(&:join)
      count.value
    end

    def upload_files_sequential(files_to_sync, source_path, destination, use_sudo, count)
      files_to_sync.each do |file_path|
        upload_single_file(file_path, source_path, destination, use_sudo)
        count.increment
      end
      count.value
    end

    def upload_single_file(file_path, source_path, destination, use_sudo)
      relative_path = Pathname.new(file_path).relative_path_from(source_path).to_s
      remote_path = File.join(destination, relative_path).gsub(%r{/+}, '/')
      remote_dir = File.dirname(remote_path)
      ensure_remote_directory(remote_dir, use_sudo: use_sudo)
      upload(file_path, remote_path, use_sudo: use_sudo)
    end

    def normalize_parallel(parallel)
      value = parallel.nil? ? Configuration.default_sync_parallel : parallel
      value = value.to_i
      value.positive? ? value : 1
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
