# frozen_string_literal: true

module Kdeploy
  # Domain Specific Language for deployment scripts
  class DSL
    def initialize(script_dir = nil)
      @pipeline = Pipeline.new
      @current_task = nil
      @inventory = nil
      @script_dir = script_dir || Dir.pwd
      @template_manager = nil
    end

    # Get pipeline or set pipeline name
    # @param name [String] Pipeline name (optional)
    # @return [Pipeline] Pipeline instance
    def pipeline(name = nil)
      @pipeline.instance_variable_set(:@name, name) if name
      @pipeline
    end

    # Set global variable
    # @param key [String, Symbol] Variable key
    # @param value [Object] Variable value
    def set(key, value)
      @pipeline.set_variable(key, value)
    end

    # Define host
    # @param hostname [String] Hostname or IP address
    # @param user [String] SSH user
    # @param port [Integer] SSH port
    # @param roles [Array] Host roles
    # @param vars [Hash] Host variables
    # @param ssh_options [Hash] SSH connection options
    def host(hostname, user: nil, port: nil, roles: [], vars: {}, **ssh_options)
      @pipeline.add_host(
        hostname,
        user: user,
        port: port,
        roles: roles,
        vars: vars,
        ssh_options: ssh_options
      )
    end

    # Define multiple hosts
    # @param hosts_config [Hash] Hosts configuration
    def hosts(hosts_config)
      @pipeline.add_hosts(hosts_config)
    end

    # Load hosts from inventory file
    # @param inventory_file [String] Path to inventory file
    def inventory(inventory_file = nil)
      inventory_file ||= default_inventory_file
      resolved_path = resolve_inventory_path(inventory_file)

      return unless File.exist?(resolved_path)

      load_inventory(resolved_path)
    end

    private

    def default_inventory_file
      Kdeploy.configuration&.inventory_file || 'inventory.yml'
    end

    def resolve_inventory_path(inventory_file)
      return inventory_file if File.absolute_path?(inventory_file)

      File.join(@script_dir, inventory_file)
    end

    def load_inventory(inventory_file)
      @inventory = Inventory.new(inventory_file)
      add_inventory_hosts
      set_inventory_variables
      log_inventory_loaded(inventory_file)
    end

    def add_inventory_hosts
      @inventory.all_hosts.each do |host|
        @pipeline.hosts << host unless @pipeline.hosts.include?(host)
      end
    end

    def set_inventory_variables
      @inventory.vars.each do |key, value|
        @pipeline.set_variable(key, value)
      end
    end

    def log_inventory_loaded(inventory_file)
      KdeployLogger.info(
        "Loaded #{@inventory.hosts.size} hosts from inventory: #{inventory_file}"
      )
    end

    public

    # Initialize template manager
    # @param template_dir [String] Template directory path
    def template_dir(template_dir = nil)
      template_dir ||= default_template_dir
      resolved_path = resolve_template_path(template_dir)

      @template_manager = TemplateManager.new(resolved_path, @pipeline.variables)
      KdeployLogger.info("Template directory set to: #{resolved_path}")
    end

    private

    def default_template_dir
      Kdeploy.configuration&.template_dir || 'templates'
    end

    def resolve_template_path(template_dir)
      return template_dir if File.absolute_path?(template_dir)

      File.join(@script_dir, template_dir)
    end

    public

    # Get or initialize template manager
    # @return [TemplateManager] Template manager instance
    def template_manager
      @template_manager ||= begin
        dir = default_template_dir
        resolved_path = resolve_template_path(dir)
        TemplateManager.new(resolved_path, @pipeline.variables)
      end
    end

    # Define task
    # @param name [String] Task name
    # @param on [Array, Symbol] Target hosts or roles
    # @param parallel [Boolean] Execute in parallel
    # @param fail_fast [Boolean] Stop on first failure
    # @param max_concurrent [Integer] Maximum concurrent executions
    def task(name, on: nil, parallel: true, fail_fast: false, max_concurrent: nil, &block)
      target_hosts = resolve_target_hosts(on)

      @current_task = @pipeline.add_task(
        name,
        hosts: target_hosts,
        parallel: parallel,
        fail_fast: fail_fast,
        max_concurrent: max_concurrent
      )

      instance_eval(&block) if block
      @current_task = nil
    end

    # Execute command in current task
    # @param command [String] Command to execute (supports heredoc)
    # @param name [String] Command name (optional)
    # @param timeout [Integer] Command timeout
    # @param retry_count [Integer] Number of retries
    # @param retry_delay [Integer] Delay between retries
    # @param ignore_errors [Boolean] Continue on error
    # @param only [Array, Symbol] Run only on specified roles
    # @param except [Array, Symbol] Skip specified roles
    def run(command, name: nil, timeout: nil, retry_count: nil, retry_delay: nil,
            ignore_errors: false, only: nil, except: nil)
      raise 'run can only be called within a task block' unless @current_task

      process_commands(command, name).each do |cmd_name, cmd|
        add_command_to_task(cmd_name, cmd, timeout, retry_count, retry_delay,
                            ignore_errors, only, except)
      end
    end

    private

    def process_commands(command, base_name)
      commands = process_heredoc_command(command)
      commands.each_with_index.map do |cmd, index|
        cmd = cmd.strip
        next if cmd.empty? || cmd.start_with?('#')

        [generate_command_name(cmd, base_name, index, commands.size), cmd]
      end.compact
    end

    def generate_command_name(cmd, base_name, index, total)
      return base_name if base_name && total == 1

      prefix = base_name || (cmd.split.first || 'unnamed')
      total > 1 ? "#{prefix}_#{index + 1}" : prefix
    end

    def add_command_to_task(name, cmd, timeout, retry_count, retry_delay,
                            ignore_errors, only, except)
      @current_task.add_command(
        name,
        cmd,
        timeout: timeout,
        retry_count: retry_count,
        retry_delay: retry_delay,
        ignore_errors: ignore_errors,
        only: only,
        except: except
      )
    end

    public

    # Execute local command
    # @param command [String] Local command to execute
    # @param name [String] Command name (optional)
    def local(command, name: nil)
      require 'open3'

      process_commands(command, name).each do |cmd_name, cmd|
        execute_local_command(cmd, cmd_name)
      end
    end

    private

    def execute_local_command(cmd, name)
      processed_cmd = process_local_command_variables(cmd)
      start_time = Time.now

      log_local_command_start(name, processed_cmd)
      stdout, stderr, status = Open3.capture3(processed_cmd)
      duration = Time.now - start_time

      handle_local_command_result(name, duration, status.exitstatus, stdout, stderr)
    end

    def process_local_command_variables(cmd)
      processed_cmd = cmd.dup
      @pipeline.variables.each do |key, value|
        processed_cmd.gsub!(/\$\{#{key}\}/, value.to_s)
      end
      processed_cmd
    end

    def log_local_command_start(name, cmd)
      KdeployLogger.info("🚀 Executing local command '#{name}'")
      KdeployLogger.debug("Command: #{cmd}")
    end

    def handle_local_command_result(name, duration, exit_code, stdout, stderr)
      if exit_code.zero?
        log_local_command_success(name, duration, stdout)
      else
        log_local_command_failure(name, duration, exit_code, stdout, stderr)
        raise "Local command '#{name}' failed"
      end
    end

    def log_local_command_success(name, duration, stdout)
      KdeployLogger.info("✅ Local command '#{name}' completed in #{duration.round(2)}s")
      KdeployLogger.debug("Output: #{stdout}") unless stdout.empty?
    end

    def log_local_command_failure(name, duration, exit_code, stdout, stderr)
      KdeployLogger.error("❌ Local command '#{name}' failed in #{duration.round(2)}s (exit code: #{exit_code})")
      KdeployLogger.error("Output: #{stdout}") unless stdout.empty?
      KdeployLogger.error("Error: #{stderr}") unless stderr.empty?
    end

    # Upload file to hosts
    # @param local_path [String] Local file path
    # @param remote_path [String] Remote file path
    # @param name [String] Command name (optional)
    def upload(local_path, remote_path, name: nil)
      raise 'upload can only be called within a task block' unless @current_task

      command_name = name || "upload #{File.basename(local_path)}"
      ensure_remote_directory(remote_path)
      add_upload_command(local_path, remote_path, command_name)
    end

    def ensure_remote_directory(remote_path)
      run("mkdir -p #{File.dirname(remote_path)}", name: 'create directory')
    end

    def add_upload_command(local_path, remote_path, command_name)
      upload_command = UploadCommand.new(local_path, remote_path, @pipeline.variables)
      upload_command.instance_variable_set(:@name, command_name)
      @current_task.commands << upload_command
    end

    public

    # Upload template file with variable substitution
    # @param template_name [String] Template name (without .erb extension)
    # @param remote_path [String] Remote file path
    # @param variables [Hash] Template variables
    # @param name [String] Command name (optional)
    def upload_template(template_name, remote_path, variables: {}, name: nil)
      raise 'upload_template can only be called within a task block' unless @current_task

      command_name = name || "upload_template #{template_name}"
      add_template_upload_command(template_name, remote_path, variables, command_name)
    end

    private

    def add_template_upload_command(template_name, remote_path, variables, command_name)
      command = TemplateUploadCommand.new(
        template_name,
        remote_path,
        variables,
        template_manager,
        @pipeline.variables
      )
      command.instance_variable_set(:@name, command_name)
      @current_task.commands << command
    end

    public

    # Download file from hosts
    # @param remote_path [String] Remote file path
    # @param local_path [String] Local file path
    # @param name [String] Command name (optional)
    def download(remote_path, local_path, name: nil)
      raise 'download can only be called within a task block' unless @current_task

      command_name = name || "download #{File.basename(remote_path)}"
      add_download_command(remote_path, local_path, command_name)
    end

    private

    def add_download_command(remote_path, local_path, command_name)
      command = DownloadCommand.new(remote_path, local_path, @pipeline.variables)
      command.instance_variable_set(:@name, command_name)
      @current_task.commands << command
    end

    # Define role-based host group
    # @param role [Symbol] Role name
    # @return [Array<Host>] Hosts with specified role
    def role(role)
      @pipeline.hosts_with_role(role)
    end

    # Conditional execution
    # @param condition [Boolean] Condition to check
    def when(condition, &)
      instance_eval(&) if condition && block_given?
    end

    # Execute block unless condition is true
    # @param condition [Boolean] Condition to check
    def unless(condition, &)
      instance_eval(&) if !condition && block_given?
    end

    # Include another deployment script
    # @param script_path [String] Path to script file
    def include(script_path)
      return unless File.exist?(script_path)

      KdeployLogger.debug("Including script: #{script_path}")
      script_content = File.read(script_path)
      instance_eval(script_content, script_path)
    end

    # Resolve target hosts from various formats
    def resolve_target_hosts(target)
      return @pipeline.hosts if target.nil?

      targets = Array(target)
      hosts = targets.flat_map { |t| resolve_single_target(t) }
      hosts.uniq
    end

    def resolve_single_target(target)
      case target
      when Host
        [target]
      when Symbol
        @pipeline.hosts_with_role(target)
      when String
        resolve_host_by_name(target)
      when Array
        target.flat_map { |t| resolve_single_target(t) }
      else
        raise ArgumentError, "Invalid target type: #{target.class}"
      end
    end

    def resolve_host_by_name(name)
      host = @pipeline.hosts.find { |h| h.hostname == name }
      raise "Host not found: #{name}" unless host

      [host]
    end

    def process_heredoc_command(command)
      command.split(/\r?\n/)
    end
  end

  # Command class for file upload operations
  class UploadCommand < Command
    def initialize(local_path, remote_path, global_variables = {})
      @local_path = local_path
      @remote_path = remote_path
      @global_variables = global_variables
      super()
    end

    def execute(host, connection)
      start_time = Time.now
      processed_path = process_remote_path(host)

      begin
        connection.upload(@local_path, processed_path)
        record_success(start_time, host)
      rescue StandardError => e
        record_failure(e, start_time, host)
        raise
      end
    end

    private

    def process_remote_path(host)
      path = @remote_path.dup
      variables = @global_variables.merge(host.vars)
      variables.each do |key, value|
        path.gsub!(/\$\{#{key}\}/, value.to_s)
      end
      path
    end

    def record_success(start_time, host)
      duration = Time.now - start_time
      KdeployLogger.info("✅ Uploaded #{@local_path} to #{host.hostname}:#{@remote_path} in #{duration.round(2)}s")
    end

    def record_failure(error, start_time, host)
      duration = Time.now - start_time
      KdeployLogger.error("❌ Failed to upload #{@local_path} to #{host.hostname}:#{@remote_path} in #{duration.round(2)}s")
      KdeployLogger.error("Error: #{error.message}")
    end
  end

  # Command class for file download operations
  class DownloadCommand < Command
    def initialize(remote_path, local_path, global_variables = {})
      @remote_path = remote_path
      @local_path = local_path
      @global_variables = global_variables
      super()
    end

    def execute(host, connection)
      start_time = Time.now
      processed_path = process_remote_path(host)

      begin
        connection.download(processed_path, @local_path)
        record_success(start_time, host)
      rescue StandardError => e
        record_failure(e, start_time, host)
        raise
      end
    end

    private

    def process_remote_path(host)
      path = @remote_path.dup
      variables = @global_variables.merge(host.vars)
      variables.each do |key, value|
        path.gsub!(/\$\{#{key}\}/, value.to_s)
      end
      path
    end

    def record_success(start_time, host)
      duration = Time.now - start_time
      KdeployLogger.info("✅ Downloaded #{host.hostname}:#{@remote_path} to #{@local_path} in #{duration.round(2)}s")
    end

    def record_failure(error, start_time, host)
      duration = Time.now - start_time
      KdeployLogger.error("❌ Failed to download #{host.hostname}:#{@remote_path} to #{@local_path} in #{duration.round(2)}s")
      KdeployLogger.error("Error: #{error.message}")
    end
  end

  # Command class for template upload operations
  class TemplateUploadCommand < Command
    def initialize(template_name, remote_path, variables, template_manager, global_variables = {})
      @template_name = template_name
      @remote_path = remote_path
      @variables = variables
      @template_manager = template_manager
      @global_variables = global_variables
      super()
    end

    def execute(host, connection)
      start_time = Time.now
      host_variables = build_host_variables(host)
      processed_path = process_remote_path_variables(host_variables)

      begin
        perform_template_upload(host, connection, host_variables, processed_path)
        record_success(start_time, host)
      rescue StandardError => e
        record_failure(e, start_time, host)
        raise
      end
    end

    private

    def build_host_variables(host)
      @global_variables.merge(@variables).merge(host.vars).merge(
        hostname: host.hostname,
        user: host.user,
        port: host.port
      )
    end

    def process_remote_path_variables(host_variables)
      path = @remote_path.dup
      host_variables.each do |key, value|
        path.gsub!(/\$\{#{key}\}/, value.to_s)
      end
      path
    end

    def perform_template_upload(_host, connection, host_variables, processed_path)
      rendered_content = @template_manager.render(@template_name, host_variables)
      temp_file = create_temp_file(rendered_content)
      upload_template_file(connection, temp_file, processed_path)
    ensure
      cleanup_temp_file(temp_file) if temp_file
    end

    def create_temp_file(content)
      temp_file = "/tmp/kdeploy_template_#{Time.now.to_i}_#{Process.pid}"
      File.write(temp_file, content)
      temp_file
    end

    def upload_template_file(connection, temp_file, processed_path)
      connection.execute("mkdir -p #{File.dirname(processed_path)}")
      connection.upload(temp_file, processed_path)
    end

    def cleanup_temp_file(temp_file)
      FileUtils.rm_f(temp_file)
    end

    def record_success(start_time, host)
      duration = Time.now - start_time
      KdeployLogger.info("✅ Uploaded template #{@template_name} to #{host.hostname}:#{@remote_path} in #{duration.round(2)}s")
    end

    def record_failure(error, start_time, host)
      duration = Time.now - start_time
      KdeployLogger.error("❌ Failed to upload template #{@template_name} to #{host.hostname}:#{@remote_path} in #{duration.round(2)}s")
      KdeployLogger.error("Error: #{error.message}")
      cleanup_temp_file(@temp_file) if defined?(@temp_file) && File.exist?(@temp_file)
    end
  end
end
