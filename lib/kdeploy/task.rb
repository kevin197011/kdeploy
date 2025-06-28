# frozen_string_literal: true

module Kdeploy
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
    def add_command(name, command, options = {})
      # Include global variables in command options
      command_options = options.merge(global_variables: @global_variables)
      @commands << Command.new(name, command, command_options)
    end

    # Add host to task
    # @param host [Host] Host to add
    def add_host(host)
      @hosts << host unless @hosts.include?(host)
    end

    # Remove host from task
    # @param host [Host] Host to remove
    def remove_host(host)
      @hosts.delete(host)
    end

    # Execute task on all hosts
    # @return [Hash] Execution results
    def execute
      return { success: true, results: {} } if @commands.empty? || @hosts.empty?

      KdeployLogger.info("Starting task '#{@name}' on #{@hosts.size} host(s)")

      start_time = Time.now

      results = if @options[:parallel]
                  execute_parallel
                else
                  execute_sequential
                end

      duration = Time.now - start_time
      success_count = results.values.count { |r| r[:success] }

      KdeployLogger.info("Task '#{@name}' completed in #{duration.round(2)}s: #{success_count}/#{@hosts.size} hosts successful")

      overall_success = @options[:fail_fast] ? results.values.all? { |r| r[:success] } : success_count.positive?

      task_result = {
        success: overall_success,
        results: results,
        duration: duration,
        hosts_count: @hosts.size,
        success_count: success_count
      }

      # Record task statistics
      Kdeploy.statistics.record_task(@name, task_result)

      task_result
    end

    private

    def default_options
      {
        parallel: true,
        fail_fast: false,
        max_concurrent: nil
      }
    end

    def execute_parallel
      max_concurrent = @options[:max_concurrent] || Kdeploy.configuration&.max_concurrent_tasks || 10
      pool = Concurrent::ThreadPoolExecutor.new(
        min_threads: 1,
        max_threads: [max_concurrent, @hosts.size].min
      )

      futures = @hosts.map do |host|
        Concurrent::Future.execute(executor: pool) do
          execute_on_host(host)
        end
      end

      results = {}
      futures.each_with_index do |future, index|
        host = @hosts[index]
        results[host.hostname] = future.value
      end

      pool.shutdown
      pool.wait_for_termination(30)

      results
    end

    def execute_sequential
      results = {}

      @hosts.each do |host|
        results[host.hostname] = execute_on_host(host)

        if @options[:fail_fast] && !results[host.hostname][:success]
          KdeployLogger.error("Task '#{@name}' failed on #{host}, stopping execution due to fail_fast option")
          break
        end
      end

      results
    end

    def execute_on_host(host)
      connection = SSHConnection.new(host)
      host_results = {
        success: true,
        commands: {},
        error: nil
      }

      begin
        connection.connect

        @commands.each do |command|
          next unless command.should_run_on?(host)

          command_success = command.execute(host, connection)
          host_results[:commands][command.name] = {
            success: command_success,
            result: command.result
          }

          next if command_success

          host_results[:success] = false
          if @options[:fail_fast]
            host_results[:error] = "Command '#{command.name}' failed"
            break
          end
        end
      rescue StandardError => e
        KdeployLogger.error("Task '#{@name}' failed on #{host}: #{e.message}")
        host_results[:success] = false
        host_results[:error] = e.message
      ensure
        connection.cleanup
      end

      host_results
    end
  end
end
