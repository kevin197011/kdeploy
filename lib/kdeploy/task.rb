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

    def global_variables=(vars)
      @global_variables = vars || {}
    end

    # Add command to task
    # @param command [String, Command] Command to execute or Command object
    # @param options [Hash] Command options (ignored if command is a Command object)
    def add_command(command, options = {})
      if command.is_a?(Command)
        @commands << command
      else
        # Include global variables in command options
        command_options = options.merge(global_variables: @global_variables)
        @commands << Command.new(options[:name] || command.split.first || 'unnamed', command, command_options)
      end
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
        success_count: success_count,
        task_name: @name
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
      end

      results
    end

    def execute_on_host(host)
      connection = nil
      host_results = {
        success: true,
        commands: {},
        error: nil
      }

      begin
        connection = SSHConnection.new(host)
        connection.connect unless host.hostname == 'localhost'

        @commands.each do |command|
          next unless command.should_run_on?(host)

          command_success = command.execute(host, connection)
          host_results[:commands][command.name] = {
            success: command_success,
            result: command.result
          }

          next if command_success || command.options[:ignore_errors]

          host_results[:success] = false
          host_results[:error] = "Command '#{command.name}' failed"
          break if @options[:fail_fast]
        end
      rescue StandardError => e
        KdeployLogger.error("Task '#{@name}' failed on #{host}: #{e.message}")
        host_results[:success] = false
        host_results[:error] = e.message
      ensure
        connection&.cleanup if connection && host.hostname != 'localhost'
      end

      host_results
    end
  end
end
