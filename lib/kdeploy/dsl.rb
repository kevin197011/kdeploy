# frozen_string_literal: true

module Kdeploy
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
      @pipeline.add_host(hostname, user: user, port: port, roles: roles, vars: vars, ssh_options: ssh_options)
    end

    # Define multiple hosts
    # @param hosts_config [Hash] Hosts configuration
    def hosts(hosts_config)
      @pipeline.add_hosts(hosts_config)
    end

    # Load hosts from inventory file
    # @param inventory_file [String] Path to inventory file
    def inventory(inventory_file = nil)
      inventory_file ||= Kdeploy.configuration&.inventory_file || 'inventory.yml'

      # Resolve relative path to script directory
      inventory_file = File.join(@script_dir, inventory_file) unless File.absolute_path?(inventory_file)

      unless File.exist?(inventory_file)
        KdeployLogger.warn("Inventory file not found: #{inventory_file}")
        return
      end

      @inventory = Inventory.new(inventory_file)

      # Add all hosts from inventory to pipeline
      @inventory.all_hosts.each do |host|
        @pipeline.hosts << host unless @pipeline.hosts.include?(host)
      end

      # Set global variables from inventory
      @inventory.vars.each do |key, value|
        @pipeline.set_variable(key, value)
      end

      KdeployLogger.info("Loaded #{@inventory.hosts.size} hosts from inventory: #{inventory_file}")
    end

    # Initialize template manager
    # @param template_dir [String] Template directory path
    def template_dir(template_dir = nil)
      template_dir ||= Kdeploy.configuration&.template_dir || 'templates'

      # Resolve relative path to script directory
      template_dir = File.join(@script_dir, template_dir) unless File.absolute_path?(template_dir)

      @template_manager = TemplateManager.new(template_dir, @pipeline.variables)

      KdeployLogger.info("Template directory set to: #{template_dir}")
    end

    # Get or initialize template manager
    # @return [TemplateManager] Template manager instance
    def template_manager
      @template_manager ||= begin
        template_dir = Kdeploy.configuration&.template_dir || 'templates'
        template_dir = File.join(@script_dir, template_dir) unless File.absolute_path?(template_dir)
        TemplateManager.new(template_dir, @pipeline.variables)
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

      instance_eval(&block) if block_given?
      @current_task = nil
    end

    # Execute command in current task
    # Supports both single line commands and heredoc syntax
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

      # Process heredoc commands - split multi-line commands into separate commands
      processed_commands = process_heredoc_command(command)

      processed_commands.each_with_index do |cmd, index|
        cmd = cmd.strip
        next if cmd.empty? || cmd.start_with?('#') # Skip empty lines and comments

        command_name = if processed_commands.size > 1
                         name ? "#{name}_#{index + 1}" : "#{cmd.split.first || 'unnamed'}_#{index + 1}"
                       else
                         name || cmd.split.first || 'unnamed'
                       end

        @current_task.add_command(
          command_name,
          cmd,
          timeout: timeout,
          retry_count: retry_count,
          retry_delay: retry_delay,
          ignore_errors: ignore_errors,
          only: only,
          except: except
        )
      end
    end

    # Execute local command
    # @param command [String] Local command to execute
    # @param name [String] Command name (optional)
    def local(command, name: nil)
      require 'open3'

      processed_commands = process_heredoc_command(command)
      processed_commands.each_with_index { |cmd, index| execute_local_command(cmd, name, index, processed_commands.size) }
    end

    # Upload file to hosts
    # @param local_path [String] Local file path
    # @param remote_path [String] Remote file path
    # @param name [String] Command name (optional)
    def upload(local_path, remote_path, name: nil)
      raise 'upload can only be called within a task block' unless @current_task

      command_name = name || "upload #{File.basename(local_path)}"

      # Add mkdir command first
      run("mkdir -p #{File.dirname(remote_path)}", name: 'create directory')

      # Add upload command with global variables
      upload_command = UploadCommand.new(local_path, remote_path, @pipeline.variables)
      upload_command.instance_variable_set(:@name, command_name)
      @current_task.commands << upload_command
    end

    # Upload template file with variable substitution
    # @param template_name [String] Template name (without .erb extension)
    # @param remote_path [String] Remote file path
    # @param variables [Hash] Template variables
    # @param name [String] Command name (optional)
    def upload_template(template_name, remote_path, variables: {}, name: nil)
      raise 'upload_template can only be called within a task block' unless @current_task

      command_name = name || "upload_template #{template_name}"

      # Add template upload command with global variables
      template_command = TemplateUploadCommand.new(template_name, remote_path, variables, template_manager, @pipeline.variables)
      template_command.instance_variable_set(:@name, command_name)
      @current_task.commands << template_command
    end

    # Render template to string
    # @param template_name [String] Template name
    # @param variables [Hash] Template variables
    # @return [String] Rendered template content
    def render_template(template_name, variables = {})
      template_manager.render(template_name, variables)
    end

    # Execute rendered template as script
    # @param template_name [String] Template name
    # @param variables [Hash] Template variables
    # @param name [String] Command name (optional)
    def run_template(template_name, variables: {}, name: nil)
      raise 'run_template can only be called within a task block' unless @current_task

      rendered_script = template_manager.render(template_name, variables)
      command_name = name || "run_template #{template_name}"

      run(rendered_script, name: command_name)
    end

    # Download file from hosts
    # @param remote_path [String] Remote file path
    # @param local_path [String] Local file path
    # @param name [String] Command name (optional)
    def download(remote_path, local_path, name: nil)
      raise 'download can only be called within a task block' unless @current_task

      command_name = name || "download #{File.basename(remote_path)}"

      # Add download command with global variables
      download_command = DownloadCommand.new(remote_path, local_path, @pipeline.variables)
      download_command.instance_variable_set(:@name, command_name)
      @current_task.commands << download_command
    end

    # Define role-based host group
    # @param role [Symbol] Role name
    # @return [Array<Host>] Hosts with specified role
    def role(role)
      @pipeline.hosts_with_role(role)
    end

    # Conditional execution
    # @param condition [Boolean] Condition to check
    def when(condition, &block)
      instance_eval(&block) if condition && block_given?
    end

    # Execute block unless condition is true
    # @param condition [Boolean] Condition to check
    def unless(condition, &block)
      instance_eval(&block) if !condition && block_given?
    end

    # Include another deployment script
    # @param script_path [String] Path to script file
    def include(script_path)
      return unless File.exist?(script_path)

      KdeployLogger.debug("Including script: #{script_path}")
      script_content = File.read(script_path)
      instance_eval(script_content, script_path)
    end

    private

    # Execute a single local command
    # @param cmd [String] Command to execute
    # @param name [String] Base command name
    # @param index [Integer] Command index
    # @param total_commands [Integer] Total number of commands
    def execute_local_command(cmd, name, index, total_commands)
      require 'open3'

      cmd = cmd.strip
      return if cmd.empty? || cmd.start_with?('#') # Skip empty lines and comments

      command_name = generate_local_command_name(cmd, name, index, total_commands)
      processed_cmd = process_local_command_variables(cmd)

      log_local_command_start(command_name, processed_cmd)

      start_time = Time.now
      stdout, stderr, status = Open3.capture3(processed_cmd)
      duration = Time.now - start_time

      if status.success?
        log_local_command_success(command_name, duration, stdout)
      else
        log_local_command_failure(command_name, duration, status.exitstatus, stdout, stderr)
        raise CommandError, "Local command failed: #{cmd}"
      end
    end

    # Generate command name for local execution
    def generate_local_command_name(cmd, name, index, total_commands)
      return name || "local: #{cmd.split.first || 'script'}" if total_commands == 1

      name ? "#{name}_#{index + 1}" : "local: #{cmd.split.first || 'script'}_#{index + 1}"
    end

    # Process template variables in local command
    def process_local_command_variables(cmd)
      processed_cmd = cmd.dup
      @pipeline.variables.each do |key, value|
        processed_cmd = processed_cmd.gsub("{{#{key}}}", value.to_s)
        processed_cmd = processed_cmd.gsub("${#{key}}", value.to_s)
      end
      processed_cmd
    end

    # Log local command execution start
    def log_local_command_start(command_name, processed_cmd)
      KdeployLogger.info("🚀 Executing local command '#{command_name}'")
      KdeployLogger.debug("   Command: #{processed_cmd}")
    end

    # Log successful local command completion
    def log_local_command_success(command_name, duration, stdout)
      KdeployLogger.info("✅ Local command '#{command_name}' completed in #{duration.round(2)}s")
      return if stdout.strip.empty?

      KdeployLogger.info('📤 Output:')
      stdout.strip.split("\n").each { |line| KdeployLogger.info("   #{line}") }
    end

    # Log failed local command
    def log_local_command_failure(command_name, duration, exit_code, stdout, stderr)
      KdeployLogger.error("❌ Local command '#{command_name}' failed in #{duration.round(2)}s (exit code: #{exit_code})")
      KdeployLogger.error("📤 STDERR: #{stderr}") unless stderr.strip.empty?
      KdeployLogger.error("📤 STDOUT: #{stdout}") unless stdout.strip.empty?
    end

    # Resolve target hosts from various formats
    # @param target [Array, Symbol, String, nil] Target specification
    # @return [Array<Host>] Resolved hosts
    def resolve_target_hosts(target)
      return @pipeline.hosts if target.nil?

      case target
      when Array
        target.flat_map { |t| resolve_single_target(t) }
      else
        resolve_single_target(target)
      end
    end

    # Resolve single target specification
    # @param target [Symbol, String] Single target specification
    # @return [Array<Host>] Resolved hosts
    def resolve_single_target(target)
      case target
      when Symbol
        target_str = target.to_s

        # Try inventory groups first if available
        if @inventory
          inventory_hosts = @inventory.hosts_in_group(target_str)
          return inventory_hosts unless inventory_hosts.empty?

          # Try inventory roles
          inventory_role_hosts = @inventory.hosts_with_role(target_str)
          return inventory_role_hosts unless inventory_role_hosts.empty?
        end

        # Fallback to pipeline roles
        @pipeline.hosts_with_role(target)
      when String
        # Try exact hostname match first
        hosts_by_name = @pipeline.hosts.select { |h| h.hostname == target }
        return hosts_by_name unless hosts_by_name.empty?

        # Try inventory groups if available
        if @inventory
          inventory_hosts = @inventory.hosts_in_group(target)
          return inventory_hosts unless inventory_hosts.empty?

          # Try inventory roles
          inventory_role_hosts = @inventory.hosts_with_role(target)
          return inventory_role_hosts unless inventory_role_hosts.empty?
        end

        # Fallback to pipeline roles
        @pipeline.hosts_with_role(target)
      else
        []
      end
    end

    # Process heredoc commands into individual command lines
    # @param command [String] Command string (may contain multiple lines)
    # @return [Array<String>] Array of individual commands
    def process_heredoc_command(command)
      # Split by newlines and process each line
      lines = command.split(/\r?\n/)

      # If single line, return as is
      return [command] if lines.size == 1

      # Process multi-line heredoc
      processed_lines = []

      lines.each do |line|
        line = line.strip

        # Skip empty lines and comments
        next if line.empty? || line.start_with?('#')

        # Handle line continuation (backslash at end)
        if line.end_with?('\\')
          line = line[0..-2] # Remove backslash
          if processed_lines.empty?
            processed_lines << line
          else
            processed_lines[-1] += " #{line}"
          end
        elsif processed_lines.empty? || !processed_lines[-1].end_with?(' ')
          processed_lines << line
        else
          processed_lines[-1] += line
        end
      end

      processed_lines.empty? ? [command] : processed_lines
    end
  end

  # Special command class for file uploads
  class UploadCommand < Command
    def initialize(local_path, remote_path, global_variables = {})
      @local_path = local_path
      @remote_path = remote_path
      @global_variables = global_variables
      super('upload', "upload #{local_path} #{remote_path}")
    end

    def execute(host, connection)
      start_time = Time.now

      # Process remote path template variables
      processed_remote_path = @remote_path.dup
      # Merge global variables with host variables
      all_variables = @global_variables.merge(host.vars).merge(
        hostname: host.hostname,
        user: host.user,
        port: host.port
      )

      all_variables.each do |key, value|
        processed_remote_path = processed_remote_path.gsub("{{#{key}}}", value.to_s)
        processed_remote_path = processed_remote_path.gsub("${#{key}}", value.to_s)
      end

      KdeployLogger.info("Uploading '#{@local_path}' to #{host}:#{processed_remote_path}")

      success = connection.upload(@local_path, processed_remote_path)

      duration = Time.now - start_time
      @result = {
        success: success,
        duration: duration
      }

      if success
        KdeployLogger.info("Upload completed to #{host} in #{duration.round(2)}s")
      else
        KdeployLogger.error("Upload failed to #{host} after #{duration.round(2)}s")
      end

      success
    end
  end

  # Special command class for file downloads
  class DownloadCommand < Command
    def initialize(remote_path, local_path, global_variables = {})
      @remote_path = remote_path
      @local_path = local_path
      @global_variables = global_variables
      super('download', "download #{remote_path} #{local_path}")
    end

    def execute(host, connection)
      start_time = Time.now

      # Process remote path template variables
      processed_remote_path = @remote_path.dup
      # Merge global variables with host variables
      all_variables = @global_variables.merge(host.vars).merge(
        hostname: host.hostname,
        user: host.user,
        port: host.port
      )

      all_variables.each do |key, value|
        processed_remote_path = processed_remote_path.gsub("{{#{key}}}", value.to_s)
        processed_remote_path = processed_remote_path.gsub("${#{key}}", value.to_s)
      end

      # Create unique local path for each host
      host_local_path = @local_path.sub(/(\.[^.]+)?$/) { "_#{host.hostname}#{::Regexp.last_match(1)}" }

      KdeployLogger.info("Downloading '#{processed_remote_path}' from #{host} to #{host_local_path}")

      success = connection.download(processed_remote_path, host_local_path)

      duration = Time.now - start_time
      @result = {
        success: success,
        duration: duration,
        local_path: host_local_path
      }

      if success
        KdeployLogger.info("Download completed from #{host} in #{duration.round(2)}s")
      else
        KdeployLogger.error("Download failed from #{host} after #{duration.round(2)}s")
      end

      success
    end
  end

  # Special command class for template uploads
  class TemplateUploadCommand < Command
    def initialize(template_name, remote_path, variables, template_manager, global_variables = {})
      @template_name = template_name
      @remote_path = remote_path
      @variables = variables
      @template_manager = template_manager
      @global_variables = global_variables
      super('upload_template', "upload_template #{template_name} #{remote_path}")
    end

    def execute(host, connection)
      start_time = Time.now

      host_variables = build_host_variables(host)
      processed_remote_path = process_remote_path_variables(host_variables)
      success = perform_template_upload(host, connection, host_variables, processed_remote_path)

      record_execution_result(start_time, success, host)
    rescue StandardError => e
      log_upload_failure(e, start_time, host)
    end

    private

    def build_host_variables(host)
      # Merge variables in priority order: global < template < host < host_info
      host_variables = @global_variables.merge(@variables).merge(
        hostname: host.hostname,
        user: host.user,
        port: host.port
      )

      # Add host custom variables (highest priority except for host info)
      host.vars.each { |k, v| host_variables[k] = v }
      host_variables
    end

    def process_remote_path_variables(host_variables)
      processed_remote_path = @remote_path.dup
      host_variables.each do |key, value|
        processed_remote_path = processed_remote_path.gsub("{{#{key}}}", value.to_s)
        processed_remote_path = processed_remote_path.gsub("${#{key}}", value.to_s)
      end
      processed_remote_path
    end

    def perform_template_upload(host, connection, host_variables, processed_remote_path)
      rendered_content = @template_manager.render(@template_name, host_variables)
      temp_file = create_temp_file(rendered_content)

      KdeployLogger.info("Uploading rendered template '#{@template_name}' to #{host}:#{processed_remote_path}")

      success = upload_template_file(connection, temp_file, processed_remote_path)
      cleanup_temp_file(temp_file)
      success
    end

    def create_temp_file(content)
      temp_file = "/tmp/kdeploy_template_#{Time.now.to_i}_#{Process.pid}"
      File.write(temp_file, content)
      temp_file
    end

    def upload_template_file(connection, temp_file, processed_remote_path)
      # Create remote directory first
      connection.execute("mkdir -p #{File.dirname(processed_remote_path)}")
      # Upload rendered template
      connection.upload(temp_file, processed_remote_path)
    end

    def cleanup_temp_file(temp_file)
      FileUtils.rm_f(temp_file)
    end

    def record_execution_result(start_time, success, host)
      duration = Time.now - start_time
      @result = {
        success: success,
        duration: duration,
        template: @template_name
      }

      if success
        KdeployLogger.info("Template upload completed to #{host} in #{duration.round(2)}s")
      else
        KdeployLogger.error("Template upload failed to #{host} after #{duration.round(2)}s")
      end

      success
    end

    def log_upload_failure(error, start_time, host)
      # Cleanup temporary file on error
      cleanup_temp_file(@temp_file) if defined?(@temp_file) && File.exist?(@temp_file)

      duration = Time.now - start_time
      @result = {
        success: false,
        duration: duration,
        error: error.message
      }

      KdeployLogger.error("Template upload failed to #{host}: #{error.message}")
      false
    end
  end
end
