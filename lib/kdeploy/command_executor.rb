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

    def execute_run(command, host_name)
      cmd = command[:command]
      use_sudo = command[:sudo]
      show_command_header(host_name, :run, cmd)

      # Show progress indicator for long-running commands
      pastel = @output.respond_to?(:pastel) ? @output.pastel : Pastel.new

      result, duration = measure_time do
        with_retries { @executor.execute(cmd, use_sudo: use_sudo) }
      end

      # Show execution time if command took more than 1 second
      @output.write_line(pastel.dim("    [completed in #{format('%.2f', duration)}s]")) if duration > 1.0

      { command: cmd, output: result, duration: duration, type: :run }
    end

    def execute_upload(command, host_name)
      show_command_header(host_name, :upload, "#{command[:source]} -> #{command[:destination]}")
      _result, duration = measure_time do
        with_retries { @executor.upload(command[:source], command[:destination]) }
      end
      {
        command: "upload: #{command[:source]} -> #{command[:destination]}",
        duration: duration,
        type: :upload
      }
    end

    def execute_upload_template(command, host_name)
      show_command_header(host_name, :upload_template, "#{command[:source]} -> #{command[:destination]}")
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

    def execute_sync(command, host_name)
      source = command[:source]
      destination = command[:destination]
      description = build_sync_description(source, destination, command[:delete])
      show_command_header(host_name, :sync, description)

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

    def build_sync_description(source, destination, delete)
      desc = "sync: #{source} -> #{destination}"
      desc += " (delete: #{delete})" if delete
      desc
    end

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

    def show_command_header(host_name, type, description)
      # Don't show command header during execution - it will be shown in results
      # This reduces noise during execution
    end

    def pastel_instance
      @output.respond_to?(:pastel) ? @output.pastel : Pastel.new
    end

    def format_command_by_type(type, description, pastel)
      case type
      when :run
        format_run_command(description, pastel)
      when :upload
        @output.write_line(pastel.green("  [upload] #{description}"))
      when :upload_template
        @output.write_line(pastel.yellow("  [template] #{description}"))
      end
    end

    def format_run_command(description, pastel)
      @output.write_line(pastel.cyan("  [run]    #{description.lines.first.strip}"))
      description.lines[1..].each do |line|
        @output.write_line("           > #{line.strip}") unless line.strip.empty?
      end
    end
  end
end
