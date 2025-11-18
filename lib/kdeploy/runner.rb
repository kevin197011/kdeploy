# frozen_string_literal: true

require 'concurrent'

module Kdeploy
  # Concurrent task runner for executing tasks across multiple hosts
  class Runner
    def initialize(hosts, tasks, parallel: Configuration.default_parallel, output: ConsoleOutput.new)
      @hosts = hosts
      @tasks = tasks
      @parallel = parallel
      @output = output
      @pool = Concurrent::FixedThreadPool.new(@parallel)
      @results = Concurrent::Hash.new
    end

    def run(task_name)
      task = find_task(task_name)
      execute_concurrent_tasks(task)
    ensure
      @pool.shutdown
    end

    def find_task(task_name)
      task = @tasks[task_name]

      raise TaskNotFoundError, task_name unless task

      task
    end

    def execute_concurrent_tasks(task)
      futures = create_task_futures(task)
      futures.each(&:wait)
      @results
    end

    def create_task_futures(task)
      @hosts.map do |name, config|
        Concurrent::Future.execute(executor: @pool) do
          execute_task_for_host(name, config, task)
        end
      end
    end

    private

    def execute_task_for_host(name, config, task)
      executor = Executor.new(config)
      command_executor = CommandExecutor.new(executor, @output)
      result = { status: :success, output: [] }

      execute_grouped_commands(task, command_executor, name, result)
      @results[name] = result
    rescue StandardError => e
      @results[name] = { status: :failed, error: e.message }
    end

    def execute_grouped_commands(task, command_executor, name, result)
      commands = task[:block].call
      grouped_commands = CommandGrouper.group(commands)

      grouped_commands.each_value do |command_group|
        execute_command_group(command_group, command_executor, name, result)
      end
    end

    def execute_command_group(command_group, command_executor, name, result)
      first_cmd = command_group.first
      task_desc = CommandGrouper.task_description(first_cmd)
      show_task_header(task_desc)

      command_group.each do |command|
        step_result = execute_command(command_executor, command, name)
        result[:output] << step_result
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
      else
        raise ConfigurationError, "Unknown command type: #{command[:type]}"
      end
    end

    def show_task_header(task_desc)
      pastel = @output.respond_to?(:pastel) ? @output.pastel : Pastel.new
      @output.write_line(pastel.cyan("\nTASK [#{task_desc}] " + ('*' * 64)))
    end
  end
end
