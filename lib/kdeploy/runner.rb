# frozen_string_literal: true

require 'concurrent'

module Kdeploy
  class Runner
    def initialize(hosts, tasks, parallel: 5)
      @hosts = hosts
      @tasks = tasks
      @parallel = parallel
      @pool = Concurrent::FixedThreadPool.new(@parallel)
      @results = Concurrent::Hash.new
    end

    def run(task_name)
      task = @tasks[task_name]
      raise "Task not found: #{task_name}" unless task

      futures = @hosts.map do |name, config|
        Concurrent::Future.execute(executor: @pool) do
          executor = Executor.new(config)
          result = { status: :success, output: [] }

          task[:block].call.each do |command|
            case command[:type]
            when :run
              output = executor.execute(command[:command])
              result[:output] << { command: command[:command], output: output }
            when :upload
              executor.upload(command[:source], command[:destination])
              result[:output] << { command: "upload: #{command[:source]} -> #{command[:destination]}" }
            when :upload_template
              executor.upload_template(command[:source], command[:destination], command[:variables])
              result[:output] << { command: "upload_template: #{command[:source]} -> #{command[:destination]}" }
            end
          end

          @results[name] = result
        rescue StandardError => e
          @results[name] = { status: :failed, error: e.message }
        end
      end

      futures.each(&:wait)
      @results
    ensure
      @pool.shutdown
    end
  end
end
