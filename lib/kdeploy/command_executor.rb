# frozen_string_literal: true

module Kdeploy
  # Executes a single command and records execution time
  class CommandExecutor
    def initialize(executor, output)
      @executor = executor
      @output = output
    end

    def execute_run(command, host_name)
      cmd = command[:command]
      use_sudo = command[:sudo]
      show_command_header(host_name, :run, cmd)

      # Show progress indicator for long-running commands
      pastel = @output.respond_to?(:pastel) ? @output.pastel : Pastel.new
      Time.now

      result, duration = measure_time do
        @executor.execute(cmd, use_sudo: use_sudo)
      end

      # Show execution time if command took more than 1 second
      @output.write_line(pastel.dim("    [completed in #{format('%.2f', duration)}s]")) if duration > 1.0

      # Show command output
      show_command_output(result)
      { command: cmd, output: result, duration: duration, type: :run }
    end

    def execute_upload(command, host_name)
      show_command_header(host_name, :upload, "#{command[:source]} -> #{command[:destination]}")
      _result, duration = measure_time do
        @executor.upload(command[:source], command[:destination])
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
        @executor.upload_template(command[:source], command[:destination], command[:variables])
      end
      {
        command: "upload_template: #{command[:source]} -> #{command[:destination]}",
        duration: duration,
        type: :upload_template
      }
    end

    private

    def measure_time
      start_time = Time.now
      result = yield
      duration = Time.now - start_time
      [result, duration]
    end

    def show_command_output(output)
      return unless output.is_a?(Hash)

      pastel = @output.respond_to?(:pastel) ? @output.pastel : Pastel.new
      show_stdout(output[:stdout])
      show_stderr(output[:stderr], pastel)
    end

    def show_stdout(stdout)
      return unless stdout && !stdout.empty?

      stdout.each_line do |line|
        @output.write_line("    #{line.rstrip}") unless line.strip.empty?
      end
    end

    def show_stderr(stderr, pastel)
      return unless stderr && !stderr.empty?

      stderr.each_line do |line|
        @output.write_line(pastel.green("    #{line.rstrip}")) unless line.strip.empty?
      end
    end

    def show_command_header(host_name, type, description)
      pastel = pastel_instance
      @output.write_line(pastel.bright_white("\n#{host_name.ljust(24)} : "))
      format_command_by_type(type, description, pastel)
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
