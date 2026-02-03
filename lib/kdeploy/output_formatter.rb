# frozen_string_literal: true

require 'pastel'
require 'tty-box'

module Kdeploy
  # Formats and displays execution results
  class OutputFormatter
    def initialize(debug: false)
      @pastel = Pastel.new
      @debug = debug
    end

    def format_task_header(task_name)
      "#{@pastel.bright_cyan("\n🚀 Task: #{task_name}")}\n#{@pastel.dim('─' * 60)}"
    end

    def format_host_status(host, status)
      status_str = case status
                   when :success then @pastel.green('✓ ok')
                   when :changed then @pastel.yellow('~ changed')
                   else @pastel.red('✗ failed')
                   end
      @pastel.bright_white("  #{host.ljust(20)} #{status_str}")
    end

    # Prefix for per-step lines to make multi-host logs easier to scan.
    def host_prefix(host)
      @pastel.dim("  #{host.ljust(20)} ")
    end

    def format_host_completed(duration)
      @pastel.dim("    [completed in #{format('%.2f', duration)}s]")
    end

    def calculate_host_duration(result)
      return 0.0 unless result.is_a?(Hash)

      Array(result[:output]).sum { |step| step[:duration].to_f }
    end

    def format_upload_steps(steps, _shown = nil)
      format_file_steps(steps, :upload, 'upload: ')
    end

    def format_template_steps(steps, _shown = nil)
      format_file_steps(steps, :upload_template, 'upload_template: ')
    end

    def format_sync_steps(steps, _shown = nil)
      steps.map { |step| format_sync_step(step) }
    end

    def format_file_steps(steps, type, prefix)
      steps.map { |step| format_file_step(step, type, prefix) }
    end

    def format_file_step(step, type, prefix)
      duration_str = format_duration(step[:duration])
      status_str = format_step_status(step)
      icon = type == :upload ? '📤' : '📝'
      file_path = step[:command].sub(prefix, '')
      # Truncate long paths for cleaner output
      display_path = file_path.length > 50 ? "...#{file_path[-47..]}" : file_path
      color_method = type == :upload ? :green : :yellow
      @pastel.dim("    #{icon} ") + @pastel.send(color_method, display_path) + duration_str + " #{status_str}"
    end

    def format_run_steps(steps, _shown = nil)
      steps.flat_map { |step| format_single_run_step(step) }
    end

    def format_single_run_step(step)
      output = []
      duration_str = format_duration(step[:duration])
      status_str = format_step_status(step)
      command_line = first_meaningful_command_line(step[:command].to_s)
      # Truncate long commands for cleaner output
      display_cmd = command_line.length > 60 ? "#{command_line[0..57]}..." : command_line
      output << (@pastel.dim('    • ') + @pastel.cyan(display_cmd) + duration_str + " #{status_str}")
      # Only show multiline details in debug mode
      if @debug
        output.concat(format_multiline_command(step[:command]))
        cmd_output = format_command_output(step[:output])
        output.concat(cmd_output) if cmd_output.any?
      end
      output
    end

    def format_error(error_message)
      @pastel.red("    ✗ ERROR: #{error_message}")
    end

    def format_summary_header
      "#{@pastel.bright_cyan("\n📊 Execution Summary")}\n#{@pastel.dim('─' * 60)}"
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
      when :sync
        ignore_str = command[:ignore]&.any? ? " (ignore: #{command[:ignore].join(', ')})" : ''
        delete_str = command[:delete] ? ' (delete: true)' : ''
        "#{@pastel.blue('>')} Sync: #{command[:source]} -> #{command[:destination]}#{ignore_str}#{delete_str}"
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

    def first_meaningful_command_line(command)
      lines = command.to_s.lines.map(&:strip)
      lines.each do |line|
        next if line.empty?
        next if line.start_with?('#')

        return line
      end
      lines.first.to_s
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

    def format_sync_step(step)
      duration_str = format_duration(step[:duration])
      status_str = format_step_status(step)
      sync_path = step[:command].sub('sync: ', '')
      # Truncate long paths for cleaner output
      display_path = sync_path.length > 50 ? "...#{sync_path[-47..]}" : sync_path

      result = step[:result] || {}
      uploaded = result[:uploaded] || 0
      deleted = result[:deleted] || 0
      total = result[:total] || 0

      stats = []
      stats << @pastel.green("#{uploaded} uploaded") if uploaded.positive?
      stats << @pastel.yellow("#{deleted} deleted") if deleted.positive?
      stats_str = stats.any? ? " (#{stats.join(', ')})" : " (#{total} files)"

      @pastel.dim('    📁 ') + @pastel.cyan(display_path) + @pastel.dim(stats_str) + duration_str + " #{status_str}"
    end

    def format_step_status(step)
      if step.is_a?(Hash) && step.key?(:error) && step[:error] && !step[:error].to_s.empty?
        @pastel.red('✗ failed')
      else
        @pastel.green('✓ ok')
      end
    end
  end
end
