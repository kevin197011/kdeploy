# frozen_string_literal: true

module Kdeploy
  # Executes a single command and records execution time
  class CommandExecutor
    def initialize(executor, output, debug: false, retries: 0, retry_delay: 1)
      @executor = executor
      @output = output
      @debug = debug
      @retries = retries.to_i
      @retry_delay = retry_delay.to_f
    end

    def execute_run(command, _host_name)
      cmd = command[:command]
      use_sudo = command[:sudo]

      result, duration = measure_time do
        with_retries { @executor.execute(cmd, use_sudo: use_sudo) }
      end

      { command: cmd, output: result, duration: duration, type: :run }
    end

    def execute_upload(command, _host_name)
      _result, duration = measure_time do
        with_retries { @executor.upload(command[:source], command[:destination]) }
      end
      {
        command: "upload: #{command[:source]} -> #{command[:destination]}",
        duration: duration,
        type: :upload
      }
    end

    def execute_upload_template(command, _host_name)
      _result, duration = measure_time do
        with_retries do
          @executor.upload_template(command[:source], command[:destination], command[:variables])
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

      result, duration = measure_time do
        with_retries do
          @executor.sync_directory(
            source,
            destination,
            ignore: command[:ignore] || [],
            exclude: command[:exclude] || [],
            delete: command[:delete] || false
          )
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

    def with_retries
      attempts = 0
      begin
        attempts += 1
        yield
      rescue SSHError, SCPError, TemplateError
        raise if attempts > (@retries + 1)

        sleep(@retry_delay) if @retry_delay.positive?
        retry
      end
    end
  end
end
