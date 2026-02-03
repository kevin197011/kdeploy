# frozen_string_literal: true

require 'json'
require 'stringio'

require 'kdeploy'

require_relative 'models'

module Kdeploy
  module Web
    # Adapter to execute kdeploy tasks from a stored job definition.
    module ExecutionAdapter
      class Runtime
        extend Kdeploy::DSL
      end

      class << self
        def execute(task_file_path:, task_name:, limit:, parallel:, retries:, retry_delay:, format:)
          runtime = build_runtime(task_file_path)
          selected_task =
            if task_name && !task_name.to_s.strip.empty?
              task_name.to_sym
            else
              runtime.kdeploy_tasks.keys.first
            end
          raise "task not found: #{task_name}" unless runtime.kdeploy_tasks.key?(selected_task)

          task_hosts = runtime.get_task_hosts(selected_task)
          hosts = runtime.kdeploy_hosts.slice(*task_hosts)
          hosts = filter_hosts(limit, hosts) if limit && !limit.to_s.strip.empty?
          raise "no hosts matched for task=#{selected_task}" if hosts.empty?

          base_dir = File.dirname(File.expand_path(task_file_path))
          host_timeout = env_float('JOB_CONSOLE_HOST_TIMEOUT') || Kdeploy::Configuration.default_host_timeout
          retry_on_nonzero = env_bool('JOB_CONSOLE_RETRY_ON_NONZERO', default: Kdeploy::Configuration.default_retry_on_nonzero)
          runner = Kdeploy::Runner.new(
            hosts,
            runtime.kdeploy_tasks,
            parallel: parallel || Kdeploy::Configuration.default_parallel,
            output: Kdeploy::SilentOutput.new,
            debug: false,
            base_dir: base_dir,
            retries: retries || Kdeploy::Configuration.default_retries,
            retry_delay: retry_delay || Kdeploy::Configuration.default_retry_delay,
            retry_on_nonzero: retry_on_nonzero,
            host_timeout: host_timeout
          )

          results = runner.run(selected_task)
          json_output = JSON.generate(
            task: selected_task.to_s,
            results: results.transform_values { |r| serialize_result(r) }
          )

          text_output = render_text(selected_task, results)

          return [results, nil, json_output] if format.to_s == 'json'

          [results, text_output, json_output]
        end

        def ensure_task_path_allowed!(task_file_path)
          base_dir = ENV.fetch('JOB_CONSOLE_TASK_BASE_DIR') do
            raise 'JOB_CONSOLE_TASK_BASE_DIR is required'
          end

          base_dir = File.expand_path(base_dir)
          raise 'JOB_CONSOLE_TASK_BASE_DIR must be a directory' unless File.directory?(base_dir)

          path = File.expand_path(task_file_path)
          raise "task file not found: #{task_file_path}" unless File.exist?(path)

          base_prefix = base_dir.end_with?(File::SEPARATOR) ? base_dir : "#{base_dir}#{File::SEPARATOR}"
          unless path == base_dir || path.start_with?(base_prefix)
            raise "task file outside base dir: #{path}"
          end

          path
        end

        private

        def build_runtime(task_file_path)
          path = ensure_task_path_allowed!(task_file_path)
          runtime = Class.new(Runtime)
          runtime.module_eval(File.read(path), path)
          runtime
        end

        def filter_hosts(limit, hosts)
          names = limit.to_s.split(',').map(&:strip)
          hosts.slice(*names)
        end

        def serialize_result(result)
          {
            status: result[:status].to_s,
            error: result[:error],
            steps: Array(result[:output]).map { |s| s.transform_keys(&:to_s) }
          }
        end

        def render_text(task_name, results)
          formatter = Kdeploy::OutputFormatter.new(debug: false)
          io = StringIO.new

          io.puts formatter.format_task_header(task_name)
          results.each do |host, result|
            io.puts formatter.format_host_status(host, result[:status])
            if %i[success changed].include?(result[:status])
              shown = {}
              grouped = (result[:output] || []).group_by { |step| step[:type] || :run }
              grouped.each do |type, steps|
                lines =
                  case type
                  when :upload then formatter.format_upload_steps(steps, shown)
                  when :upload_template then formatter.format_template_steps(steps, shown)
                  when :sync then formatter.format_sync_steps(steps, shown)
                  when :run then formatter.format_run_steps(steps, shown)
                  else []
                  end
                lines.each { |l| io.puts l }
              end
            else
              io.puts formatter.format_error(result[:error].to_s)
            end
          end

          io.string
        end

        def env_float(key)
          raw = ENV.fetch(key, nil)
          return nil if raw.nil? || raw.to_s.strip.empty?

          raw.to_f
        end

        def env_bool(key, default: false)
          raw = ENV.fetch(key, nil)
          return default if raw.nil? || raw.to_s.strip.empty?

          %w[1 true yes on].include?(raw.to_s.downcase)
        end
      end
    end
  end
end
