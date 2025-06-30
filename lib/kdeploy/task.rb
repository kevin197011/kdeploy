# frozen_string_literal: true

module Kdeploy
  # Task class for managing command execution on hosts
  class Task
    attr_reader :name, :hosts, :commands, :options
    attr_accessor :global_variables

    def initialize(name, hosts = [], options = {})
      @name = name
      @hosts = Array(hosts)
      @commands = []
      @options = default_options.merge(options)
      @global_variables = {}
    end

    # Add command to task
    # @param name [String] Command name
    # @param command [String] Command to execute
    # @param options [Hash] Command options
    # @return [Command] Created command
    def add_command(name, command, options = {})
      command_options = options.merge(global_variables: @global_variables)
      cmd = Command.new(name, command, command_options)
      @commands << cmd
      cmd
    end

    # Add host to task
    # @param host [Host] Host to add
    # @return [Host] Added host
    def add_host(host)
      @hosts << host unless @hosts.include?(host)
      host
    end

    # Remove host from task
    # @param host [Host] Host to remove
    # @return [Host, nil] Removed host or nil if not found
    def remove_host(host)
      @hosts.delete(host)
    end

    # Execute task on all hosts
    # @return [Hash] Execution results
    def execute
      return empty_execution_result if @commands.empty? || @hosts.empty?

      log_task_start
      start_time = Time.now
      results = execute_commands
      duration = Time.now - start_time
      success_count = count_successful_hosts(results)

      log_task_completion(duration, success_count)
      build_task_result(results, duration, success_count)
    end

    private

    def default_options
      {
        parallel: true,
        fail_fast: false,
        max_concurrent: nil
      }
    end

    def empty_execution_result
      { success: true, results: {} }
    end

    def log_task_start
      KdeployLogger.info("Starting task '#{@name}' on #{@hosts.size} host(s)")
    end

    def execute_commands
      @options[:parallel] ? execute_parallel : execute_sequential
    end

    def execute_parallel
      max_concurrent = determine_max_concurrent
      pool = create_thread_pool(max_concurrent)
      futures = create_futures(pool)
      results = collect_future_results(futures)

      shutdown_pool(pool)
      results
    end

    def determine_max_concurrent
      @options[:max_concurrent] ||
        Kdeploy.configuration&.max_concurrent_tasks ||
        10
    end

    def create_thread_pool(max_concurrent)
      Concurrent::ThreadPoolExecutor.new(
        min_threads: 1,
        max_threads: [max_concurrent, @hosts.size].min
      )
    end

    def create_futures(pool)
      @hosts.map do |host|
        Concurrent::Future.execute(executor: pool) do
          execute_on_host(host)
        end
      end
    end

    def collect_future_results(futures)
      results = {}
      futures.each_with_index do |future, index|
        host = @hosts[index]
        results[host.hostname] = future.value
      end
      results
    end

    def shutdown_pool(pool)
      pool.shutdown
      pool.wait_for_termination(30)
    end

    def execute_sequential
      results = {}

      @hosts.each do |host|
        results[host.hostname] = execute_on_host(host)

        if should_stop_execution?(results[host.hostname])
          log_fail_fast_stop(host)
          break
        end
      end

      results
    end

    def should_stop_execution?(result)
      @options[:fail_fast] && !result[:success]
    end

    def log_fail_fast_stop(host)
      KdeployLogger.error(
        "Task '#{@name}' failed on #{host}, stopping execution due to fail_fast option"
      )
    end

    def execute_on_host(host)
      connection = SSHConnection.new(host)
      host_results = initialize_host_results

      begin
        connection.connect
        execute_commands_on_host(host, connection, host_results)
      rescue StandardError => e
        handle_host_execution_error(host, e, host_results)
      ensure
        connection.cleanup
      end

      host_results
    end

    def initialize_host_results
      {
        success: true,
        commands: {},
        error: nil
      }
    end

    def execute_commands_on_host(host, connection, host_results)
      @commands.each do |command|
        next unless command.should_run_on?(host)

        command_success = command.execute(host, connection)
        record_command_result(command, command_success, host_results)

        break if should_stop_command_execution?(command_success, host_results)
      end
    end

    def record_command_result(command, success, host_results)
      host_results[:commands][command.name] = {
        success: success,
        result: command.result
      }

      return if success

      host_results[:success] = false
      host_results[:error] = "Command '#{command.name}' failed" if @options[:fail_fast]
    end

    def should_stop_command_execution?(command_success, host_results)
      !command_success && @options[:fail_fast] && host_results[:error]
    end

    def handle_host_execution_error(host, error, host_results)
      KdeployLogger.error("Task '#{@name}' failed on #{host}: #{error.message}")
      host_results[:success] = false
      host_results[:error] = error.message
    end

    def count_successful_hosts(results)
      results.values.count { |r| r[:success] }
    end

    def log_task_completion(duration, success_count)
      KdeployLogger.info(
        "Task '#{@name}' completed in #{duration.round(2)}s: " \
        "#{success_count}/#{@hosts.size} hosts successful"
      )
    end

    def build_task_result(results, duration, success_count)
      task_result = {
        success: calculate_overall_success(results, success_count),
        results: results,
        duration: duration,
        hosts_count: @hosts.size,
        success_count: success_count
      }

      record_task_statistics(task_result)
      task_result
    end

    def calculate_overall_success(results, success_count)
      @options[:fail_fast] ? results.values.all? { |r| r[:success] } : success_count.positive?
    end

    def record_task_statistics(task_result)
      Kdeploy.statistics.record_task(@name, task_result)
    end
  end
end
