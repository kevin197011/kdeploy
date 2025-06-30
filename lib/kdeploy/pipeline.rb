# frozen_string_literal: true

module Kdeploy
  # Pipeline class for managing deployment tasks and hosts
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
    # @return [Host] Created host
    def add_host(hostname, user: nil, port: nil, ssh_options: {}, roles: [], vars: {})
      host = Host.new(
        hostname,
        user: user,
        port: port,
        ssh_options: ssh_options,
        roles: roles,
        vars: vars
      )
      @hosts << host unless @hosts.include?(host)
      host
    end

    # Add multiple hosts from hash
    # @param hosts_config [Hash] Hosts configuration
    def add_hosts(hosts_config)
      hosts_config.each do |hostname, config|
        config ||= {}
        add_host_from_config(hostname, config)
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
      target_hosts = hosts || @hosts
      task = create_task(name, target_hosts, options)
      @tasks << task
      task
    end

    # Set global variable
    # @param key [String, Symbol] Variable key
    # @param value [Object] Variable value
    def set_variable(key, value)
      @variables[key.to_s] = value
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
      return empty_execution_result if @tasks.empty?

      log_pipeline_start
      start_time = Time.now
      results = execute_tasks
      duration = Time.now - start_time
      success_count = count_successful_tasks(results)

      log_pipeline_completion(duration, success_count)
      build_execution_result(results, duration, success_count)
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
      errors.concat(validate_pipeline_structure)
      errors.concat(validate_hosts)
      errors.concat(validate_tasks)
      errors
    end

    # Check if pipeline is valid
    # @return [Boolean] True if pipeline is valid
    def valid?
      validate.empty?
    end

    private

    def add_host_from_config(hostname, config)
      add_host(
        hostname,
        user: config['user'] || config[:user],
        port: config['port'] || config[:port],
        ssh_options: config['ssh_options'] || config[:ssh_options] || {},
        roles: config['roles'] || config[:roles] || [],
        vars: config['vars'] || config[:vars] || {}
      )
    end

    def create_task(name, target_hosts, options)
      task = Task.new(name, target_hosts, options)
      task.global_variables = @variables
      task
    end

    def empty_execution_result
      { success: true, results: [], duration: 0 }
    end

    def log_pipeline_start
      KdeployLogger.info(
        "Starting pipeline '#{@name}' with #{@tasks.size} task(s) on #{@hosts.size} host(s)"
      )
    end

    def execute_tasks
      results = []
      overall_success = true

      @tasks.each_with_index do |task, index|
        log_task_execution(task, index)
        result = execute_task(task)
        results << result
        overall_success = false unless result[:success]
      end

      results
    end

    def log_task_execution(task, index)
      KdeployLogger.info("Executing task #{index + 1}/#{@tasks.size}: '#{task.name}'")
    end

    def execute_task(task)
      result = task.execute
      log_task_failure(task) unless result[:success]

      {
        task_name: task.name,
        **result
      }
    end

    def log_task_failure(task)
      KdeployLogger.error("Task '#{task.name}' failed, pipeline execution continuing...")
    end

    def count_successful_tasks(results)
      results.count { |r| r[:success] }
    end

    def log_pipeline_completion(duration, success_count)
      KdeployLogger.info(
        "Pipeline '#{@name}' completed in #{duration.round(2)}s: " \
        "#{success_count}/#{@tasks.size} tasks successful"
      )
    end

    def build_execution_result(results, duration, success_count)
      {
        success: results.all? { |r| r[:success] },
        results: results,
        duration: duration,
        tasks_count: @tasks.size,
        success_count: success_count
      }
    end

    def validate_pipeline_structure
      errors = []
      errors << 'No hosts defined' if @hosts.empty?
      errors << 'No tasks defined' if @tasks.empty?
      errors
    end

    def validate_hosts
      @hosts.each_with_object([]) do |host, errors|
        errors.concat(validate_host(host))
      end
    end

    def validate_host(host)
      errors = []
      errors << "Invalid hostname: #{host.hostname}" if invalid_hostname?(host)
      errors << "Invalid user: #{host.user}" if invalid_user?(host)
      errors << "Invalid port: #{host.port}" if invalid_port?(host)
      errors
    end

    def invalid_hostname?(host)
      host.hostname.nil? || host.hostname.empty?
    end

    def invalid_user?(host)
      host.user.nil? || host.user.empty?
    end

    def invalid_port?(host)
      !host.port.is_a?(Integer) || !host.port.positive?
    end

    def validate_tasks
      @tasks.each_with_object([]) do |task, errors|
        errors.concat(validate_task(task))
      end
    end

    def validate_task(task)
      errors = []
      errors << "Task '#{task.name}' has no commands" if task.commands.empty?
      errors << "Task '#{task.name}' has no hosts" if task.hosts.empty?
      errors
    end
  end
end
