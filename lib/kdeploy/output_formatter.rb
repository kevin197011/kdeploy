# frozen_string_literal: true

require 'pastel'
require 'tty-box'

module Kdeploy
  # Formats and displays execution results
  class OutputFormatter
    def initialize
      @pastel = Pastel.new
    end

    def format_task_header(task_name)
      @pastel.cyan("\nPLAY [#{task_name}] " + ('*' * 64))
    end

    def format_host_status(host, status)
      status_str = case status
                   when :success then @pastel.green('ok')
                   when :changed then @pastel.yellow('changed')
                   else @pastel.red('failed')
                   end
      @pastel.bright_white("\n#{host.ljust(24)} : #{status_str}")
    end

    def format_upload_steps(steps, shown)
      format_file_steps(steps, shown, :upload, @pastel.green('  === Upload ==='), 'upload: ')
    end

    def format_template_steps(steps, shown)
      format_file_steps(steps, shown, :upload_template, @pastel.yellow('  === Template ==='), 'upload_template: ')
    end

    def format_file_steps(steps, shown, type, header, prefix)
      output = [header]
      steps.each do |step|
        next if step_already_shown?(step, type, shown)

        mark_step_as_shown(step, type, shown)
        output << format_file_step(step, type, prefix)
      end
      output
    end

    def format_file_step(step, type, prefix)
      duration_str = format_duration(step[:duration])
      label = type == :upload ? '[upload]' : '[template]'
      color("    #{label} #{step[:command].sub(prefix, '')}#{duration_str}")
    end

    def format_run_steps(steps, shown)
      output = []
      output << @pastel.cyan('  === Run ===')
      steps.each do |step|
        next if step_already_shown?(step, :run, shown)

        mark_step_as_shown(step, :run, shown)
        output.concat(format_single_run_step(step))
      end
      output
    end

    def format_single_run_step(step)
      output = []
      duration_str = format_duration(step[:duration])
      command_line = step[:command].to_s.lines.first.strip
      output << @pastel.cyan("    [run]    #{command_line}#{duration_str}")
      output.concat(format_multiline_command(step[:command]))
      # Format and add command output (stdout/stderr)
      cmd_output = format_command_output(step[:output])
      output.concat(cmd_output) if cmd_output.any?
      output
    end

    def format_error(error_message)
      @pastel.red("  ERROR: #{error_message}")
    end

    def format_summary_header
      @pastel.cyan("\nPLAY RECAP #{'*' * 64}")
    end

    def format_summary_line(host, result, max_host_len)
      counts = calculate_summary_counts(result)
      line = build_summary_line(host, counts, max_host_len)
      colorize_summary_line(line, counts)
    end

    def calculate_summary_counts(result)
      ok = %i[success changed].include?(result[:status]) ? result[:output].size : 0
      failed = result[:status] == :failed ? 1 : 0
      changed = result[:status] == :changed ? result[:output].size : 0
      { ok: ok, failed: failed, changed: changed }
    end

    def build_summary_line(host, counts, max_host_len)
      ok_w = 7
      changed_w = 11
      failed_w = 10

      ok_str = @pastel.green("ok=#{counts[:ok].to_s.ljust(ok_w - 3)}")
      changed_str = @pastel.yellow("changed=#{counts[:changed].to_s.ljust(changed_w - 8)}")
      failed_str = @pastel.red("failed=#{counts[:failed].to_s.ljust(failed_w - 7)}")
      "#{host.ljust(max_host_len)} : #{ok_str}  #{changed_str}  #{failed_str}"
    end

    def colorize_summary_line(line, counts)
      if counts[:failed].positive?
        @pastel.red(line)
      elsif counts[:ok].positive? && counts[:failed].zero?
        @pastel.green(line)
      else
        line
      end
    end

    def format_dry_run_box(title, content)
      TTY::Box.frame(
        content,
        title: { top_left: " #{title} " },
        style: {
          border: {
            fg: :yellow
          }
        }
      )
    end

    def format_dry_run_header
      TTY::Box.frame(
        'Showing what would be done without executing any commands',
        title: { top_left: ' Dry Run Mode ', bottom_right: ' Kdeploy ' },
        style: {
          border: {
            fg: :blue
          }
        }
      )
    end

    def format_command_for_dry_run(command)
      case command[:type]
      when :run
        "#{@pastel.green('>')} #{command[:command]}"
      when :upload
        "#{@pastel.blue('>')} Upload: #{command[:source]} -> #{command[:destination]}"
      when :upload_template
        "#{@pastel.blue('>')} Template: #{command[:source]} -> #{command[:destination]}"
      else
        "#{@pastel.blue('>')} #{command[:type]}: #{command}"
      end
    end

    private

    def format_duration(duration)
      duration ? @pastel.dim(" [#{format('%.2f', duration)}s]") : ''
    end

    def format_multiline_command(command)
      output = []
      cmd_lines = command.to_s.lines[1..].map(&:strip).reject(&:empty?)
      cmd_lines.each { |line| output << @pastel.cyan("           > #{line}") } if cmd_lines.any?
      output
    end

    def format_command_output(output)
      result = []
      return result unless output

      if output.is_a?(Hash)
        format_hash_output(output, result)
      elsif output.is_a?(String) && !output.strip.empty?
        format_stdout_lines(output, result)
      end
      result
    end

    def format_hash_output(output, result)
      format_stdout_from_hash(output, result)
      format_stderr_from_hash(output, result)
    end

    def format_stdout_from_hash(output, result)
      return unless output.key?(:stdout)

      stdout = output[:stdout]
      format_stdout_lines(stdout, result) if stdout && !stdout.to_s.strip.empty?
    end

    def format_stderr_from_hash(output, result)
      return unless output.key?(:stderr)

      stderr = output[:stderr]
      format_stderr_lines(stderr, result) if stderr && !stderr.to_s.strip.empty?
    end

    def format_stdout_lines(stdout, result)
      return result if stdout.nil? || stdout.to_s.empty?

      stdout.to_s.each_line do |line|
        stripped = line.rstrip
        # Show all non-empty lines
        result << @pastel.green("        #{stripped}") unless stripped.empty?
      end
      result
    end

    def format_stderr_lines(stderr, result)
      return result if stderr.nil? || stderr.to_s.empty?

      stderr.to_s.each_line do |line|
        stripped = line.rstrip
        # Show all non-empty stderr lines in yellow
        result << @pastel.yellow("        #{stripped}") unless stripped.empty?
      end
      result
    end

    def step_already_shown?(step, type, shown)
      key = [step[:command], type].hash
      shown[key]
    end

    def mark_step_as_shown(step, type, shown)
      key = [step[:command], type].hash
      shown[key] = true
    end
  end
end
