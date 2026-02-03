# frozen_string_literal: true

require 'concurrent'

module Kdeploy
  # Concurrent task runner for executing tasks across multiple hosts
  class Runner
    def initialize(hosts, tasks, parallel: Configuration.default_parallel, output: ConsoleOutput.new,
                   debug: false, base_dir: nil, retries: Configuration.default_retries,
                   retry_delay: Configuration.default_retry_delay)
      @hosts = hosts
      @tasks = tasks
      @parallel = parallel
      @output = output
      @debug = debug
      @base_dir = base_dir
      @retries = retries
      @retry_delay = retry_delay
      @pool = Concurrent::FixedThreadPool.new(@parallel)
      @results = Concurrent::Hash.new
    end

    def run(task_name)
      task = find_task(task_name)
      execute_concurrent_tasks(task, task_name)
    ensure
      @pool.shutdown
    end

    def find_task(task_name)
      task = @tasks[task_name]

      raise TaskNotFoundError, task_name unless task

      task
    end

    def execute_concurrent_tasks(task, task_name)
      futures = create_task_futures(task, task_name)

      # If no hosts, return empty results immediately
      return @results if futures.empty?

      # Collect results from futures
      futures.each_with_index do |future, index|
        host_name = @host_names[index] # Get host name from the stored list
        begin
          # Wait for future to complete and get its value
          # This ensures the future has finished executing
          future_result = future.value

          # Handle the result
          if future_result.nil?
            # Future returned nil - create a default result
            @results[host_name] = { status: :unknown, error: 'Future returned nil', output: [] }
          elsif future_result.is_a?(Array) && future_result.length == 2
            name, result = future_result
            # Store the result using the name from the future
            @results[name] = result
          else
            # Handle unexpected result format - create a default result
            @results[host_name] = {
              status: :unknown,
              error: "Unexpected result format: #{future_result.class}",
              output: []
            }
          end

          # Check if future raised an exception
          if future.rejected?
            error = begin
              future.reason
            rescue StandardError
              'Unknown error'
            end
            @results[host_name] = { status: :failed, error: error, output: [] } unless @results.key?(host_name)
          end
        rescue StandardError => e
          # If future.value raises an exception, create an error result
          @results[host_name] = { status: :failed, error: "#{e.class}: #{e.message}", output: [] }
        ensure
          # Ensure we always have a result for this host
          @results[host_name] ||= { status: :unknown, error: 'No result collected', output: [] }
        end
      end

      @results
    end

    def create_task_futures(task, task_name)
      # Store host names in order to match with futures
      @host_names = @hosts.keys
      @hosts.map do |name, config|
        Concurrent::Future.execute(executor: @pool) do
          execute_task_for_host(name, config, task, task_name)
        end
      end
    end

    private

    def execute_task_for_host(name, config, task, task_name)
      # Add base_dir to config for path resolution
      config_with_base_dir = config.merge(base_dir: @base_dir)
      executor = Executor.new(config_with_base_dir)
      command_executor = CommandExecutor.new(
        executor,
        @output,
        debug: @debug,
        retries: @retries,
        retry_delay: @retry_delay
      )
      result = { status: :success, output: [] }

      begin
        execute_commands(task, command_executor, name, result, task_name)
      rescue StandardError => e
        # Keep any already collected step output for troubleshooting.
        result[:status] = :failed
        result[:error] = "#{e.class}: #{e.message}"
      end

      # Return the result so it can be collected from the future
      [name, result]
    end

    def execute_commands(task, command_executor, name, result, task_name)
      commands = task[:block].call

      commands.each do |command|
        step_result = execute_command(command_executor, command, name)
        result[:output] << step_result
      rescue StandardError => e
        step = step_description(command)
        result[:status] = :failed
        result[:error] = "task=#{task_name} host=#{name} step=#{step} error=#{e.class}: #{e.message}"
        result[:output] << {
          type: command[:type],
          command: step_command_string(command),
          duration: 0.0,
          error: "#{e.class}: #{e.message}",
          output: error_output_for_step(e)
        }
        break
      end
    end

    def error_output_for_step(error)
      return nil unless error.is_a?(Kdeploy::SSHError)

      {
        stdout: error.stdout,
        stderr: error.stderr,
        exit_status: error.exit_status,
        command: error.command
      }
    end

    def execute_command(command_executor, command, host_name)
      case command[:type]
      when :run
        command_executor.execute_run(command, host_name)
      when :upload
        command_executor.execute_upload(command, host_name)
      when :upload_template
        command_executor.execute_upload_template(command, host_name)
      when :sync
        command_executor.execute_sync(command, host_name)
      else
        raise ConfigurationError, "Unknown command type: #{command[:type]}"
      end
    end

    def step_command_string(command)
      case command[:type]
      when :run
        command[:command].to_s
      when :upload
        "upload: #{command[:source]} -> #{command[:destination]}"
      when :upload_template
        "upload_template: #{command[:source]} -> #{command[:destination]}"
      when :sync
        "sync: #{command[:source]} -> #{command[:destination]}"
      else
        command[:type].to_s
      end
    end

    def step_description(command)
      case command[:type]
      when :run
        first = command[:command].to_s.lines.first&.strip
        "run: #{first}"
      when :upload
        "upload: #{command[:source]} -> #{command[:destination]}"
      when :upload_template
        "upload_template: #{command[:source]} -> #{command[:destination]}"
      when :sync
        "sync: #{command[:source]} -> #{command[:destination]}"
      else
        command[:type].to_s
      end
    end
  end
end
