# frozen_string_literal: true

require 'thor'
require 'tty-prompt'

# Add String truncate method if not available
class String
  def truncate(length)
    return self if size <= length

    "#{self[0, length - 3]}..."
  end
end

module Kdeploy
  class CLI < Thor
    # Fix Thor deprecation warning
    def self.exit_on_failure?
      true
    end
    desc 'execute SCRIPT', 'Execute deployment script'
    option :config, aliases: '-c', desc: 'Configuration file path'
    option :inventory, aliases: '-i', desc: 'Inventory file path'
    option :dry_run, aliases: '-d', type: :boolean, desc: 'Perform dry run without executing'
    option :verbose, aliases: '-v', type: :boolean, desc: 'Enable verbose output'
    option :log_file, aliases: '-l', desc: 'Log file path'
    def execute(script_file)
      setup_configuration
      setup_logging

      unless File.exist?(script_file)
        error "Script file not found: #{script_file}"
        exit 1
      end

      begin
        if options[:dry_run]
          perform_dry_run(script_file)
        else
          execute_script(script_file)
        end
      rescue Kdeploy::Error => e
        error "Deployment failed: #{e.message}"
        exit 1
      rescue StandardError => e
        error "Unexpected error: #{e.message}"
        KdeployLogger.debug("Backtrace: #{e.backtrace.join("\n")}")
        exit 1
      end
    end

    desc 'deploy SCRIPT', 'Execute deployment script (alias for execute)'
    option :config, aliases: '-c', desc: 'Configuration file path'
    option :inventory, aliases: '-i', desc: 'Inventory file path'
    option :dry_run, aliases: '-d', type: :boolean, desc: 'Perform dry run without executing'
    option :verbose, aliases: '-v', type: :boolean, desc: 'Enable verbose output'
    option :log_file, aliases: '-l', desc: 'Log file path'
    def deploy(script_file)
      execute(script_file)
    end

    desc 'init [PROJECT_NAME]', 'Initialize new deployment project'
    option :name, aliases: '-n', desc: 'Specify project name'
    def init(project_name = nil)
      show_kdeploy_banner
      project_name ||= options[:name] || File.basename(Dir.pwd)

      puts ''
      puts "🆕 Initializing kdeploy project: #{project_name}".colorize(:yellow)
      puts ''

      create_project_structure(project_name)
      create_sample_files(project_name)

      puts ''
      puts '✅ Project initialized successfully!'.colorize(:green)
      puts ''
      puts '📁 Project Structure Created:'.colorize(:cyan)
      puts "  #{project_name}/".colorize(:light_blue)
      puts '  ├── deploy.rb           # Main deployment script'.colorize(:light_blue)
      puts '  ├── config/             # Configuration files'.colorize(:light_blue)
      puts '  │   └── deploy.yml      # Deployment configuration'.colorize(:light_blue)
      puts '  ├── scripts/            # Additional scripts'.colorize(:light_blue)
      puts '  │   └── setup.rb        # Server setup script'.colorize(:light_blue)
      puts '  └── templates/          # Configuration templates'.colorize(:light_blue)
      puts '      ├── nginx.conf.erb  # Nginx configuration'.colorize(:light_blue)
      puts '      └── app.service.erb # Systemd service'.colorize(:light_blue)
      puts ''
      puts '🚀 Next Steps:'.colorize(:cyan)
      puts "  1. cd #{project_name}".colorize(:light_blue)
      puts '  2. Edit deploy.rb to configure your deployment'.colorize(:light_blue)
      puts '  3. Add your servers to config/deploy.yml'.colorize(:light_blue)
      puts '  4. Run: kdeploy deploy deploy.rb'.colorize(:light_blue)
      puts ''
      puts '💡 Need help? Run: kdeploy help deploy'.colorize(:yellow)
      puts ''
    end

    desc 'validate SCRIPT', 'Validate deployment script'
    option :config, aliases: '-c', desc: 'Configuration file path'
    option :inventory, aliases: '-i', desc: 'Inventory file path'
    def validate(script_file)
      show_kdeploy_banner
      setup_configuration

      puts ''
      puts "🔍 Validating deployment script: #{script_file}".colorize(:yellow)
      puts ''

      unless File.exist?(script_file)
        error "❌ Script file not found: #{script_file}"
        exit 1
      end

      begin
        pipeline = Kdeploy.load_script(script_file)
        validation_errors = pipeline.validate

        if validation_errors.empty?
          puts '✅ Script validation passed'.colorize(:green)
          puts ''
          puts '📋 Pipeline Summary:'.colorize(:cyan)
          puts "  Name: #{pipeline.name}".colorize(:light_blue)
          puts "  Hosts: #{pipeline.hosts.size}".colorize(:light_blue)
          puts "  Tasks: #{pipeline.tasks.size}".colorize(:light_blue)

          if pipeline.hosts.any?
            puts ''
            puts '🖥️  Target Hosts:'.colorize(:cyan)
            pipeline.hosts.each do |host|
              puts "  • #{host.hostname}:#{host.port} (#{host.user})".colorize(:light_blue)
            end
          end

          if pipeline.tasks.any?
            puts ''
            puts '🔧 Tasks to Execute:'.colorize(:cyan)
            pipeline.tasks.each_with_index do |task, index|
              puts "  #{index + 1}. #{task.name}".colorize(:light_blue)
            end
          end
          puts ''
        else
          puts '❌ Script validation failed:'.colorize(:red)
          puts ''
          validation_errors.each { |err| puts "  • #{err}".colorize(:red) }
          puts ''
          exit 1
        end
      rescue Kdeploy::Error => e
        puts "❌ Validation failed: #{e.message}".colorize(:red)
        puts ''
        exit 1
      end
    end

    desc 'config', 'Show configuration'
    option :config, aliases: '-c', desc: 'Configuration file path'
    option :inventory, aliases: '-i', desc: 'Inventory file path'
    option :verbose, aliases: '-v', type: :boolean, desc: 'Enable verbose output'
    option :log_file, aliases: '-l', desc: 'Log file path'
    def config
      show_kdeploy_banner
      setup_configuration

      config = Kdeploy.configuration

      puts ''
      puts '⚙️  Current Configuration'.colorize(:yellow)
      puts '=' * 50

      puts ''
      puts '🔧 Execution Settings'.colorize(:cyan)
      puts "  Max Concurrent Tasks: #{config.max_concurrent_tasks}".colorize(:light_blue)
      puts "  Retry Count: #{config.retry_count}".colorize(:light_blue)
      puts "  Retry Delay: #{config.retry_delay}s".colorize(:light_blue)

      puts ''
      puts '🌐 Network & SSH Settings'.colorize(:cyan)
      puts "  SSH Timeout: #{config.ssh_timeout}s".colorize(:light_blue)
      puts "  Command Timeout: #{config.command_timeout}s".colorize(:light_blue)
      puts "  Default User: #{config.default_user}".colorize(:light_blue)
      puts "  Default Port: #{config.default_port}".colorize(:light_blue)

      puts ''
      puts '📁 File & Directory Settings'.colorize(:cyan)
      puts "  Inventory File: #{config.inventory_file || 'not specified'}".colorize(:light_blue)
      puts "  Template Directory: #{config.template_dir}".colorize(:light_blue)

      puts ''
      puts '📋 Logging Settings'.colorize(:cyan)
      puts "  Log Level: #{config.log_level}".colorize(:light_blue)
      puts "  Log File: #{config.log_file || 'stdout'}".colorize(:light_blue)

      # Show SSH options if available
      if config.respond_to?(:ssh_options) && config.ssh_options && !config.ssh_options.empty?
        puts ''
        puts '🔐 SSH Options'.colorize(:cyan)
        config.ssh_options.each do |key, value|
          puts "  #{key.to_s.capitalize.gsub('_', ' ')}: #{value}".colorize(:light_blue)
        end
      end

      puts ''
      puts '💡 Use --config FILE to load custom configuration'.colorize(:yellow)
      puts ''
    end

    desc 'version', 'Show version'
    def version
      show_kdeploy_banner
      puts ''
      puts "🔖 Version: #{Kdeploy::VERSION}".colorize(:green)
      puts '📅 Released: 2025'.colorize(:light_blue)
      puts '🏠 Homepage: https://github.com/kdeploy/kdeploy'.colorize(:light_blue)
      puts '📚 Documentation: https://github.com/kdeploy/kdeploy/wiki'.colorize(:light_blue)
      puts ''
    end

    desc 'help [COMMAND]', 'Describe available commands or one specific command'
    def help(command = nil)
      show_kdeploy_banner
      puts ''
      puts '📖 Available Commands:'.colorize(:yellow)
      puts ''

      if command
        # Show specific command help
        super
      else
        # Show all commands with custom formatting
        puts "  🚀 #{'deploy SCRIPT'.ljust(25)} Execute deployment script"
        puts "  ⚡ #{'execute SCRIPT'.ljust(25)} Execute deployment script (alias for deploy)"
        puts "  🔍 #{'validate SCRIPT'.ljust(25)} Validate deployment script without execution"
        puts "  🆕 #{'init [PROJECT_NAME]'.ljust(25)} Initialize new deployment project"
        puts "  ⚙️  #{'config'.ljust(25)} Show current configuration"
        puts "  📊 #{'stats [COMMAND]'.ljust(25)} Show deployment statistics"
        puts "  🔖 #{'version'.ljust(25)} Show version information"
        puts "  ❓ #{'help [COMMAND]'.ljust(25)} Show this help or specific command help"
        puts ''
        puts '📈 Statistics Commands:'.colorize(:cyan)
        puts "  #{'stats summary'.ljust(20)} Overview of all statistics"
        puts "  #{'stats deployments'.ljust(20)} Deployment statistics"
        puts "  #{'stats tasks'.ljust(20)} Task execution statistics"
        puts "  #{'stats failures'.ljust(20)} Failed operations statistics"
        puts "  #{'stats trends'.ljust(20)} Performance trends"
        puts "  #{'stats global'.ljust(20)} Global statistics"
        puts "  #{'stats clear'.ljust(20)} Clear all statistics"
        puts "  #{'stats export'.ljust(20)} Export statistics to file"
        puts ''
        puts '🔧 Options:'.colorize(:magenta)
        puts '  --config, -c FILE    Specify configuration file'
        puts '  --inventory, -i FILE Specify inventory file'
        puts '  --verbose, -v        Enable verbose logging'
        puts '  --log-file FILE      Specify log file path'
        puts '  --dry-run            Perform dry run without execution'
        puts ''
        puts '📚 Examples:'.colorize(:green)
        puts '  kdeploy deploy app.rb'
        puts '  kdeploy validate deploy.rb --dry-run'
        puts '  kdeploy init my-project'
        puts '  kdeploy stats summary --days 7'
        puts '  kdeploy config'
        puts ''
        puts '💡 For more help: kdeploy help [COMMAND]'.colorize(:yellow)
        puts ''
      end
    end

    desc 'stats [COMMAND]', 'Show deployment statistics'
    option :days, aliases: '-d', type: :numeric, default: 30, desc: 'Number of days to include in statistics'
    option :format, aliases: '-f', default: 'table', desc: 'Output format (table, json, csv)'
    option :export, aliases: '-e', desc: 'Export statistics to file'
    def stats(command = 'summary')
      case command.downcase
      when 'summary', 'overview'
        show_summary_stats
      when 'deployments'
        show_deployment_stats
      when 'tasks'
        show_task_stats
      when 'failures', 'failed'
        show_failure_stats
      when 'trends'
        show_trend_stats
      when 'global'
        show_global_stats
      when 'clear'
        clear_statistics
      when 'export'
        export_statistics
      else
        error "Unknown stats command: #{command}"
        error 'Available commands: summary, deployments, tasks, failures, trends, global, clear, export'
        exit 1
      end
    end

    private

    def setup_configuration
      Kdeploy.configure do |config|
        config.load_from_file(options[:config]) if options[:config] && File.exist?(options[:config])

        config.inventory_file = options[:inventory] if options[:inventory]
        config.log_level = :debug if options[:verbose]
        config.log_file = options[:log_file] if options[:log_file]
      end
    end

    def setup_logging
      config = Kdeploy.configuration
      KdeployLogger.setup(
        level: config.log_level,
        file: config.log_file
      )
    end

    def perform_dry_run(script_file)
      info '🔍 Performing dry run...'

      pipeline = Kdeploy.load_script(script_file)
      runner = Runner.new(pipeline)

      result = runner.dry_run

      if result[:success]
        success '✅ Dry run completed successfully'
      else
        error '❌ Dry run failed'
        result[:validation_errors].each { |err| error "  - #{err}" }
        exit 1
      end
    end

    def execute_script(script_file)
      show_kdeploy_banner
      info '🚀 Starting deployment...'

      pipeline = Kdeploy.load_script(script_file)
      runner = Runner.new(pipeline)

      result = runner.execute

      if result[:success]
        success '✅ Deployment completed successfully'
      else
        error '❌ Deployment failed'
        error "Error: #{result[:error]}" if result[:error]
        exit 1
      end
    end

    def show_kdeploy_banner
      banner = <<~BANNER

                  _            _
          /\\ /\\__| | ___ _ __ | | ___  _   _
         / //_/ _` |/ _ \\ '_ \\| |/ _ \\| | | |
        / __ \\ (_| |  __/ |_) | | (_) | |_| |
        \\/  \\/\\__,_|\\___| .__/|_|\\___/ \\__, |
                        |_|            |___/

                ⚡ Lightweight Agentless Deployment Tool v#{Kdeploy::VERSION}
                🚀 Deploy with confidence, scale with ease

      BANNER

      puts banner.colorize(:cyan)
    end

    def create_project_structure(project_name)
      dirs = [
        project_name,
        "#{project_name}/config",
        "#{project_name}/scripts",
        "#{project_name}/templates"
      ]

      dirs.each do |dir|
        FileUtils.mkdir_p(dir)
        info "Created directory: #{dir}"
      end
    end

    def create_sample_files(project_name)
      # Create sample deployment script
      deploy_script = <<~RUBY
        # frozen_string_literal: true

        # Kdeploy deployment script for #{project_name}

        # Load hosts from inventory file
        inventory 'inventory.yml'

        # Deploy application to web servers
        task 'deploy', on: :webservers do
          run 'echo "Deploying application to {{hostname}}..."'
          run 'cd {{deploy_to}} && git pull origin main'
          run 'cd {{deploy_to}} && bundle install --deployment'
          run 'sudo systemctl restart {{application}}'
        end

        # Setup database
        task 'setup_db', on: :databases do
          run 'echo "Setting up database on {{hostname}}..."'
          run 'sudo systemctl restart postgresql'
        end

        # Health check on all web servers
        task 'health_check', on: :webservers do
          run 'curl -f http://localhost:{{app_port}}/health || exit 1',
              name: 'health_check',
              timeout: 30,
              retry_count: 3
        end

        # Backup database
        task 'backup_db', on: :databases do
          run 'pg_dump {{application}}_production > /tmp/{{application}}_backup_$(date +%Y%m%d).sql',
              name: 'backup_database',
              only: :database
        end
      RUBY

      File.write("#{project_name}/deploy.rb", deploy_script)
      info "Created sample script: #{project_name}/deploy.rb"

      # Create configuration file
      config_content = <<~YAML
        # Kdeploy configuration
        max_concurrent_tasks: 10
        ssh_timeout: 30
        command_timeout: 300
        retry_count: 3
        retry_delay: 1
        log_level: info
        default_user: deploy
        default_port: 22

        ssh_options:
          verify_host_key: never
          non_interactive: true
          use_agent: true
          forward_agent: false
      YAML

      File.write("#{project_name}/config/kdeploy.yml", config_content)
      info "Created configuration: #{project_name}/config/kdeploy.yml"

      # Create sample inventory file
      inventory_content = <<~YAML
        # Kdeploy inventory file
        # Global variables
        vars:
          application: #{project_name}
          deploy_to: /opt/#{project_name}
          environment: production

        # Host groups
        groups:
          webservers:
            hosts:
              - web1.example.com
              - web2.example.com
            vars:
              nginx_port: 80
              app_port: 3000

          databases:
            hosts:
              - db1.example.com
            vars:
              postgres_port: 5432
              backup_enabled: true

          production:
            children:
              - webservers
              - databases
            vars:
              environment: production

        # Individual hosts configuration
        hosts:
          web1.example.com:
            user: deploy
            port: 22
            roles:
              - web
              - app
            ssh:
              key_file: ~/.ssh/id_rsa
              verify_host_key: false
            vars:
              server_id: 1

          web2.example.com:
            user: deploy
            port: 22
            roles:
              - web
              - app
            ssh:
              key_file: ~/.ssh/id_rsa
              verify_host_key: false
            vars:
              server_id: 2

          db1.example.com:
            user: deploy
            port: 22
            roles:
              - database
            ssh:
              key_file: ~/.ssh/id_rsa
              verify_host_key: false
            vars:
              server_id: 3
              master: true
      YAML

      File.write("#{project_name}/inventory.yml", inventory_content)
      info "Created inventory: #{project_name}/inventory.yml"

      # Create sample template files
      create_sample_templates(project_name)
    end

    def info(message)
      puts message.colorize(:blue)
    end

    def success(message)
      puts message.colorize(:green)
    end

    def error(message)
      puts message.colorize(:red)
    end

    def show_summary_stats
      stats = Kdeploy.statistics
      deployment_summary = stats.deployment_summary(days: options[:days])
      task_summary = stats.task_summary(days: options[:days])
      global_summary = stats.global_summary

      case options[:format].downcase
      when 'json'
        puts JSON.pretty_generate({
                                    deployment_summary: deployment_summary,
                                    task_summary: task_summary,
                                    global_summary: global_summary
                                  })
      else
        print_summary_table(deployment_summary, task_summary, global_summary)
      end
    end

    def show_deployment_stats
      stats = Kdeploy.statistics
      summary = stats.deployment_summary(days: options[:days])

      case options[:format].downcase
      when 'json'
        puts JSON.pretty_generate(summary)
      else
        print_deployment_table(summary)
      end
    end

    def show_task_stats
      stats = Kdeploy.statistics
      summary = stats.task_summary(days: options[:days])

      case options[:format].downcase
      when 'json'
        puts JSON.pretty_generate(summary)
      else
        print_task_table(summary)
      end
    end

    def show_failure_stats
      stats = Kdeploy.statistics
      failed_tasks = stats.top_failed_tasks(limit: 10, days: options[:days])

      case options[:format].downcase
      when 'json'
        puts JSON.pretty_generate(failed_tasks)
      else
        print_failure_table(failed_tasks)
      end
    end

    def show_trend_stats
      stats = Kdeploy.statistics
      trends = stats.performance_trends(days: options[:days])

      case options[:format].downcase
      when 'json'
        puts JSON.pretty_generate(trends)
      else
        print_trend_table(trends)
      end
    end

    def show_global_stats
      stats = Kdeploy.statistics
      global_summary = stats.global_summary

      case options[:format].downcase
      when 'json'
        puts JSON.pretty_generate(global_summary)
      else
        print_global_table(global_summary)
      end
    end

    def clear_statistics
      prompt = TTY::Prompt.new
      if prompt.yes?('Are you sure you want to clear all statistics? This cannot be undone.')
        Kdeploy.statistics.clear_statistics!
        success 'Statistics cleared successfully'
      else
        info 'Statistics clearing cancelled'
      end
    end

    def export_statistics
      export_file = options[:export] || "kdeploy_stats_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"
      format = File.extname(export_file) == '.csv' ? :csv : :json

      Kdeploy.statistics.export_statistics(export_file, format: format)
      success "Statistics exported to #{export_file}"
    end

    def print_summary_table(deployment_summary, task_summary, global_summary)
      puts "\n📊 Kdeploy Statistics Summary (Last #{options[:days]} days)".colorize(:cyan)
      puts '=' * 60

      # Deployment Statistics
      puts "\n📦 Deployment Statistics".colorize(:yellow)
      if deployment_summary[:total_deployments] > 0
        puts "  Total Deployments: #{deployment_summary[:total_deployments]}"
        puts "  Successful: #{deployment_summary[:successful_deployments]} (#{deployment_summary[:success_rate]}%)"
        puts "  Failed: #{deployment_summary[:failed_deployments]}"
        puts "  Average Duration: #{deployment_summary[:avg_duration]}s"
        puts "  Total Duration: #{format_duration(deployment_summary[:total_duration])}"
      else
        puts "  No deployments in the last #{options[:days]} days"
      end

      # Task Statistics
      puts "\n🔧 Task Statistics".colorize(:yellow)
      if task_summary[:total_task_executions] > 0
        puts "  Total Task Executions: #{task_summary[:total_task_executions]}"
        puts "  Unique Tasks: #{task_summary[:unique_tasks]}"

        if task_summary[:tasks].any?
          puts '  Top Tasks:'
          task_summary[:tasks].first(5).each do |name, stats|
            puts "    #{name}: #{stats[:total_executions]} executions (#{stats[:success_rate]}% success)"
          end
        end
      else
        puts "  No task executions in the last #{options[:days]} days"
      end

      # Global Statistics
      puts "\n🌍 Global Statistics".colorize(:yellow)
      puts "  Total Deployments: #{global_summary[:total_deployments]}"
      puts "  Total Tasks: #{global_summary[:total_tasks]}"
      puts "  Total Commands: #{global_summary[:total_commands]}"
      puts "  Total Execution Time: #{format_duration(global_summary[:total_execution_time])}"
      puts "  Session Duration: #{format_duration(global_summary[:session_duration])}"
      puts ''
    end

    def print_deployment_table(summary)
      puts "\n📦 Deployment Statistics (Last #{options[:days]} days)".colorize(:cyan)
      puts '=' * 60

      return puts 'No deployments found' if summary[:total_deployments] == 0

      puts "Total Deployments: #{summary[:total_deployments]}"
      puts "Successful: #{summary[:successful_deployments]} (#{summary[:success_rate]}%)"
      puts "Failed: #{summary[:failed_deployments]}"
      puts "Average Duration: #{summary[:avg_duration]}s"
      puts "Min Duration: #{summary[:min_duration]}s"
      puts "Max Duration: #{summary[:max_duration]}s"
      puts "Total Duration: #{format_duration(summary[:total_duration])}"
      puts ''
    end

    def print_task_table(summary)
      puts "\n🔧 Task Statistics (Last #{options[:days]} days)".colorize(:cyan)
      puts '=' * 60

      return puts 'No task executions found' if summary[:total_task_executions] == 0

      puts "Total Executions: #{summary[:total_task_executions]}"
      puts "Unique Tasks: #{summary[:unique_tasks]}"
      puts ''

      if summary[:tasks].any?
        puts 'Task Details:'
        printf "%-30s %10s %10s %10s %12s %12s\n", 'Task Name', 'Executions', 'Success', 'Failed', 'Success Rate', 'Avg Duration'
        puts '-' * 95

        summary[:tasks].each do |name, stats|
          printf "%-30s %10d %10d %10d %11.1f%% %11.2fs\n",
                 name.truncate(28),
                 stats[:total_executions],
                 stats[:successful],
                 stats[:failed],
                 stats[:success_rate],
                 stats[:avg_duration]
        end
      end
      puts ''
    end

    def print_failure_table(failed_tasks)
      puts "\n❌ Top Failed Tasks (Last #{options[:days]} days)".colorize(:red)
      puts '=' * 60

      return puts 'No failed tasks found' if failed_tasks.empty?

      printf "%-30s %10s %20s\n", 'Task Name', 'Failures', 'Last Failure'
      puts '-' * 62

      failed_tasks.each do |task|
        last_failure_time = Time.at(task[:last_failure][:timestamp]).strftime('%Y-%m-%d %H:%M:%S')
        printf "%-30s %10d %20s\n",
               task[:task_name].truncate(28),
               task[:failure_count],
               last_failure_time
      end
      puts ''
    end

    def print_trend_table(trends)
      puts "\n📈 Performance Trends (Last #{options[:days]} days)".colorize(:cyan)
      puts '=' * 80

      return puts 'No trend data available' if trends[:trends].empty?

      printf "%-12s %10s %10s %10s %12s %12s\n", 'Date', 'Total', 'Success', 'Failed', 'Success Rate', 'Avg Duration'
      puts '-' * 78

      trends[:trends].each do |date, stats|
        printf "%-12s %10d %10d %10d %11.1f%% %11.2fs\n",
               date,
               stats[:total],
               stats[:successful],
               stats[:failed],
               stats[:success_rate],
               stats[:avg_duration]
      end
      puts ''
    end

    def print_global_table(global_summary)
      puts "\n🌍 Global Statistics".colorize(:cyan)
      puts '=' * 60

      puts 'Deployments:'
      puts "  Total: #{global_summary[:total_deployments]}"
      puts "  Successful: #{global_summary[:successful_deployments]}"
      puts "  Failed: #{global_summary[:failed_deployments]}"

      puts "\nTasks:"
      puts "  Total: #{global_summary[:total_tasks]}"
      puts "  Successful: #{global_summary[:successful_tasks]}"
      puts "  Failed: #{global_summary[:failed_tasks]}"

      puts "\nCommands:"
      puts "  Total: #{global_summary[:total_commands]}"
      puts "  Successful: #{global_summary[:successful_commands]}"
      puts "  Failed: #{global_summary[:failed_commands]}"

      puts "\nExecution Time:"
      puts "  Total: #{format_duration(global_summary[:total_execution_time])}"
      puts "  Session: #{format_duration(global_summary[:session_duration])}"
      puts "  Session Started: #{global_summary[:session_start_time].strftime('%Y-%m-%d %H:%M:%S')}"
      puts ''
    end

    def format_duration(seconds)
      return '0s' if seconds.nil? || seconds.zero?

      if seconds < 60
        "#{seconds.round(1)}s"
      elsif seconds < 3600
        minutes = (seconds / 60).to_i
        remaining_seconds = (seconds % 60).to_i
        "#{minutes}m #{remaining_seconds}s"
      else
        hours = (seconds / 3600).to_i
        remaining_minutes = ((seconds % 3600) / 60).to_i
        "#{hours}h #{remaining_minutes}m"
      end
    end

    def create_sample_templates(project_name)
      # Create nginx configuration template
      nginx_template = <<~ERB
        # Nginx configuration for <%= application %>
        server {
            listen <%= nginx_port || 80 %>;
            server_name <%= hostname %>;

            root <%= deploy_to %>/public;
            index index.html index.htm;

            location / {
                try_files $uri $uri/ @app;
            }

            location @app {
                proxy_pass http://127.0.0.1:<%= app_port || 3000 %>;
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
            }

            # Static files cache
            location ~* .(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
                expires 1y;
                add_header Cache-Control "public, immutable";
            }

            # Logs
            access_log /var/log/nginx/<%= application %>_access.log;
            error_log /var/log/nginx/<%= application %>_error.log;
        }
      ERB

      File.write("#{project_name}/templates/nginx.conf.erb", nginx_template)
      info "Created template: #{project_name}/templates/nginx.conf.erb"

      # Create systemd service template
      systemd_template = <<~ERB
        [Unit]
        Description=<%= application %> web application
        After=network.target

        [Service]
        Type=simple
        User=<%= user %>
        WorkingDirectory=<%= deploy_to %>
        ExecStart=/usr/bin/node server.js
        Restart=always
        RestartSec=10
        Environment=NODE_ENV=<%= environment || 'production' %>
        Environment=PORT=<%= app_port || 3000 %>

        # Security settings
        NoNewPrivileges=true
        PrivateTmp=true
        ProtectSystem=strict
        ProtectHome=true
        ReadWritePaths=<%= deploy_to %>/logs <%= deploy_to %>/tmp

        [Install]
        WantedBy=multi-user.target
      ERB

      File.write("#{project_name}/templates/app.service.erb", systemd_template)
      info "Created template: #{project_name}/templates/app.service.erb"

      # Create deployment script template
      deploy_script_template = <<~ERB
        #!/bin/bash
        # Deployment script for <%= application %>
        set -e

        echo "Deploying <%= application %> to <%= hostname %>..."

        # Variables
        APP_DIR="<%= deploy_to %>"
        APP_USER="<%= user %>"
        REPO_URL="<%= repo_url %>"
        BRANCH="<%= branch || 'main' %>"

        # Create application directory
        sudo mkdir -p $APP_DIR
        sudo chown $APP_USER:$APP_USER $APP_DIR

        # Deploy application
        cd $APP_DIR
        if [ -d .git ]; then
            echo "Updating existing repository..."
            git fetch origin
            git reset --hard origin/$BRANCH
        else
            echo "Cloning repository..."
            git clone $REPO_URL .
            git checkout $BRANCH
        fi

        # Install dependencies
        echo "Installing dependencies..."
        npm install --production

        # Build application
        echo "Building application..."
        npm run build || echo "No build script found"

        # Restart service
        echo "Restarting <%= application %> service..."
        sudo systemctl restart <%= application %>

        echo "Deployment completed successfully!"
      ERB

      File.write("#{project_name}/templates/deploy.sh.erb", deploy_script_template)
      info "Created template: #{project_name}/templates/deploy.sh.erb"

      # Create database backup script template
      backup_template = <<~ERB
        #!/bin/bash
        # Database backup script for <%= application %>
        set -e

        # Variables
        DB_NAME="<%= application %>_<%= environment || 'production' %>"
        BACKUP_DIR="/backup/<%= application %>"
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql"

        # Create backup directory
        sudo mkdir -p $BACKUP_DIR

        <% if postgres_port %>
        # PostgreSQL backup
        echo "Creating PostgreSQL backup..."
        pg_dump -h localhost -p <%= postgres_port %> -U postgres $DB_NAME > $BACKUP_FILE
        <% else %>
        # Default PostgreSQL backup
        echo "Creating PostgreSQL backup..."
        pg_dump $DB_NAME > $BACKUP_FILE
        <% end %>

        # Compress backup
        gzip $BACKUP_FILE

        # Clean up old backups (keep last 7 days)
        find $BACKUP_DIR -name "*.sql.gz" -mtime +7 -delete

        echo "Backup completed: ${BACKUP_FILE}.gz"
      ERB

      File.write("#{project_name}/templates/backup.sh.erb", backup_template)
      info "Created template: #{project_name}/templates/backup.sh.erb"
    end
  end
end
