# frozen_string_literal: true

module Kdeploy
  class Pipeline
    attr_reader :name, :hosts, :tasks, :variables

    def initialize(name = 'default')
      @name = name
      @hosts = []
      @tasks = []
      @variables = {}
    end

    # Add host to pipeline
    # @param hostname [String] Hostname or IP address
    # @param user [String] SSH user
    # @param port [Integer] SSH port
    # @param ssh_options [Hash] SSH options
    # @param roles [Array] Host roles
    # @param vars [Hash] Host variables
    def add_host(hostname, user: nil, port: nil, ssh_options: {}, roles: [], vars: {})
      # Convert roles to array if it's a single value
      roles = Array(roles)

      # Create host object
      host = Host.new(
        hostname,
        user: user || 'root',
        port: port || 22,
        ssh_options: ssh_options,
        roles: roles,
        vars: vars
      )

      # Add host if not already present
      @hosts << host unless @hosts.any? { |h| h.hostname == host.hostname }
      host
    end

    # Add multiple hosts from hash
    # @param hosts_config [Hash] Hosts configuration
    def add_hosts(hosts_config)
      hosts_config.each do |hostname, config|
        config ||= {}
        add_host(
          hostname,
          user: config['user'] || config[:user],
          port: config['port'] || config[:port],
          ssh_options: config['ssh_options'] || config[:ssh_options] || {},
          roles: config['roles'] || config[:roles] || [],
          vars: config['vars'] || config[:vars] || {}
        )
      end
    end

    # Get hosts by role
    # @param role [String, Symbol] Role to filter by
    # @return [Array<Host>] Hosts with specified role
    def hosts_with_role(role)
      @hosts.select { |host| host.has_role?(role) }
    end

    # Add task to pipeline
    # @param name [String] Task name
    # @param hosts [Array<Host>] Target hosts (default: all hosts)
    # @param options [Hash] Task options
    # @return [Task] Created task
    def add_task(name, hosts: nil, **options)
      target_hosts = case hosts
                     when Array
                       hosts
                     when Symbol
                       hosts_with_role(hosts)
                     when String
                       hosts_with_role(hosts.to_sym)
                     else
                       @hosts
                     end

      task = Task.new(name, target_hosts, options)
      # Set global variables from pipeline
      task.global_variables = @variables
      @tasks << task
      task
    end

    # Set global variable
    # @param key [String, Symbol] Variable key
    # @param value [Object] Variable value
    def set_variable(key, value)
      @variables[key.to_s] = value
      @variables[key.to_sym] = value
    end

    # Get global variable
    # @param key [String, Symbol] Variable key
    # @return [Object] Variable value
    def get_variable(key)
      @variables[key.to_s] || @variables[key.to_sym]
    end

    # Execute all tasks in pipeline
    # @return [Hash] Execution results
    def execute
      return { success: true, results: [], duration: 0 } if @tasks.empty?

      KdeployLogger.info("Starting pipeline '#{@name}' with #{@tasks.size} task(s) on #{@hosts.size} host(s)")

      start_time = Time.now
      results = []
      overall_success = true

      @tasks.each_with_index do |task, index|
        KdeployLogger.info("Executing task #{index + 1}/#{@tasks.size}: '#{task.name}'")

        result = task.execute
        results << {
          task_name: task.name,
          **result
        }

        unless result[:success]
          overall_success = false
          KdeployLogger.error("Task '#{task.name}' failed, pipeline execution continuing...")
        end
      end

      duration = Time.now - start_time
      success_count = results.count { |r| r[:success] }

      KdeployLogger.info("Pipeline '#{@name}' completed in #{duration.round(2)}s: #{success_count}/#{@tasks.size} tasks successful")

      {
        success: overall_success,
        results: results,
        duration: duration,
        tasks_count: @tasks.size,
        success_count: success_count
      }
    end

    # Get pipeline summary
    # @return [Hash] Pipeline summary
    def summary
      {
        name: @name,
        hosts_count: @hosts.size,
        tasks_count: @tasks.size,
        hosts: @hosts.map(&:hostname),
        tasks: @tasks.map(&:name)
      }
    end

    # Validate pipeline configuration
    # @return [Array<String>] Validation errors
    def validate
      errors = []

      errors << 'No hosts defined' if @hosts.empty?
      errors << 'No tasks defined' if @tasks.empty?

      @hosts.each do |host|
        errors << "Invalid hostname: #{host.hostname}" if host.hostname.nil? || host.hostname.empty?
        errors << "Invalid user: #{host.user}" if host.user.nil? || host.user.empty?
        errors << "Invalid port: #{host.port}" unless host.port.is_a?(Integer) && host.port.positive?
      end

      @tasks.each do |task|
        errors << "Task '#{task.name}' has no commands" if task.commands.empty?
        errors << "Task '#{task.name}' has no hosts" if task.hosts.empty?
      end

      errors
    end

    # Check if pipeline is valid
    # @return [Boolean] True if pipeline is valid
    def valid?
      validate.empty?
    end
  end
end
