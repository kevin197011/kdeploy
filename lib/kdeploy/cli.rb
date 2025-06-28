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
      puts '  ├── inventory.yml       # Server inventory'.colorize(:light_blue)
      puts '  ├── config/             # Configuration files'.colorize(:light_blue)
      puts '  │   └── kdeploy.yml     # Deployment configuration'.colorize(:light_blue)
      puts '  ├── scripts/            # Additional scripts'.colorize(:light_blue)
      puts '  │   ├── setup.rb        # Server setup script'.colorize(:light_blue)
      puts '  │   ├── database.rb     # Database management'.colorize(:light_blue)
      puts '  │   ├── backup.rb       # Backup operations'.colorize(:light_blue)
      puts '  │   ├── monitoring.rb   # Health checks & monitoring'.colorize(:light_blue)
      puts '  │   ├── rollback.rb     # Rollback operations'.colorize(:light_blue)
      puts '  │   └── cleanup.rb      # Cleanup operations'.colorize(:light_blue)
      puts '  └── templates/          # Configuration templates'.colorize(:light_blue)
      puts '      ├── nginx.conf.erb  # Nginx configuration'.colorize(:light_blue)
      puts '      ├── app.service.erb # Systemd service'.colorize(:light_blue)
      puts '      ├── deploy.sh.erb   # Deployment script'.colorize(:light_blue)
      puts '      └── backup.sh.erb   # Backup script'.colorize(:light_blue)
      puts ''
      puts '🚀 Next Steps:'.colorize(:cyan)
      puts "  1. cd #{project_name}".colorize(:light_blue)
      puts '  2. Edit deploy.rb to configure your deployment'.colorize(:light_blue)
      puts '  3. Update inventory.yml with your servers'.colorize(:light_blue)
      puts '  4. Run: kdeploy deploy scripts/setup.rb        # Setup servers'.colorize(:light_blue)
      puts '  5. Run: kdeploy deploy deploy.rb               # Deploy application'.colorize(:light_blue)
      puts ''
      puts '💡 Available Scripts:'.colorize(:cyan)
      puts '  kdeploy deploy scripts/setup.rb      # Initial server setup'.colorize(:light_blue)
      puts '  kdeploy deploy scripts/database.rb   # Database operations'.colorize(:light_blue)
      puts '  kdeploy deploy scripts/backup.rb     # Backup operations'.colorize(:light_blue)
      puts '  kdeploy deploy scripts/monitoring.rb # Health checks'.colorize(:light_blue)
      puts '  kdeploy deploy scripts/rollback.rb   # Rollback operations'.colorize(:light_blue)
      puts '  kdeploy deploy scripts/cleanup.rb    # Cleanup operations'.colorize(:light_blue)
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
      puts '🏠 Homepage: https://github.com/kevin197011/kdeploy'.colorize(:light_blue)
      puts '📚 Documentation: https://github.com/kevin197011/kdeploy/wiki'.colorize(:light_blue)
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
        #
        # This script demonstrates how to use kdeploy for full deployment lifecycle
        # including references to scripts in the scripts/ directory

        # ===================================================================
        # CONFIGURATION
        # ===================================================================

        # Load hosts from inventory file
        inventory 'inventory.yml'

        # Optional: Set global variables (can also be set in inventory.yml)
        set 'application', '#{project_name}'
        set 'deploy_to', '/opt/#{project_name}'
        set 'branch', 'main'

        # ===================================================================
        # MODULAR SCRIPTS (for complex projects)
        # ===================================================================

        # Include common tasks from external files (optional)
        # This allows you to organize your deployment scripts modularly
        include 'scripts/common_tasks.rb' if File.exist?('scripts/common_tasks.rb')
        include 'scripts/#{project_name}_tasks.rb' if File.exist?('scripts/#{project_name}_tasks.rb')

        # You can also include environment-specific tasks
        # include 'scripts/production_tasks.rb' if File.exist?('scripts/production_tasks.rb')
        # include 'scripts/staging_tasks.rb' if File.exist?('scripts/staging_tasks.rb')

        # ===================================================================
        # DEPLOYMENT WORKFLOW
        # ===================================================================

        # Option 1: Complete deployment workflow using individual scripts
        # Uncomment these to use the predefined scripts from scripts/ directory:

        # Pre-deployment tasks (local)
        local 'echo "🚀 Starting #{project_name} deployment..."'
        local 'echo "Current user: $(whoami)"'
        local 'echo "Current time: $(date)"'

        # Step 1: Server setup (run once for new servers)
        # Run with: kdeploy deploy scripts/setup.rb
        # task 'run_setup' do
        #   # This would execute the setup script
        #   local 'kdeploy deploy scripts/setup.rb'
        # end

        # Step 2: Database operations
        # Run with: kdeploy deploy scripts/database.rb
        # task 'run_database_tasks' do
        #   local 'kdeploy deploy scripts/database.rb'
        # end

        # ===================================================================
        # MAIN DEPLOYMENT TASKS
        # ===================================================================

        # Main application deployment
        task 'deploy', on: :webservers do
          run 'echo "Deploying #{project_name} to {{hostname}}..."'

          # Create deployment directory
          run 'sudo mkdir -p {{deploy_to}}'
          run 'sudo chown {{user}}:{{user}} {{deploy_to}}'

          # Deploy using heredoc for complex operations
          run <<~DEPLOYMENT
            echo "Starting deployment on {{hostname}}"
            cd {{deploy_to}}

            # Backup current version if exists
            if [ -d ".git" ]; then
              echo "Creating backup..."
              git stash push -m "backup_$(date +%Y%m%d_%H%M%S)"
            fi

            # Get latest code
            if [ -d ".git" ]; then
              echo "Updating existing repository..."
              git fetch origin
              git reset --hard origin/{{branch}}
            else
              echo "Cloning repository..."
              git clone https://github.com/example/#{project_name}.git .
              git checkout {{branch}}
            fi

            # Install dependencies (adjust for your stack)
            echo "Installing dependencies..."
            # For Node.js: npm install --production
            # For Ruby: bundle install --deployment
            # For Python: pip install -r requirements.txt

            # Build application if needed
            # npm run build
            # bundle exec rake assets:precompile

            echo "✅ Deployment completed on {{hostname}}"
          DEPLOYMENT

          # Configure and restart services
          run 'sudo systemctl restart {{application}}', ignore_errors: true
        end

        # Database setup (if needed)
        task 'setup_database', on: :databases do
          run 'echo "Setting up database on {{hostname}}..."'

          # Create database and user (PostgreSQL example)
          run 'sudo -u postgres createdb {{application}}_{{environment}}', ignore_errors: true
          run 'sudo -u postgres createuser {{application}}_user', ignore_errors: true

          # Run migrations
          run 'cd {{deploy_to}} && npm run migrate', ignore_errors: true

          run 'echo "✅ Database setup completed on {{hostname}}"'
        end

        # Health check
        task 'health_check', on: :webservers do
          run 'echo "Running health checks on {{hostname}}..."'

          # Check if service is running
          run 'systemctl is-active {{application}} || echo "Service not running"', ignore_errors: true

          # HTTP health check
          run 'curl -f http://localhost:{{app_port}}/health || curl -f http://localhost:{{app_port}}/ || echo "HTTP check failed"',
              name: 'http_health_check',
              timeout: 30,
              retry_count: 3,
              ignore_errors: true

          run 'echo "✅ Health check completed on {{hostname}}"'
        end

        # Backup before deployment (recommended for production)
        task 'backup', on: :databases do
          run 'echo "Creating backup on {{hostname}}..."'
          run 'mkdir -p /backup/{{application}}'
          run 'pg_dump {{application}}_{{environment}} > /backup/{{application}}/backup_$(date +%Y%m%d_%H%M%S).sql',
              name: 'database_backup',
              ignore_errors: true
          run 'echo "✅ Backup completed on {{hostname}}"'
        end

        # ===================================================================
        # ADVANCED WORKFLOWS
        # ===================================================================

        # Complete deployment workflow
        task 'full_deploy' do
          run 'echo "🚀 Starting full deployment workflow..."'

          # This demonstrates how you might chain operations
          # In practice, you'd run these as separate kdeploy commands
          local 'echo "Step 1: Pre-deployment checks"'
          local 'echo "Step 2: Backup (use: kdeploy deploy scripts/backup.rb)"'
          local 'echo "Step 3: Deploy application (this script)"'
          local 'echo "Step 4: Health monitoring (use: kdeploy deploy scripts/monitoring.rb)"'

          run 'echo "✅ Full deployment workflow guide completed"'
        end

        # Example of using common tasks (from common_tasks.rb)
        # Uncomment these to use tasks from the included common_tasks.rb file:

        # task 'full_setup_with_common_tasks' do
        #   run_task 'pre_deploy_checks'       # From common_tasks.rb
        #   run_task 'setup_environment'       # From common_tasks.rb
        #   run_task 'security_hardening'      # From common_tasks.rb
        #   run_task 'performance_tuning'      # From common_tasks.rb
        #   run_task 'deploy'                  # From this file
        #   run_task 'verify_deployment'       # From common_tasks.rb
        # end

        # task 'emergency_procedures_demo' do
        #   # These tasks are available from common_tasks.rb:
        #   # run_task 'emergency_stop'         # Stop all services
        #   # run_task 'emergency_start'        # Start all services
        #   # run_task 'health_check_all'       # Comprehensive health check
        # end

        # Rollback task (for emergencies)
        task 'rollback', on: :webservers do
          run 'echo "🔄 Rolling back on {{hostname}}..."'

          run <<~ROLLBACK
            cd {{deploy_to}}
            echo "Current commit: $(git rev-parse HEAD)"
            echo "Rolling back to previous commit..."
            git reset --hard HEAD~1

            # Restart services
            sudo systemctl restart {{application}}

            echo "✅ Rollback completed on {{hostname}}"
          ROLLBACK
        end

        # Maintenance mode
        task 'maintenance_on', on: :webservers do
          run 'echo "Enabling maintenance mode on {{hostname}}..."'
          run 'echo "maintenance" > {{deploy_to}}/public/maintenance.txt', ignore_errors: true
          run 'sudo nginx -s reload', ignore_errors: true
        end

        task 'maintenance_off', on: :webservers do
          run 'echo "Disabling maintenance mode on {{hostname}}..."'
          run 'rm -f {{deploy_to}}/public/maintenance.txt', ignore_errors: true
          run 'sudo nginx -s reload', ignore_errors: true
        end

        # ===================================================================
        # POST-DEPLOYMENT
        # ===================================================================

        # Final success message
        local 'echo "🎉 #{project_name} deployment script completed!"'
        local 'echo ""'
        local 'echo "💡 Next steps:"'
        local 'echo "   1. Run health checks: kdeploy deploy scripts/monitoring.rb"'
        local 'echo "   2. Monitor logs and performance"'
        local 'echo "   3. Create backups: kdeploy deploy scripts/backup.rb"'
        local 'echo ""'
        local 'echo "🔧 Modular script usage examples:"'
        local 'echo "   - Individual tasks: kdeploy deploy scripts/common_tasks.rb --task setup_environment"'
        local 'echo "   - Security hardening: kdeploy deploy scripts/common_tasks.rb --task security_hardening"'
        local 'echo "   - Emergency procedures: kdeploy deploy scripts/common_tasks.rb --task emergency_stop"'
        local 'echo ""'
        local 'echo "📊 View deployment statistics: kdeploy stats summary"'

        # ===================================================================
        # USAGE EXAMPLES:
        # ===================================================================
        #
        # Complete deployment workflow:
        # 1. kdeploy deploy scripts/setup.rb      # One-time server setup
        # 2. kdeploy deploy scripts/database.rb   # Database operations
        # 3. kdeploy deploy deploy.rb             # Main deployment (this file)
        # 4. kdeploy deploy scripts/monitoring.rb # Health checks
        # 5. kdeploy deploy scripts/backup.rb     # Create backups
        #
        # Individual tasks:
        # kdeploy deploy deploy.rb --task deploy         # Deploy only
        # kdeploy deploy deploy.rb --task health_check   # Health check only
        # kdeploy deploy deploy.rb --task rollback       # Emergency rollback
        #
        # Maintenance:
        # kdeploy deploy deploy.rb --task maintenance_on  # Enable maintenance
        # kdeploy deploy deploy.rb --task maintenance_off # Disable maintenance
        #
        # For more examples, see scripts/ directory files.
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

      # Create sample scripts
      create_sample_scripts(project_name)

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
      show_kdeploy_banner
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
      show_kdeploy_banner
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
      show_kdeploy_banner
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
      show_kdeploy_banner
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
      show_kdeploy_banner
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
      show_kdeploy_banner
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
      show_kdeploy_banner
      prompt = TTY::Prompt.new
      if prompt.yes?('Are you sure you want to clear all statistics? This cannot be undone.')
        Kdeploy.statistics.clear_statistics!
        success 'Statistics cleared successfully'
      else
        info 'Statistics clearing cancelled'
      end
    end

    def export_statistics
      show_kdeploy_banner
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
      if deployment_summary[:total_deployments].positive?
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
      if task_summary[:total_task_executions].positive?
        puts "  Total Task Executions: #{task_summary[:total_task_executions]}"
        puts "  Unique Tasks: #{task_summary[:unique_tasks]}"

        if task_summary[:tasks].any?
          puts '  Top Tasks:'
          # Sort tasks by total executions (descending) and take top 5
          sorted_tasks = task_summary[:tasks].sort_by { |_name, stats| -stats[:total_executions] }.first(5)
          sorted_tasks.each do |name, stats|
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

      return puts 'No deployments found' if summary[:total_deployments].zero?

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

      return puts 'No task executions found' if summary[:total_task_executions].zero?

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

    def create_sample_scripts(project_name)
      # Create server setup script
      setup_script = <<~RUBY
        # frozen_string_literal: true

        # Server setup script for #{project_name}
        # Run this script to prepare servers for deployment

        # Load inventory
        inventory 'inventory.yml'

        # Install system dependencies
        task 'install_dependencies', on: :all do
          run 'sudo apt-get update'
          run 'sudo apt-get install -y curl git build-essential'
          run 'sudo apt-get install -y nginx postgresql redis-server'
        end

        # Setup application user
        task 'setup_user', on: :all do
          run 'sudo useradd -m -s /bin/bash {{user}}',
              name: 'create_user',
              ignore_errors: true
          run 'sudo mkdir -p /home/{{user}}/.ssh'
          run 'sudo cp ~/.ssh/authorized_keys /home/{{user}}/.ssh/'
          run 'sudo chown -R {{user}}:{{user}} /home/{{user}}/.ssh'
          run 'sudo chmod 700 /home/{{user}}/.ssh'
          run 'sudo chmod 600 /home/{{user}}/.ssh/authorized_keys'
        end

        # Setup application directory
        task 'setup_app_directory', on: :webservers do
          run 'sudo mkdir -p {{deploy_to}}'
          run 'sudo chown {{user}}:{{user}} {{deploy_to}}'
          run 'sudo mkdir -p {{deploy_to}}/shared/logs'
          run 'sudo mkdir -p {{deploy_to}}/shared/tmp'
        end

        # Configure firewall
        task 'setup_firewall', on: :all do
          run 'sudo ufw allow ssh'
          run 'sudo ufw allow {{nginx_port || 80}}'
          run 'sudo ufw --force enable', name: 'enable_firewall'
        end

        # Install Node.js (example for Node.js applications)
        task 'install_nodejs', on: :webservers do
          run 'curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -'
          run 'sudo apt-get install -y nodejs'
          run 'node --version && npm --version'
        end
      RUBY

      File.write("#{project_name}/scripts/setup.rb", setup_script)
      info "Created script: #{project_name}/scripts/setup.rb"

      # Create database management script
      database_script = <<~RUBY
        # frozen_string_literal: true

        # Database management script for #{project_name}

        inventory 'inventory.yml'

        # Create database and user
        task 'create_database', on: :databases do
          run 'sudo -u postgres createdb {{application}}_{{environment}}',
              name: 'create_db',
              ignore_errors: true
          run 'sudo -u postgres createuser {{application}}_user',
              name: 'create_user',
              ignore_errors: true
          run %(sudo -u postgres psql -c "ALTER USER {{application}}_user WITH PASSWORD 'secure_password';")
          run %(sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE {{application}}_{{environment}} TO {{application}}_user;")
        end

        # Run database migrations
        task 'migrate', on: :databases do
          run 'cd {{deploy_to}} && npm run migrate'
        end

        # Database backup
        task 'backup', on: :databases do
          run 'mkdir -p /backup/{{application}}'
          run 'pg_dump {{application}}_{{environment}} > /backup/{{application}}/backup_$(date +%Y%m%d_%H%M%S).sql'
          run 'gzip /backup/{{application}}/backup_*.sql'
        end

        # Database restore (use with caution!)
        task 'restore', on: :databases do |hosts, backup_file|
          backup_file ||= ENV['BACKUP_FILE']
          raise 'Please specify BACKUP_FILE environment variable' unless backup_file

          run "gunzip -c \#{backup_file} | psql {{application}}_{{environment}}"
        end

        # Database maintenance
        task 'maintenance', on: :databases do
          run %(sudo -u postgres psql {{application}}_{{environment}} -c "VACUUM ANALYZE;")
          run %(sudo -u postgres psql {{application}}_{{environment}} -c "REINDEX DATABASE {{application}}_{{environment}};")
        end
      RUBY

      File.write("#{project_name}/scripts/database.rb", database_script)
      info "Created script: #{project_name}/scripts/database.rb"

      # Create backup script
      backup_script = <<~RUBY
        # frozen_string_literal: true

        # Backup script for #{project_name}

        inventory 'inventory.yml'

        # Full application backup
        task 'backup_application', on: :all do
          run 'mkdir -p /backup/{{application}}/{{hostname}}'

          # Backup application files
          run 'tar -czf /backup/{{application}}/{{hostname}}/app_$(date +%Y%m%d_%H%M%S).tar.gz -C {{deploy_to}} .',
              name: 'backup_app_files'

          # Backup configuration files
          run 'sudo tar -czf /backup/{{application}}/{{hostname}}/config_$(date +%Y%m%d_%H%M%S).tar.gz /etc/nginx /etc/systemd/system/{{application}}.service',
              name: 'backup_config',
              ignore_errors: true
        end

        # Database backup
        task 'backup_database', on: :databases do
          run 'mkdir -p /backup/{{application}}/database'
          run 'pg_dump {{application}}_{{environment}} | gzip > /backup/{{application}}/database/{{application}}_$(date +%Y%m%d_%H%M%S).sql.gz'
        end

        # Cleanup old backups
        task 'cleanup_backups', on: :all do
          run 'find /backup/{{application}} -name "*.tar.gz" -mtime +30 -delete'
          run 'find /backup/{{application}} -name "*.sql.gz" -mtime +30 -delete'
        end

        # Download backups to local machine
        task 'download_backups', on: :all do
          run 'ls -la /backup/{{application}}/{{hostname}}/'
        end
      RUBY

      File.write("#{project_name}/scripts/backup.rb", backup_script)
      info "Created script: #{project_name}/scripts/backup.rb"

      # Create monitoring script
      monitoring_script = <<~RUBY
        # frozen_string_literal: true

        # Monitoring and health check script for #{project_name}

        inventory 'inventory.yml'

        # System health check
        task 'system_health', on: :all do
          run 'echo "=== System Health for {{hostname}} ==="'
          run 'uptime'
          run 'df -h'
          run 'free -h'
          run 'ps aux --sort=-%cpu | head -10'
        end

        # Application health check
        task 'app_health', on: :webservers do
          run 'systemctl status {{application}}', ignore_errors: true
          run 'curl -f http://localhost:{{app_port}}/health || echo "Health check endpoint not responding"',
              timeout: 10,
              ignore_errors: true
        end

        # Service status check
        task 'service_status', on: :all do
          run 'systemctl status nginx', ignore_errors: true
          run 'systemctl status postgresql', ignore_errors: true, only: :databases
          run 'systemctl status redis', ignore_errors: true
        end

        # Log analysis
        task 'check_logs', on: :webservers do
          run 'echo "=== Recent Application Logs ==="'
          run 'tail -n 20 {{deploy_to}}/shared/logs/application.log', ignore_errors: true
          run 'echo "=== Recent Nginx Error Logs ==="'
          run 'sudo tail -n 20 /var/log/nginx/{{application}}_error.log', ignore_errors: true
        end

        # Performance monitoring
        task 'performance_check', on: :webservers do
          run 'echo "=== Performance Metrics ==="'
          run 'curl -w "Connect: %<time_connect>ss, Total: %<time_total>ss, Size: %<size_download>s bytes\\n" -s -o /dev/null http://localhost:{{app_port}}/',
              timeout: 15,
              ignore_errors: true
        end

        # Security check
        task 'security_check', on: :all do
          run 'echo "=== Security Status ==="'
          run 'sudo ufw status'
          run 'last -n 10'
          run 'sudo fail2ban-client status', ignore_errors: true
        end
      RUBY

      File.write("#{project_name}/scripts/monitoring.rb", monitoring_script)
      info "Created script: #{project_name}/scripts/monitoring.rb"

      # Create rollback script
      rollback_script = <<~RUBY
        # frozen_string_literal: true

        # Rollback script for #{project_name}

        inventory 'inventory.yml'

        # Quick rollback to previous version
        task 'rollback', on: :webservers do
          run 'cd {{deploy_to}} && git log --oneline -5'
          run 'cd {{deploy_to}} && git reset --hard HEAD~1',
              name: 'rollback_code'
          run 'cd {{deploy_to}} && npm install --production',
              ignore_errors: true
          run 'sudo systemctl restart {{application}}'
        end

        # Rollback to specific commit
        task 'rollback_to_commit', on: :webservers do |hosts, commit_hash|
          commit_hash ||= ENV['COMMIT_HASH']
          raise 'Please specify COMMIT_HASH environment variable' unless commit_hash

          run "cd {{deploy_to}} && git reset --hard \#{commit_hash}"
          run 'cd {{deploy_to}} && npm install --production'
          run 'sudo systemctl restart {{application}}'
        end

        # Emergency stop
        task 'emergency_stop', on: :webservers do
          run 'sudo systemctl stop {{application}}'
          run 'sudo systemctl disable {{application}}'
        end

        # Emergency start
        task 'emergency_start', on: :webservers do
          run 'sudo systemctl enable {{application}}'
          run 'sudo systemctl start {{application}}'
          run 'sleep 5 && systemctl status {{application}}'
        end

        # Maintenance mode
        task 'maintenance_on', on: :webservers do
          run 'echo "maintenance" > {{deploy_to}}/public/maintenance.txt'
          run 'sudo nginx -s reload'
        end

        task 'maintenance_off', on: :webservers do
          run 'rm -f {{deploy_to}}/public/maintenance.txt'
          run 'sudo nginx -s reload'
        end
      RUBY

      File.write("#{project_name}/scripts/rollback.rb", rollback_script)
      info "Created script: #{project_name}/scripts/rollback.rb"

      # Create cleanup script
      cleanup_script = <<~RUBY
        # frozen_string_literal: true

        # Cleanup script for #{project_name}

        inventory 'inventory.yml'

        # Clean application logs
        task 'clean_logs', on: :all do
          run 'sudo find /var/log -name "*.log" -mtime +30 -delete', ignore_errors: true
          run 'find {{deploy_to}}/shared/logs -name "*.log" -mtime +7 -delete', ignore_errors: true
          run 'sudo systemctl reload rsyslog', ignore_errors: true
        end

        # Clean temporary files
        task 'clean_temp', on: :all do
          run 'find /tmp -type f -mtime +7 -delete', ignore_errors: true
          run 'find {{deploy_to}}/shared/tmp -type f -mtime +1 -delete', ignore_errors: true
        end

        # Clean package cache
        task 'clean_cache', on: :all do
          run 'sudo apt-get autoremove -y'
          run 'sudo apt-get autoclean'
          run 'npm cache clean --force', ignore_errors: true
        end

        # Restart services
        task 'restart_services', on: :all do
          run 'sudo systemctl restart nginx'
          run 'sudo systemctl restart {{application}}', only: :webservers
          run 'sudo systemctl restart postgresql', only: :databases
        end

        # Full cleanup (use with caution)
        task 'deep_clean', on: :all do
          run 'docker system prune -af', ignore_errors: true
          run 'sudo journalctl --vacuum-time=7d'
          run 'sudo find /var/cache -type f -delete', ignore_errors: true
        end
      RUBY

      File.write("#{project_name}/scripts/cleanup.rb", cleanup_script)
      info "Created script: #{project_name}/scripts/cleanup.rb"

      # Create common tasks script (modular example)
      common_tasks_script = <<~RUBY
        # frozen_string_literal: true

        # Common tasks for #{project_name}
        # This file demonstrates modular script organization
        #
        # To use this file, include it in your main deployment script:
        # include 'scripts/common_tasks.rb' if File.exist?('scripts/common_tasks.rb')

        # ===================================================================
        # HOST DEFINITIONS (Required for remote tasks)
        # ===================================================================

                # Define default hosts - update these with your actual hosts
        host 'localhost', user: ENV.fetch('USER', 'deploy'), port: 22, roles: [:web, :app, :db, :all, :webservers, :databases]

        # Uncomment and update these for real deployments:
        # host 'web1.example.com', user: 'deploy', port: 22, roles: [:web, :app, :webservers]
        # host 'web2.example.com', user: 'deploy', port: 22, roles: [:web, :app, :webservers]
        # host 'db1.example.com', user: 'deploy', port: 22, roles: [:db, :databases]

        # ===================================================================
        # COMMON UTILITY TASKS
        # ===================================================================

        # Shared pre-deployment checks (LOCAL + REMOTE)
        task 'pre_deploy_checks', on: :all do
          local 'echo "🔍 Running pre-deployment checks..."'
          local 'echo "Current user: $(whoami)"'
          local 'echo "Current directory: $(pwd)"'
          local 'echo "Git status:" && git status --porcelain || echo "Not a git repository"'
          local 'echo "✅ Pre-deployment checks completed"'

          # Add a dummy remote command to satisfy validation
          run 'echo "Pre-deployment check completed on {{hostname}}"'
        end

        # Common environment setup
        task 'setup_environment', on: :all do
          run 'echo "Setting up environment on {{hostname}}..."'

          # Set timezone
          run 'sudo timedatectl set-timezone UTC', ignore_errors: true

          # Update system packages
          run 'sudo apt-get update -qq', ignore_errors: true

          # Install common utilities
          run 'sudo apt-get install -y -qq htop curl wget vim git unzip', ignore_errors: true

          run 'echo "✅ Environment setup completed on {{hostname}}"'
        end

        # Common SSL certificate setup
        task 'setup_ssl', on: :webservers do
          run 'echo "Setting up SSL certificates on {{hostname}}..."'

          # Install certbot
          run 'sudo apt-get install -y certbot python3-certbot-nginx', ignore_errors: true

          # Generate certificate (this is a dry run example)
          run 'sudo certbot --nginx --dry-run -d {{hostname}} || echo "SSL setup skipped (dry run)"',
              ignore_errors: true

          run 'echo "✅ SSL setup completed on {{hostname}}"'
        end

        # Common log rotation setup
        task 'setup_log_rotation', on: :all do
          run 'echo "Setting up log rotation on {{hostname}}..."'

          # Application log rotation
          run <<~LOGROTATE
            sudo tee /etc/logrotate.d/{{application}} > /dev/null << 'EOF'
            {{deploy_to}}/shared/logs/*.log {
                daily
                missingok
                rotate 52
                compress
                delaycompress
                notifempty
                create 644 {{user}} {{user}}
                postrotate
                    sudo systemctl reload {{application}} || true
                endscript
            }
            EOF
          LOGROTATE

          run 'echo "✅ Log rotation setup completed on {{hostname}}"'
        end

        # Common system monitoring setup
        task 'setup_monitoring', on: :all do
          run 'echo "Setting up basic monitoring on {{hostname}}..."'

          # Install system monitoring tools
          run 'sudo apt-get install -y htop iotop iftop nethogs', ignore_errors: true

          # Setup basic disk space monitoring
          run <<~MONITORING
            sudo tee /usr/local/bin/disk-alert.sh > /dev/null << 'EOF'
            #!/bin/bash
            THRESHOLD=90
            USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
            if [ $USAGE -gt $THRESHOLD ]; then
                echo "Warning: Disk usage is $USAGE% on $(hostname)"
                logger "Disk usage alert: $USAGE% on $(hostname)"
            fi
            EOF
          MONITORING

          run 'sudo chmod +x /usr/local/bin/disk-alert.sh'

          # Add to crontab
          run 'echo "0 */6 * * * /usr/local/bin/disk-alert.sh" | sudo crontab -', ignore_errors: true

          run 'echo "✅ Monitoring setup completed on {{hostname}}"'
        end

        # Common security hardening
        task 'security_hardening', on: :all do
          run 'echo "Applying security hardening on {{hostname}}..."'

          # Disable root login
          run 'sudo sed -i "s/PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config', ignore_errors: true

          # Configure firewall basics
          run 'sudo ufw --force reset', ignore_errors: true
          run 'sudo ufw default deny incoming', ignore_errors: true
          run 'sudo ufw default allow outgoing', ignore_errors: true
          run 'sudo ufw allow ssh', ignore_errors: true
          run 'sudo ufw allow {{nginx_port || 80}}', ignore_errors: true
          run 'sudo ufw allow {{nginx_ssl_port || 443}}', ignore_errors: true
          run 'sudo ufw --force enable', ignore_errors: true

          # Install fail2ban
          run 'sudo apt-get install -y fail2ban', ignore_errors: true
          run 'sudo systemctl enable fail2ban', ignore_errors: true
          run 'sudo systemctl start fail2ban', ignore_errors: true

          run 'echo "✅ Security hardening completed on {{hostname}}"'
        end

        # Common performance tuning
        task 'performance_tuning', on: :all do
          run 'echo "Applying performance tuning on {{hostname}}..."'

          # System limits
          run <<~LIMITS
            sudo tee -a /etc/security/limits.conf > /dev/null << 'EOF'
            * soft nofile 65536
            * hard nofile 65536
            * soft nproc 32768
            * hard nproc 32768
            EOF
          LIMITS

          # Kernel parameters
          run <<~SYSCTL
            sudo tee -a /etc/sysctl.conf > /dev/null << 'EOF'
            # Network performance
            net.core.rmem_max = 16777216
            net.core.wmem_max = 16777216
            net.ipv4.tcp_rmem = 4096 65536 16777216
            net.ipv4.tcp_wmem = 4096 65536 16777216
            EOF
          SYSCTL

          run 'sudo sysctl -p', ignore_errors: true

          run 'echo "✅ Performance tuning completed on {{hostname}}"'
        end

        # ===================================================================
        # COMMON UTILITY FUNCTIONS
        # ===================================================================

        # Health check wrapper (LOCAL + REMOTE)
        task 'health_check_all', on: :all do
          local 'echo "🏥 Running comprehensive health checks..."'

          # You can call other scripts from here
          local 'echo "1. System health check"'
          # local 'kdeploy deploy scripts/monitoring.rb --task system_health'

          local 'echo "2. Application health check"'
          # local 'kdeploy deploy scripts/monitoring.rb --task app_health'

          local 'echo "3. Service status check"'
          # local 'kdeploy deploy scripts/monitoring.rb --task service_status'

          local 'echo "✅ Health checks completed"'

          # Add a dummy remote command to satisfy validation
          run 'echo "Health check completed on {{hostname}}"'
        end

        # Deployment verification
        task 'verify_deployment', on: :webservers do
          run 'echo "🔍 Verifying deployment on {{hostname}}..."'

          # Check if application directory exists
          run 'test -d {{deploy_to}} && echo "✅ Application directory exists" || echo "❌ Application directory missing"'

          # Check if application is running
          run 'systemctl is-active {{application}} && echo "✅ Application service is running" || echo "❌ Application service not running"', ignore_errors: true

          # Check if application responds
          run 'curl -f http://localhost:{{app_port || 3000}}/health && echo "✅ Application responds to health check" || echo "❌ Application health check failed"',
              ignore_errors: true, timeout: 10

          run 'echo "✅ Deployment verification completed on {{hostname}}"'
        end

        # ===================================================================
        # EMERGENCY PROCEDURES
        # ===================================================================

        # Emergency stop all services
        task 'emergency_stop', on: :all do
          run 'echo "🚨 Emergency stop initiated on {{hostname}}"'
          run 'sudo systemctl stop {{application}}', ignore_errors: true
          run 'sudo systemctl stop nginx', ignore_errors: true
          run 'echo "🛑 Services stopped on {{hostname}}"'
        end

        # Emergency start all services
        task 'emergency_start', on: :all do
          run 'echo "🚨 Emergency start initiated on {{hostname}}"'
          run 'sudo systemctl start nginx', ignore_errors: true
          run 'sudo systemctl start {{application}}', ignore_errors: true
          run 'echo "🚀 Services started on {{hostname}}"'
        end

        # ===================================================================
        # USAGE EXAMPLES
        # ===================================================================
        #
        # This file can be included in your main deploy.rb script:
        #
        # include 'scripts/common_tasks.rb' if File.exist?('scripts/common_tasks.rb')
        #
        # Then you can call these tasks from your deployment workflow:
        #
        # task 'full_setup' do
        #   run_task 'pre_deploy_checks'
        #   run_task 'setup_environment'
        #   run_task 'security_hardening'
        #   run_task 'performance_tuning'
        # end
        #
        # Or run them individually:
        # kdeploy deploy scripts/common_tasks.rb --task setup_environment
        # kdeploy deploy scripts/common_tasks.rb --task security_hardening
        #
      RUBY

      File.write("#{project_name}/scripts/common_tasks.rb", common_tasks_script)
      info "Created script: #{project_name}/scripts/common_tasks.rb"
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
