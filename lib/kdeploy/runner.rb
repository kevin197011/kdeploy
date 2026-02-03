# frozen_string_literal: true

require 'concurrent'

module Kdeploy
  # Concurrent task runner for executing tasks across multiple hosts
  class Runner
    def initialize(hosts, tasks, parallel: Configuration.default_parallel, output: ConsoleOutput.new,
                   debug: false, base_dir: nil, retries: Configuration.default_retries,
                   retry_delay: Configuration.default_retry_delay,
                   retry_on_nonzero: Configuration.default_retry_on_nonzero,
                   host_timeout: Configuration.default_host_timeout)
      @hosts = hosts
      @tasks = tasks
      @parallel = parallel
      @output = output
      @debug = debug
      @base_dir = base_dir
      @retries = retries
      @retry_delay = retry_delay
      @retry_on_nonzero = retry_on_nonzero
      @host_timeout = normalize_timeout(host_timeout)
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

      pending = futures.dup

      until pending.empty?
        progressed = false
        now = Time.now

        pending.dup.each do |future|
          meta = @future_meta[future]
          host_name = meta[:host_name]
          started_at = meta[:started_at].get

          if future.fulfilled? || future.rejected?
            collect_future_result(future, host_name)
            pending.delete(future)
            progressed = true
          elsif timeout_exceeded?(started_at, now)
            @results[host_name] ||= {
              status: :failed,
              error: "execution timeout after #{@host_timeout}s",
              output: []
            }
            pending.delete(future)
            progressed = true
          end
        end

        sleep(0.05) unless progressed
      end

      @results
    end

    def create_task_futures(task, task_name)
      @future_meta = {}
      @hosts.map do |name, config|
        started_at = Concurrent::AtomicReference.new(nil)
        future = Concurrent::Future.execute(executor: @pool) do
          started_at.set(Time.now)
          execute_task_for_host(name, config, task, task_name)
        end
        @future_meta[future] = { host_name: name, started_at: started_at }
        future
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
        retry_delay: @retry_delay,
        retry_on_nonzero: @retry_on_nonzero
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
        result[:error] = build_step_error(task_name, name, step, e)
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

    def collect_future_result(future, host_name)
      return if @results.key?(host_name)

      begin
        future_result = future.value
        if future_result.nil?
          @results[host_name] = { status: :unknown, error: 'Future returned nil', output: [] }
        elsif future_result.is_a?(Array) && future_result.length == 2
          name, result = future_result
          @results[name] = result
        else
          @results[host_name] = {
            status: :unknown,
            error: "Unexpected result format: #{future_result.class}",
            output: []
          }
        end

        if future.rejected?
          error = begin
            future.reason
          rescue StandardError
            'Unknown error'
          end
          @results[host_name] ||= { status: :failed, error: error, output: [] }
        end
      rescue StandardError => e
        @results[host_name] = { status: :failed, error: "#{e.class}: #{e.message}", output: [] }
      ensure
        @results[host_name] ||= { status: :unknown, error: 'No result collected', output: [] }
      end
    end

    def timeout_exceeded?(started_at, now)
      return false unless @host_timeout
      return false if started_at.nil?

      (now - started_at) > @host_timeout
    end

    def normalize_timeout(timeout)
      return nil if timeout.nil?

      timeout = timeout.to_f
      timeout.positive? ? timeout : nil
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

    def build_step_error(task_name, host_name, step, error)
      base = "task=#{task_name} host=#{host_name} step=#{step} error=#{error.class}: #{error.message}"
      return base unless error.is_a?(Kdeploy::SSHError)

      if error.exit_status
        "#{base} exit_status=#{error.exit_status} command=#{error.command}"
      else
        base
      end
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
