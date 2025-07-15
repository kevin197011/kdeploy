# frozen_string_literal: true

require 'thor'
require 'pastel'
require 'tty-table'
require 'tty-box'
require 'fileutils'

module Kdeploy
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
        pastel = Pastel.new
        puts Kdeploy::Banner.show
        puts <<~HELP
          #{pastel.bright_white('📖 Available Commands:')}

          #{pastel.bright_yellow('🚀')} #{pastel.bright_white('execute TASK_FILE [TASK]')}     Execute deployment tasks from file
          #{pastel.dim('    --limit HOSTS')}              Limit to specific hosts (comma-separated)
          #{pastel.dim('    --parallel NUM')}             Number of parallel executions (default: 5)
          #{pastel.dim('    --dry-run')}                  Show what would be done without executing

          #{pastel.bright_yellow('🆕')} #{pastel.bright_white('init [DIR]')}                  Initialize new deployment project
          #{pastel.bright_yellow('ℹ️')} #{pastel.bright_white('version')}                    Show version information
          #{pastel.bright_yellow('❓')} #{pastel.bright_white('help [COMMAND]')}              Show help information

          #{pastel.bright_white('💡 Examples:')}

          #{pastel.dim('# Initialize a new project')}
          #{pastel.bright_cyan('kdeploy init my-deployment')}

          #{pastel.dim('# Deploy to web servers')}
          #{pastel.bright_cyan('kdeploy execute deploy.rb deploy_web')}

          #{pastel.dim('# Backup database')}
          #{pastel.bright_cyan('kdeploy execute deploy.rb backup_db')}

          #{pastel.dim('# Run maintenance on specific hosts')}
          #{pastel.bright_cyan('kdeploy execute deploy.rb maintenance --limit web01')}

          #{pastel.dim('# Preview deployment')}
          #{pastel.bright_cyan('kdeploy execute deploy.rb deploy_web --dry-run')}

          #{pastel.bright_white('📚 Documentation:')}
          #{pastel.bright_cyan('https://github.com/kevin197011/kdeploy')}

        HELP
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
    method_option :parallel, type: :numeric, default: 5, desc: 'Number of parallel executions'
    method_option :dry_run, type: :boolean, desc: 'Show what would be done'
    def execute(task_file, task_name = nil)
      # 只在最前面输出一次 banner
      @banner_printed ||= false
      unless @banner_printed
        puts Kdeploy::Banner.show
        @banner_printed = true
      end

      load_task_file(task_file)

      tasks_to_run = if task_name
                       [task_name.to_sym]
                     else
                       self.class.kdeploy_tasks.keys
                     end

      tasks_to_run.each do |task|
        task_hosts = self.class.get_task_hosts(task)
        hosts = filter_hosts(options[:limit], task_hosts)

        if hosts.empty?
          puts Kdeploy::Banner.show_error("No hosts found for task: #{task}")
          next
        end

        if options[:dry_run]
          print_dry_run(hosts, task)
          next
        end

        runner = Runner.new(hosts, self.class.kdeploy_tasks, parallel: options[:parallel])
        results = runner.run(task)
        print_results(results, task)
      end
    rescue StandardError => e
      puts Kdeploy::Banner.show_error(e.message)
      exit 1
    end

    private

    def load_task_file(file)
      unless File.exist?(file)
        puts Kdeploy::Banner.show_error("Task file not found: #{file}")
        exit 1
      end

      # 用 instance_eval 并传递顶层 binding，兼容 heredoc
      self.class.module_eval(File.read(file), file)
    end

    def filter_hosts(limit, task_hosts)
      hosts = self.class.kdeploy_hosts.slice(*task_hosts)
      return hosts unless limit

      host_names = limit.split(',').map(&:strip)
      hosts.slice(*host_names)
    end

    def print_dry_run(hosts, task_name)
      puts Kdeploy::Banner.show
      pastel = Pastel.new
      puts TTY::Box.frame(
        'Showing what would be done without executing any commands',
        title: { top_left: ' Dry Run Mode ', bottom_right: ' Kdeploy ' },
        style: {
          border: {
            fg: :blue
          }
        }
      )
      puts

      hosts.each do |name, config|
        commands = self.class.kdeploy_tasks[task_name][:block].call
        output = commands.map do |command|
          case command[:type]
          when :run
            "#{pastel.green('>')} #{command[:command]}"
          when :upload
            "#{pastel.blue('>')} Upload: #{command[:source]} -> #{command[:destination]}"
          end
        end.join("\n")

        puts TTY::Box.frame(
          output,
          title: { top_left: " #{name} (#{config[:ip]}) " },
          style: {
            border: {
              fg: :yellow
            }
          }
        )
        puts
      end
    end

    def print_results(results, task_name)
      pastel = Pastel.new
      puts pastel.cyan("\nPLAY [#{task_name}] " + ('*' * 64))

      results.each do |host, result|
        status = case result[:status]
                 when :success then pastel.green('ok')
                 when :changed then pastel.yellow('changed')
                 else pastel.red('failed')
                 end
        puts pastel.bright_white("\n#{host.ljust(24)} : #{status}")

        if %i[success changed].include?(result[:status])
          result[:output].each do |step|
            if step[:command].to_s.start_with?('upload:')
              puts pastel.green("  [upload] #{step[:command].sub('upload: ', '')}")
            elsif step[:command].to_s.start_with?('upload_template:')
              puts pastel.yellow("  [template] #{step[:command].sub('upload_template: ', '')}")
            else
              puts pastel.cyan("  [run]    #{step[:command].to_s.lines.first.strip}")
              if step[:output].is_a?(Hash) && step[:output][:stdout]
                step[:output][:stdout].each_line do |line|
                  puts "           > #{line.strip}" unless line.strip.empty?
                end
              elsif step[:output].is_a?(String)
                step[:output].each_line do |line|
                  puts "           > #{line.strip}" unless line.strip.empty?
                end
              end
            end
          end
        else
          # 失败主机高亮错误
          err = result[:error] || (if result[:output].is_a?(Array)
                                     result[:output].map do |o|
                                       o[:output][:stderr] if o[:output].is_a?(Hash)
                                     end.compact.join("\n")
                                   else
                                     result[:output].to_s
                                   end)
          puts pastel.red("  ERROR: #{err}")
        end
      end

      # summary
      puts pastel.cyan("\nPLAY RECAP #{'*' * 64}")
      max_host_len = results.keys.map(&:length).max || 16
      results.each do |host, result|
        ok = %i[success changed].include?(result[:status]) ? result[:output].size : 0
        failed = result[:status] == :failed ? 1 : 0
        changed = result[:status] == :changed ? result[:output].size : 0
        ok_str = pastel.green("ok=#{ok.to_s.ljust(3)}")
        changed_str = pastel.yellow("changed=#{changed.to_s.ljust(3)}")
        failed_str = pastel.red("failed=#{failed.to_s.ljust(3)}")
        line = "#{host.ljust(max_host_len)} : #{ok_str}  #{changed_str}  #{failed_str}"
        if failed.positive?
          puts pastel.red(line)
        elsif ok.positive? && failed.zero?
          puts pastel.green(line)
        else
          puts line
        end
      end
    end
  end
end
