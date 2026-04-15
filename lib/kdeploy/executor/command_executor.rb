# frozen_string_literal: true

require 'timeout'

module Kdeploy
  # Executes a single command and records execution time
  class CommandExecutor
    def initialize(executor, output, debug: false, retries: 0, retry_delay: 1, retry_on_nonzero: false,
                   step_timeout: nil, retry_policy: nil)
      @executor = executor
      @output = output
      @debug = debug
      @retries = retries.to_i
      @retry_delay = retry_delay.to_f
      @retry_on_nonzero = retry_on_nonzero
      @step_timeout = step_timeout&.to_f
      @retry_policy = retry_policy
    end

    def execute_run(command, _host_name)
      cmd = command[:command]
      use_sudo = command[:sudo]

      result, duration = measure_time do
        with_retries(step_type: :run) do
          with_timeout { @executor.execute(cmd, use_sudo: use_sudo) }
        end
      end

      { command: cmd, output: result, duration: duration, type: :run }
    end

    def execute_upload(command, _host_name)
      _result, duration = measure_time do
        with_retries(step_type: :upload) do
          with_timeout { @executor.upload(command[:source], command[:destination]) }
        end
      end
      {
        command: "upload: #{command[:source]} -> #{command[:destination]}",
        duration: duration,
        type: :upload
      }
    end

    def execute_upload_template(command, _host_name)
      _result, duration = measure_time do
        with_retries(step_type: :upload_template) do
          with_timeout do
            @executor.upload_template(command[:source], command[:destination], command[:variables])
          end
        end
      end
      {
        command: "upload_template: #{command[:source]} -> #{command[:destination]}",
        duration: duration,
        type: :upload_template
      }
    end

    def execute_sync(command, _host_name)
      source = command[:source]
      destination = command[:destination]
      fast = command.key?(:fast) ? command[:fast] : Configuration.default_sync_fast
      parallel = command.key?(:parallel) ? command[:parallel] : Configuration.default_sync_parallel

      result, duration = measure_time do
        with_retries(step_type: :sync) do
          with_timeout do
            @executor.sync_directory(
              source,
              destination,
              ignore: command[:ignore] || [],
              exclude: command[:exclude] || [],
              delete: command[:delete] || false,
              fast: fast,
              parallel: parallel
            )
          end
        end
      end

      build_sync_result(source, destination, result, duration)
    end

    private

    def build_sync_result(source, destination, result, duration)
      {
        command: "sync: #{source} -> #{destination}",
        duration: duration,
        type: :sync,
        result: result,
        uploaded: result[:uploaded],
        deleted: result[:deleted],
        total: result[:total]
      }
    end

    def measure_time
      start_time = Time.now
      result = yield
      duration = Time.now - start_time
      [result, duration]
    end

    def with_retries(step_type: nil)
      attempts = 0
      max_retries = retries_for(step_type)
      exit_codes = retry_exit_codes_for(step_type)
      begin
        attempts += 1
        yield
      rescue SSHError, SCPError, TemplateError => e
        raise if e.is_a?(SSHError) && e.exit_status && !retry_on_exit_status?(e.exit_status, exit_codes)
        raise if attempts > (max_retries + 1)

        sleep(@retry_delay) if @retry_delay.positive?
        retry
      end
    end

    def with_timeout(&block)
      return yield unless @step_timeout&.positive?

      Timeout.timeout(@step_timeout, &block)
    rescue Timeout::Error
      raise StepTimeoutError, "exceeded #{@step_timeout}s"
    end

    def retries_for(step_type)
      return @retries unless @retry_policy.is_a?(Hash) && step_type

      policy = @retry_policy[step_type.to_s] || @retry_policy[step_type.to_sym]
      return @retries unless policy.is_a?(Hash)

      policy.fetch('retries', policy.fetch(:retries, @retries)).to_i
    end

    def retry_exit_codes_for(step_type)
      return nil unless @retry_policy.is_a?(Hash) && step_type

      policy = @retry_policy[step_type.to_s] || @retry_policy[step_type.to_sym]
      return nil unless policy.is_a?(Hash)

      policy['retry_on_exit_codes'] || policy[:retry_on_exit_codes]
    end

    def retry_on_exit_status?(exit_status, exit_codes)
      return @retry_on_nonzero if exit_codes.nil?

      Array(exit_codes).map(&:to_i).include?(exit_status.to_i)
    end
  end
end
