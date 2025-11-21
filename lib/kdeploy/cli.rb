# frozen_string_literal: true

require 'thor'
require 'pastel'
require 'tty-table'
require 'tty-box'
require 'fileutils'

module Kdeploy
  # Command-line interface for Kdeploy
  class CLI < Thor
    extend DSL

    def self.exit_on_failure?
      true
    end

    map %w[--help -h] => :help
    map %w[--version -v] => :version

    desc 'version', 'Show version information'
    def version
      puts Kdeploy::Banner.show_version
    end

    desc 'help [COMMAND]', 'Show help information'
    def help(command = nil)
      if command
        super
      else
        show_general_help
      end
    end

    desc 'init [DIR]', 'Initialize a new deployment project'
    def init(dir = '.')
      initializer = Initializer.new(dir)
      initializer.run
    rescue StandardError => e
      puts Kdeploy::Banner.show_error(e.message)
      exit 1
    end

    desc 'execute TASK_FILE [TASK]', 'Execute deployment tasks from file'
    method_option :limit, type: :string, desc: 'Limit to specific hosts (comma-separated)'
    method_option :parallel, type: :numeric, default: 10, desc: 'Number of parallel executions'
    method_option :dry_run, type: :boolean, desc: 'Show what would be done'
    method_option :debug, type: :boolean, desc: 'Show detailed command output (stdout/stderr)'
    def execute(task_file, task_name = nil)
      load_config_file
      show_banner_once
      @task_file_dir = File.dirname(File.expand_path(task_file))
      load_task_file(task_file)

      tasks_to_run = determine_tasks(task_name)
      execute_tasks(tasks_to_run)
    rescue StandardError => e
      puts Kdeploy::Banner.show_error(e.message)
      exit 1
    end

    private

    def load_config_file
      Configuration.load_from_file
    end

    def load_task_file(file)
      validate_task_file(file)
      # 用 instance_eval 并传递顶层 binding，兼容 heredoc
      self.class.module_eval(File.read(file), file)
    rescue StandardError => e
      raise FileNotFoundError, file if e.message.include?('not found')

      raise
    end

    def validate_task_file(file)
      return if File.exist?(file)

      puts Kdeploy::Banner.show_error("Task file not found: #{file}")
      exit 1
    end

    def show_general_help
      formatter = HelpFormatter.new
      puts Kdeploy::Banner.show
      puts formatter.format_help
    end

    def filter_hosts(limit, task_hosts)
      hosts = self.class.kdeploy_hosts.slice(*task_hosts)
      return hosts unless limit

      host_names = limit.split(',').map(&:strip)
      hosts.slice(*host_names)
    end

    def print_dry_run(hosts, task_name)
      formatter = OutputFormatter.new
      # Banner already shown by show_banner_once, don't show again
      puts formatter.format_dry_run_header
      puts

      hosts.each do |name, config|
        print_dry_run_for_host(name, config, task_name, formatter)
      end
    end

    def print_dry_run_for_host(name, config, task_name, formatter)
      commands = self.class.kdeploy_tasks[task_name][:block].call
      output = commands.map { |cmd| formatter.format_command_for_dry_run(cmd) }.join("\n")
      title = "#{name} (#{config[:ip]})"
      puts formatter.format_dry_run_box(title, output)
      puts
    end

    def print_results(results, task_name, show_summary: false, debug: false)
      formatter = OutputFormatter.new(debug: debug)
      puts formatter.format_task_header(task_name)

      if results.empty?
        puts Kdeploy::Banner.show_error("No hosts executed for task: #{task_name}")
        puts 'This usually means no hosts matched the task configuration.'
        return
      end

      results.each do |host, result|
        puts formatter.format_host_status(host, result[:status])
        print_host_result(host, result, formatter)
      end

      # Only show summary if explicitly requested (for single task execution)
      print_summary(results, formatter) if show_summary
    end

    def print_host_result(_host, result, formatter)
      if %i[success changed].include?(result[:status])
        print_success_result(result, formatter)
      else
        print_failure_result(result, formatter)
      end
    end

    def print_success_result(result, formatter)
      shown = {}
      grouped = group_output_by_type(result[:output])

      grouped.each do |type, steps|
        output_lines = format_steps_by_type(type, steps, shown, formatter)
        output_lines.each { |line| puts line }
      end
    end

    def group_output_by_type(output)
      output.group_by { |step| step[:type] || :run }
    end

    def format_steps_by_type(type, steps, shown, formatter)
      case type
      when :upload
        formatter.format_upload_steps(steps, shown)
      when :upload_template
        formatter.format_template_steps(steps, shown)
      when :sync
        formatter.format_sync_steps(steps, shown)
      when :run
        formatter.format_run_steps(steps, shown)
      else
        []
      end
    end

    def print_failure_result(result, formatter)
      error_message = extract_error_message(result)
      puts formatter.format_error(error_message)
    end

    def print_summary(results, formatter)
      puts formatter.format_summary_header
      max_host_len = results.keys.map(&:length).max || 16

      results.keys.sort.each do |host|
        result = results[host]
        puts formatter.format_summary_line(host, result, max_host_len)
      end
    end

    def show_banner_once
      @banner_printed ||= false
      return if @banner_printed

      puts Kdeploy::Banner.show
      @banner_printed = true
    end

    def determine_tasks(task_name)
      task_name ? [task_name.to_sym] : self.class.kdeploy_tasks.keys
    end

    def execute_tasks(tasks_to_run)
      all_results = {}

      tasks_to_run.each do |task|
        task_results = execute_single_task(task)
        # Collect results for final summary
        all_results[task] = task_results if task_results
      end

      # Show combined summary at the end for all tasks
      print_all_tasks_summary(all_results) unless all_results.empty?
    end

    def execute_single_task(task)
      task_hosts = self.class.get_task_hosts(task)
      hosts = filter_hosts(options[:limit], task_hosts)

      if hosts.empty?
        puts Kdeploy::Banner.show_error("No hosts found for task: #{task}")
        return nil
      end

      if options[:dry_run]
        print_dry_run(hosts, task)
        return nil
      end

      run_task(hosts, task)
    end

    def run_task(hosts, task)
      output = ConsoleOutput.new
      parallel_count = options[:parallel] || Configuration.default_parallel
      debug_mode = options[:debug] || false
      base_dir = @task_file_dir
      runner = Runner.new(
        hosts, self.class.kdeploy_tasks,
        parallel: parallel_count,
        output: output,
        debug: debug_mode,
        base_dir: base_dir
      )
      results = runner.run(task)
      # Don't show summary here - it will be shown at the end for all tasks
      print_results(results, task, show_summary: false, debug: debug_mode)
      results
    end

    def print_all_tasks_summary(all_results)
      debug_mode = options[:debug] || false
      formatter = OutputFormatter.new(debug: debug_mode)
      puts formatter.format_summary_header

      # Collect all hosts from all tasks
      all_hosts = {}
      all_results.each do |task_name, task_results|
        task_results.each do |host, result|
          all_hosts[host] ||= { ok: 0, changed: 0, failed: 0, tasks: [] }
          counts = formatter.calculate_summary_counts(result)
          all_hosts[host][:ok] += counts[:ok]
          all_hosts[host][:changed] += counts[:changed]
          all_hosts[host][:failed] += counts[:failed]
          all_hosts[host][:tasks] << task_name
        end
      end

      max_host_len = all_hosts.keys.map(&:length).max || 16
      all_hosts.keys.sort.each do |host|
        counts = all_hosts[host]
        line = formatter.build_summary_line(host, counts, max_host_len)
        puts formatter.colorize_summary_line(line, counts)
      end
    end

    def extract_error_message(result)
      return result[:error] if result[:error]

      if result[:output].is_a?(Array)
        result[:output].map do |o|
          o[:output][:stderr] if o[:output].is_a?(Hash)
        end.compact.join("\n")
      else
        result[:output].to_s
      end
    end
  end
end
