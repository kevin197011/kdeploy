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
      command_name = name || "local: #{command.split.first}"

      result = system(command)

      if result
        KdeployLogger.info("Local command '#{command_name}' completed successfully")
      else
        KdeployLogger.error("Local command '#{command_name}' failed")
        raise CommandError, "Local command failed: #{command}"
      end
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

      # Add upload command
      upload_command = UploadCommand.new(local_path, remote_path)
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

      # Add template upload command
      template_command = TemplateUploadCommand.new(template_name, remote_path, variables, template_manager)
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

      # Add download command
      download_command = DownloadCommand.new(remote_path, local_path)
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
    def initialize(local_path, remote_path)
      @local_path = local_path
      @remote_path = remote_path
      super('upload', "upload #{local_path} #{remote_path}")
    end

    def execute(host, connection)
      start_time = Time.now

      KdeployLogger.info("Uploading '#{@local_path}' to #{host}:#{@remote_path}")

      success = connection.upload(@local_path, @remote_path)

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
    def initialize(remote_path, local_path)
      @remote_path = remote_path
      @local_path = local_path
      super('download', "download #{remote_path} #{local_path}")
    end

    def execute(host, connection)
      start_time = Time.now

      # Create unique local path for each host
      host_local_path = @local_path.sub(/(\.[^.]+)?$/) { "_#{host.hostname}#{::Regexp.last_match(1)}" }

      KdeployLogger.info("Downloading '#{@remote_path}' from #{host} to #{host_local_path}")

      success = connection.download(@remote_path, host_local_path)

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
    def initialize(template_name, remote_path, variables, template_manager)
      @template_name = template_name
      @remote_path = remote_path
      @variables = variables
      @template_manager = template_manager
      super('upload_template', "upload_template #{template_name} #{remote_path}")
    end

    def execute(host, connection)
      start_time = Time.now

      # Merge host variables with template variables
      host_variables = @variables.merge(
        hostname: host.hostname,
        user: host.user,
        port: host.port
      )

      # Add host custom variables
      host.vars.each { |k, v| host_variables[k] = v }

      # Render template
      rendered_content = @template_manager.render(@template_name, host_variables)

      # Create temporary file with rendered content
      temp_file = "/tmp/kdeploy_template_#{Time.now.to_i}_#{Process.pid}"
      File.write(temp_file, rendered_content)

      KdeployLogger.info("Uploading rendered template '#{@template_name}' to #{host}:#{@remote_path}")

      # Create remote directory first
      connection.execute("mkdir -p #{File.dirname(@remote_path)}")

      # Upload rendered template
      success = connection.upload(temp_file, @remote_path)

      # Cleanup temporary file
      FileUtils.rm_f(temp_file)

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
    rescue StandardError => e
      # Cleanup temporary file on error
      File.delete(temp_file) if defined?(temp_file) && File.exist?(temp_file)

      duration = Time.now - start_time
      @result = {
        success: false,
        duration: duration,
        error: e.message
      }

      KdeployLogger.error("Template upload failed to #{host}: #{e.message}")
      false
    end
  end
end
