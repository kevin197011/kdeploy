# frozen_string_literal: true

# Add String truncate method if not available
class String
  def truncate(length)
    return self if size <= length

    "#{self[0, length - 3]}..."
  end
end

module Kdeploy
  # Command Line Interface for kdeploy
  class CLI < Thor
    # Fix Thor deprecation warning
    def self.exit_on_failure?
      true
    end

    # Common options for commands that execute scripts
    SCRIPT_OPTIONS = {
      config: { aliases: '-c', desc: 'Configuration file path' },
      inventory: { aliases: '-i', desc: 'Inventory file path' },
      dry_run: { aliases: '-d', type: :boolean, desc: 'Perform dry run without executing' },
      verbose: { aliases: '-v', type: :boolean, desc: 'Enable verbose output' },
      log_file: { aliases: '-l', desc: 'Log file path' }
    }.freeze

    desc 'execute SCRIPT', 'Execute deployment script'
    SCRIPT_OPTIONS.each { |name, opts| option(name, opts) }
    def execute(script_file)
      setup_configuration
      setup_logging

      validate_script_file(script_file)

      begin
        options[:dry_run] ? perform_dry_run(script_file) : execute_script(script_file)
      rescue Kdeploy::Error => e
        handle_deployment_error(e)
      rescue StandardError => e
        handle_unexpected_error(e)
      end
    end

    desc 'deploy SCRIPT', 'Execute deployment script (alias for execute)'
    SCRIPT_OPTIONS.each { |name, opts| option(name, opts) }
    def deploy(script_file)
      execute(script_file)
    end

    desc 'init [PROJECT_NAME]', 'Initialize new deployment project'
    option :name, aliases: '-n', desc: 'Specify project name'
    def init(project_name = nil)
      show_kdeploy_banner
      project_name = determine_project_name(project_name)

      display_init_header(project_name)
      create_project_structure(project_name)
      display_init_success(project_name)
    end

    desc 'validate SCRIPT', 'Validate deployment script'
    option :config, aliases: '-c', desc: 'Configuration file path'
    option :inventory, aliases: '-i', desc: 'Inventory file path'
    def validate(script_file)
      show_kdeploy_banner
      setup_configuration

      display_validation_header(script_file)
      validate_script_file(script_file)

      begin
        pipeline = Kdeploy.load_script(script_file)
        validation_errors = pipeline.validate

        if validation_errors.empty?
          display_validation_success(pipeline)
        else
          display_validation_errors(validation_errors)
        end
      rescue Kdeploy::Error => e
        display_validation_failure(e)
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

      display_configuration(Kdeploy.configuration)
    end

    desc 'version', 'Show version'
    def version
      show_kdeploy_banner
      display_version_info
    end

    desc 'help [COMMAND]', 'Describe available commands or one specific command'
    def help(command = nil)
      show_kdeploy_banner
      puts ''
      puts '📖 Available Commands:'.colorize(:yellow)
      puts ''

      if command
        super
      else
        display_available_commands
      end
    end

    desc 'stats [COMMAND]', 'Show deployment statistics'
    option :days, aliases: '-d', type: :numeric, default: 30, desc: 'Number of days to analyze'
    option :format, aliases: '-f', type: :string, default: 'text', desc: 'Output format (text, json, csv)'
    option :output, aliases: '-o', type: :string, desc: 'Output file path'
    def stats(command = 'summary')
      case command.downcase
      when 'summary'
        show_summary_stats
      when 'deployments'
        show_deployment_stats
      when 'tasks'
        show_task_stats
      when 'failures'
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
        puts ''
        puts 'Available commands: summary, deployments, tasks, failures, trends, global, clear, export'
        exit 1
      end
    end

    private

    def display_configuration(config)
      puts ''
      puts '⚙️  Current Configuration'.colorize(:yellow)
      puts '=' * 50

      display_execution_settings(config)
      display_network_settings(config)
      display_file_settings(config)
      display_logging_settings(config)
      display_ssh_options(config) if config.respond_to?(:ssh_options) && config.ssh_options&.any?

      puts ''
      puts '💡 Use --config FILE to load custom configuration'.colorize(:yellow)
      puts ''
    end

    def display_execution_settings(config)
      puts ''
      puts '🔧 Execution Settings'.colorize(:cyan)
      puts "  Max Concurrent Tasks: #{config.max_concurrent_tasks}".colorize(:light_blue)
      puts "  Retry Count: #{config.retry_count}".colorize(:light_blue)
      puts "  Retry Delay: #{config.retry_delay}s".colorize(:light_blue)
    end

    def display_network_settings(config)
      puts ''
      puts '🌐 Network & SSH Settings'.colorize(:cyan)
      puts "  SSH Timeout: #{config.ssh_timeout}s".colorize(:light_blue)
      puts "  Command Timeout: #{config.command_timeout}s".colorize(:light_blue)
      puts "  Default User: #{config.default_user}".colorize(:light_blue)
      puts "  Default Port: #{config.default_port}".colorize(:light_blue)
    end

    def display_file_settings(config)
      puts ''
      puts '📁 File & Directory Settings'.colorize(:cyan)
      puts "  Inventory File: #{config.inventory_file || 'not specified'}".colorize(:light_blue)
      puts "  Template Directory: #{config.template_dir}".colorize(:light_blue)
    end

    def display_logging_settings(config)
      puts ''
      puts '📋 Logging Settings'.colorize(:cyan)
      puts "  Log Level: #{config.log_level}".colorize(:light_blue)
      puts "  Log File: #{config.log_file || 'stdout'}".colorize(:light_blue)
    end

    def display_ssh_options(config)
      puts ''
      puts '🔐 SSH Options'.colorize(:cyan)
      config.ssh_options.each do |key, value|
        puts "  #{key.to_s.capitalize.gsub('_', ' ')}: #{value}".colorize(:light_blue)
      end
    end

    def display_version_info
      puts ''
      puts "🔖 Version: #{Kdeploy::VERSION}".colorize(:green)
      puts '📅 Released: 2025'.colorize(:light_blue)
      puts '🏠 Homepage: https://github.com/kevin197011/kdeploy'.colorize(:light_blue)
      puts '📚 Documentation: https://github.com/kevin197011/kdeploy/wiki'.colorize(:light_blue)
      puts ''
    end

    def display_available_commands
      puts "  🚀 #{'deploy SCRIPT'.ljust(25)} Execute deployment script"
      puts "  ⚡ #{'execute SCRIPT'.ljust(25)} Execute deployment script (alias for deploy)"
      puts "  🆕 #{'init [PROJECT_NAME]'.ljust(25)} Initialize new deployment project"
      puts "  ✅ #{'validate SCRIPT'.ljust(25)} Validate deployment script"
      puts "  ⚙️  #{'config'.ljust(25)} Show configuration"
      puts "  📊 #{'stats [COMMAND]'.ljust(25)} Show deployment statistics"
      puts "  🔖 #{'version'.ljust(25)} Show version"
      puts ''
      puts '💡 For more details on a command:'.colorize(:yellow)
      puts '   kdeploy help COMMAND'.colorize(:light_blue)
      puts ''
    end

    def setup_configuration
      Kdeploy.configure do |config|
        config.config_file = options[:config] if options[:config]
        config.inventory_file = options[:inventory] if options[:inventory]
        config.log_level = options[:verbose] ? :debug : :info
        config.log_file = options[:log_file] if options[:log_file]
      end
    end

    def setup_logging
      config = Kdeploy.configuration
      KdeployLogger.setup(
        level: config.log_level,
        log_file: config.log_file
      )
    end

    def perform_dry_run(script_file)
      info '🔍 Performing dry run...'
      pipeline = Kdeploy.load_script(script_file)

      puts ''
      puts '📋 Pipeline Summary:'.colorize(:cyan)
      puts "  Name: #{pipeline.name}".colorize(:light_blue)
      puts "  Hosts: #{pipeline.hosts.size}".colorize(:light_blue)
      puts "  Tasks: #{pipeline.tasks.size}".colorize(:light_blue)

      display_target_hosts(pipeline.hosts) if pipeline.hosts.any?
      display_tasks(pipeline.tasks) if pipeline.tasks.any?

      success '✅ Dry run completed'
    end

    def execute_script(script_file)
      show_kdeploy_banner
      info "🚀 Executing deployment script: #{script_file}"

      pipeline = Kdeploy.load_script(script_file)
      result = pipeline.execute

      if result[:success]
        success '✅ Deployment completed successfully'
      else
        error '❌ Deployment failed'
        exit 1
      end
    end

    def show_kdeploy_banner
      Banner.show
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

    def create_project_structure(project_name)
      create_project_directories(project_name)
      create_sample_files(project_name)
      create_sample_scripts(project_name)
      create_sample_templates(project_name)
    end

    def create_project_directories(project_name)
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
      create_deploy_script(project_name)
      create_inventory_file(project_name)
      create_config_file(project_name)
    end

    def create_deploy_script(project_name)
      content = <<~RUBY
        # frozen_string_literal: true

        # Main deployment script
        pipeline 'main' do
          # Define target hosts
          host 'app1.example.com', roles: [:app, :web]
          host 'app2.example.com', roles: [:app, :web]
          host 'db.example.com', roles: [:db]

          # Set global variables
          set :app_name, 'my_app'
          set :deploy_to, '/var/www/${app_name}'
          set :keep_releases, 5

          # Define tasks
          task :check_requirements do
            run 'ruby -v'
            run 'node -v'
            run 'git --version'
          end

          task :setup_directories do
            run "mkdir -p ${deploy_to}"
            run "mkdir -p ${deploy_to}/releases"
            run "mkdir -p ${deploy_to}/shared"
          end

          task :deploy do
            depends_on :check_requirements, :setup_directories

            run 'git clone https://github.com/user/repo.git ${deploy_to}/releases/$(date +%Y%m%d%H%M%S)'
            run 'ln -sfn ${deploy_to}/releases/$(ls -t ${deploy_to}/releases | head -n1) ${deploy_to}/current'
          end

          task :restart_services do
            run 'sudo systemctl restart nginx'
            run 'sudo systemctl restart app'
          end

          task :cleanup do
            run "cd ${deploy_to}/releases && ls -t | tail -n +${keep_releases + 1} | xargs rm -rf"
          end
        end
      RUBY

      write_file("#{project_name}/deploy.rb", content)
      info "Created deployment script: #{project_name}/deploy.rb"
    end

    def create_inventory_file(project_name)
      content = <<~YAML
        # Server inventory configuration
        groups:
          production:
            hosts:
              - hostname: app1.example.com
                roles: [app, web]
                user: deploy
                port: 22
              - hostname: app2.example.com
                roles: [app, web]
                user: deploy
                port: 22
              - hostname: db.example.com
                roles: [db]
                user: deploy
                port: 22
                vars:
                  db_name: production_db
                  db_user: app_user

          staging:
            hosts:
              - hostname: staging.example.com
                roles: [app, web, db]
                user: deploy
                port: 22
                vars:
                  rails_env: staging
                  node_env: staging
      YAML

      write_file("#{project_name}/inventory.yml", content)
      info "Created inventory file: #{project_name}/inventory.yml"
    end

    def create_config_file(project_name)
      content = <<~YAML
        # Deployment configuration
        max_concurrent_tasks: 5
        retry_count: 3
        retry_delay: 5
        ssh_timeout: 30
        command_timeout: 300

        default_user: deploy
        default_port: 22

        template_dir: templates
        inventory_file: inventory.yml

        ssh_options:
          forward_agent: true
          verify_host_key: true
          keepalive: true
          keepalive_interval: 30

        logging:
          level: info
          file: kdeploy.log
      YAML

      write_file("#{project_name}/config/kdeploy.yml", content)
      info "Created configuration file: #{project_name}/config/kdeploy.yml"
    end

    def create_sample_scripts(project_name)
      create_setup_script(project_name)
      create_database_script(project_name)
      create_backup_script(project_name)
      create_monitoring_script(project_name)
      create_rollback_script(project_name)
      create_cleanup_script(project_name)
    end

    def create_setup_script(project_name)
      content = <<~RUBY
        # frozen_string_literal: true

        # Server setup script
        pipeline 'setup' do
          # Target all hosts
          host 'app1.example.com', roles: [:app, :web]
          host 'app2.example.com', roles: [:app, :web]
          host 'db.example.com', roles: [:db]

          # Set global variables
          set :ruby_version, '3.2.0'
          set :node_version, '18.x'

          task :install_dependencies do
            run <<~BASH
              # Update package lists
              sudo apt-get update

              # Install essential packages
              sudo apt-get install -y build-essential git curl
              sudo apt-get install -y nginx redis-server
            BASH
          end

          task :setup_ruby do
            run <<~BASH
              # Install rbenv
              git clone https://github.com/rbenv/rbenv.git ~/.rbenv
              echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
              echo 'eval "$(rbenv init -)"' >> ~/.bashrc
              source ~/.bashrc

              # Install ruby-build
              git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build

              # Install Ruby
              rbenv install ${ruby_version}
              rbenv global ${ruby_version}
            BASH
          end

          task :setup_node do
            run <<~BASH
              # Install Node.js
              curl -fsSL https://deb.nodesource.com/setup_${node_version} | sudo -E bash -
              sudo apt-get install -y nodejs

              # Install Yarn
              curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
              echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
              sudo apt-get update && sudo apt-get install -y yarn
            BASH
          end

          task :setup_nginx do
            # Upload nginx configuration
            upload_template 'nginx.conf', '/etc/nginx/sites-available/app'
            run 'sudo ln -sf /etc/nginx/sites-available/app /etc/nginx/sites-enabled/app'
            run 'sudo nginx -t && sudo systemctl restart nginx'
          end

          task :setup_app_service do
            # Upload systemd service configuration
            upload_template 'app.service', '/etc/systemd/system/app.service'
            run 'sudo systemctl daemon-reload'
            run 'sudo systemctl enable app'
          end

          task :setup do
            depends_on :install_dependencies,
                      :setup_ruby,
                      :setup_node,
                      :setup_nginx,
                      :setup_app_service
          end
        end
      RUBY

      write_file("#{project_name}/scripts/setup.rb", content)
      info "Created setup script: #{project_name}/scripts/setup.rb"
    end

    def create_database_script(project_name)
      content = <<~RUBY
        # frozen_string_literal: true

        # Database management script
        pipeline 'database' do
          # Target database hosts
          host 'db.example.com', roles: [:db]

          # Set database configuration
          set :db_name, 'app_production'
          set :db_user, 'app_user'
          set :db_password, ENV['DB_PASSWORD']

          task :create_database do
            run <<~SQL
              psql -U postgres -c "CREATE USER ${db_user} WITH PASSWORD '${db_password}';"
              psql -U postgres -c "CREATE DATABASE ${db_name} OWNER ${db_user};"
            SQL
          end

          task :migrate do
            run 'cd /var/www/app/current && RAILS_ENV=production bundle exec rake db:migrate'
          end

          task :seed do
            run 'cd /var/www/app/current && RAILS_ENV=production bundle exec rake db:seed'
          end

          task :backup do
            run <<~BASH
              timestamp=$(date +%Y%m%d_%H%M%S)
              pg_dump -U ${db_user} ${db_name} > /var/backups/${db_name}_${timestamp}.sql
              gzip /var/backups/${db_name}_${timestamp}.sql
            BASH
          end

          task :restore do
            run <<~BASH
              latest_backup=$(ls -t /var/backups/${db_name}_*.sql.gz | head -n1)
              gunzip -c $latest_backup | psql -U ${db_user} ${db_name}
            BASH
          end
        end
      RUBY

      write_file("#{project_name}/scripts/database.rb", content)
      info "Created database script: #{project_name}/scripts/database.rb"
    end

    def create_backup_script(project_name)
      content = <<~RUBY
        # frozen_string_literal: true

        # Backup operations script
        pipeline 'backup' do
          # Target all hosts
          host 'app1.example.com', roles: [:app, :web]
          host 'app2.example.com', roles: [:app, :web]
          host 'db.example.com', roles: [:db]

          # Set backup configuration
          set :backup_dir, '/var/backups'
          set :keep_backups, 10

          task :backup_database do
            only :db
            run <<~BASH
              timestamp=$(date +%Y%m%d_%H%M%S)
              pg_dump -U ${db_user} ${db_name} > ${backup_dir}/${db_name}_${timestamp}.sql
              gzip ${backup_dir}/${db_name}_${timestamp}.sql
            BASH
          end

          task :backup_uploads do
            only [:app, :web]
            run <<~BASH
              timestamp=$(date +%Y%m%d_%H%M%S)
              tar -czf ${backup_dir}/uploads_${timestamp}.tar.gz /var/www/app/shared/public/uploads
            BASH
          end

          task :backup_logs do
            run <<~BASH
              timestamp=$(date +%Y%m%d_%H%M%S)
              tar -czf ${backup_dir}/logs_${timestamp}.tar.gz /var/log/app
            BASH
          end

          task :cleanup_old_backups do
            run <<~BASH
              cd ${backup_dir}
              ls -t *.sql.gz | tail -n +${keep_backups + 1} | xargs rm -f
              ls -t *.tar.gz | tail -n +${keep_backups + 1} | xargs rm -f
            BASH
          end

          task :backup do
            depends_on :backup_database,
                      :backup_uploads,
                      :backup_logs,
                      :cleanup_old_backups
          end
        end
      RUBY

      write_file("#{project_name}/scripts/backup.rb", content)
      info "Created backup script: #{project_name}/scripts/backup.rb"
    end

    def create_monitoring_script(project_name)
      content = <<~RUBY
        # frozen_string_literal: true

        # Health checks and monitoring script
        pipeline 'monitoring' do
          # Target all hosts
          host 'app1.example.com', roles: [:app, :web]
          host 'app2.example.com', roles: [:app, :web]
          host 'db.example.com', roles: [:db]

          task :check_system_resources do
            run <<~BASH
              echo "Memory Usage:"
              free -h
              echo "\\nDisk Usage:"
              df -h
              echo "\\nCPU Load:"
              uptime
            BASH
          end

          task :check_services do
            run <<~BASH
              echo "Nginx Status:"
              sudo systemctl status nginx
              echo "\\nApp Status:"
              sudo systemctl status app
              echo "\\nRedis Status:"
              sudo systemctl status redis-server
            BASH
          end

          task :check_logs do
            run <<~BASH
              echo "Last 50 lines of application log:"
              tail -n 50 /var/www/app/current/log/production.log
              echo "\\nLast 50 lines of nginx error log:"
              sudo tail -n 50 /var/log/nginx/error.log
            BASH
          end

          task :check_database do
            only :db
            run <<~BASH
              echo "PostgreSQL Status:"
              sudo systemctl status postgresql
              echo "\\nDatabase Size:"
              psql -U ${db_user} -d ${db_name} -c "\\l+"
            BASH
          end

          task :monitor do
            depends_on :check_system_resources,
                      :check_services,
                      :check_logs,
                      :check_database
          end
        end
      RUBY

      write_file("#{project_name}/scripts/monitoring.rb", content)
      info "Created monitoring script: #{project_name}/scripts/monitoring.rb"
    end

    def create_rollback_script(project_name)
      content = <<~RUBY
        # frozen_string_literal: true

        # Rollback operations script
        pipeline 'rollback' do
          # Target application hosts
          host 'app1.example.com', roles: [:app, :web]
          host 'app2.example.com', roles: [:app, :web]

          # Set deployment configuration
          set :app_name, 'my_app'
          set :deploy_to, '/var/www/${app_name}'

          task :list_releases do
            run "ls -lt ${deploy_to}/releases"
          end

          task :rollback_code do
            run <<~BASH
              current_release=$(readlink ${deploy_to}/current)
              previous_release=$(ls -t ${deploy_to}/releases | head -n 2 | tail -n 1)
              ln -sfn ${deploy_to}/releases/$previous_release ${deploy_to}/current
            BASH
          end

          task :rollback_database do
            run 'cd ${deploy_to}/current && RAILS_ENV=production bundle exec rake db:rollback STEP=1'
          end

          task :restart_services do
            run 'sudo systemctl restart app'
            run 'sudo systemctl restart nginx'
          end

          task :rollback do
            depends_on :list_releases,
                      :rollback_code,
                      :rollback_database,
                      :restart_services
          end
        end
      RUBY

      write_file("#{project_name}/scripts/rollback.rb", content)
      info "Created rollback script: #{project_name}/scripts/rollback.rb"
    end

    def create_cleanup_script(project_name)
      content = <<~RUBY
        # frozen_string_literal: true

        # Cleanup operations script
        pipeline 'cleanup' do
          # Target all hosts
          host 'app1.example.com', roles: [:app, :web]
          host 'app2.example.com', roles: [:app, :web]
          host 'db.example.com', roles: [:db]

          # Set cleanup configuration
          set :app_name, 'my_app'
          set :deploy_to, '/var/www/${app_name}'
          set :keep_releases, 5
          set :keep_logs, 7

          task :cleanup_releases do
            run <<~BASH
              cd ${deploy_to}/releases
              ls -t | tail -n +${keep_releases + 1} | xargs rm -rf
            BASH
          end

          task :cleanup_logs do
            run <<~BASH
              find /var/www/app/current/log -name "*.log.*" -mtime +${keep_logs} -exec rm {} \\;
              find /var/log/nginx -name "*.log.*" -mtime +${keep_logs} -exec sudo rm {} \\;
            BASH
          end

          task :cleanup_temp do
            run <<~BASH
              find /tmp -name "#{app_name}-*" -mtime +1 -exec rm -rf {} \\;
              find /var/tmp -name "#{app_name}-*" -mtime +1 -exec rm -rf {} \\;
            BASH
          end

          task :cleanup do
            depends_on :cleanup_releases,
                      :cleanup_logs,
                      :cleanup_temp
          end
        end
      RUBY

      write_file("#{project_name}/scripts/cleanup.rb", content)
      info "Created cleanup script: #{project_name}/scripts/cleanup.rb"
    end

    def create_sample_templates(project_name)
      create_nginx_template(project_name)
      create_app_service_template(project_name)
      create_deploy_script_template(project_name)
      create_backup_script_template(project_name)
    end

    def create_nginx_template(project_name)
      content = <<~ERB
        # Nginx configuration for <%= app_name %>
        upstream app_server {
          server unix:/var/www/<%= app_name %>/shared/tmp/sockets/puma.sock fail_timeout=0;
        }

        server {
          listen 80;
          server_name <%= server_name %>;
          root /var/www/<%= app_name %>/current/public;

          location ^~ /assets/ {
            gzip_static on;
            expires max;
            add_header Cache-Control public;
          }

          try_files $uri/index.html $uri @app;

          location @app {
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header Host $http_host;
            proxy_redirect off;
            proxy_pass http://app_server;
          }

          error_page 500 502 503 504 /500.html;
          client_max_body_size 4G;
          keepalive_timeout 10;
        }
      ERB

      write_file("#{project_name}/templates/nginx.conf.erb", content)
      info "Created nginx template: #{project_name}/templates/nginx.conf.erb"
    end

    def create_app_service_template(project_name)
      content = <<~ERB
        [Unit]
        Description=<%= app_name %> application server
        After=network.target

        [Service]
        Type=simple
        User=<%= app_user %>
        WorkingDirectory=/var/www/<%= app_name %>/current
        Environment=RAILS_ENV=production
        Environment=PATH=/home/<%= app_user %>/.rbenv/shims:/usr/local/bin:/usr/bin:/bin
        ExecStart=/home/<%= app_user %>/.rbenv/shims/bundle exec puma -C config/puma.rb
        Restart=always
        RestartSec=1

        [Install]
        WantedBy=multi-user.target
      ERB

      write_file("#{project_name}/templates/app.service.erb", content)
      info "Created app service template: #{project_name}/templates/app.service.erb"
    end

    def create_deploy_script_template(project_name)
      content = <<~ERB
        #!/bin/bash
        # Deployment script for <%= app_name %>

        set -e

        APP_ROOT="/var/www/<%= app_name %>"
        CURRENT="$APP_ROOT/current"
        SHARED="$APP_ROOT/shared"
        RELEASE="$APP_ROOT/releases/$(date +%Y%m%d%H%M%S)"

        echo "Deploying <%= app_name %> to $RELEASE"

        # Create release directory
        mkdir -p $RELEASE

        # Clone repository
        git clone <%= repository_url %> $RELEASE

        # Install dependencies
        cd $RELEASE
        bundle install --deployment --without development test
        yarn install --production

        # Compile assets
        bundle exec rake assets:precompile RAILS_ENV=production

        # Create symlinks
        ln -s $SHARED/config/database.yml $RELEASE/config/database.yml
        ln -s $SHARED/config/master.key $RELEASE/config/master.key
        ln -s $SHARED/public/uploads $RELEASE/public/uploads

        # Update current symlink
        ln -sfn $RELEASE $CURRENT

        # Restart application
        sudo systemctl restart <%= app_name %>

        echo "Deployment completed successfully!"
      ERB

      write_file("#{project_name}/templates/deploy.sh.erb", content)
      info "Created deploy script template: #{project_name}/templates/deploy.sh.erb"
    end

    def create_backup_script_template(project_name)
      content = <<~ERB
        #!/bin/bash
        # Backup script for <%= app_name %>

        set -e

        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        BACKUP_DIR="<%= backup_dir %>"
        DB_NAME="<%= db_name %>"
        APP_ROOT="/var/www/<%= app_name %>"

        echo "Starting backup for <%= app_name %>"

        # Create backup directory
        mkdir -p $BACKUP_DIR

        # Backup database
        echo "Backing up database..."
        pg_dump -U <%= db_user %> $DB_NAME > $BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.sql
        gzip $BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.sql

        # Backup uploads
        echo "Backing up uploads..."
        tar -czf $BACKUP_DIR/uploads_${TIMESTAMP}.tar.gz $APP_ROOT/shared/public/uploads

        # Backup configuration
        echo "Backing up configuration..."
        tar -czf $BACKUP_DIR/config_${TIMESTAMP}.tar.gz $APP_ROOT/shared/config

        # Cleanup old backups
        echo "Cleaning up old backups..."
        find $BACKUP_DIR -name "*.sql.gz" -mtime +<%= keep_days %> -delete
        find $BACKUP_DIR -name "*.tar.gz" -mtime +<%= keep_days %> -delete

        echo "Backup completed successfully!"
      ERB

      write_file("#{project_name}/templates/backup.sh.erb", content)
      info "Created backup script template: #{project_name}/templates/backup.sh.erb"
    end

    def write_file(path, content)
      File.write(path, content)
    end

    def determine_project_name(project_name)
      project_name || options[:name] || File.basename(Dir.pwd)
    end

    def display_init_header(project_name)
      puts ''
      puts "🆕 Initializing kdeploy project: #{project_name}".colorize(:yellow)
      puts ''
    end

    def display_init_success(project_name)
      puts ''
      puts '✅ Project initialized successfully!'.colorize(:green)
      puts ''
      display_project_structure(project_name)
      display_next_steps(project_name)
      display_available_scripts
    end

    def display_project_structure(project_name)
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
    end

    def display_next_steps(project_name)
      puts '🚀 Next Steps:'.colorize(:cyan)
      puts "  1. cd #{project_name}".colorize(:light_blue)
      puts '  2. Edit deploy.rb to configure your deployment'.colorize(:light_blue)
      puts '  3. Update inventory.yml with your servers'.colorize(:light_blue)
      puts '  4. Run: kdeploy deploy scripts/setup.rb        # Setup servers'.colorize(:light_blue)
      puts '  5. Run: kdeploy deploy deploy.rb               # Deploy application'.colorize(:light_blue)
      puts ''
    end

    def display_available_scripts
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

    def validate_script_file(script_file)
      return if File.exist?(script_file)

      error "Script file not found: #{script_file}"
      exit 1
    end

    def display_validation_header(script_file)
      puts ''
      puts "🔍 Validating deployment script: #{script_file}".colorize(:yellow)
      puts ''
    end

    def display_validation_success(pipeline)
      puts '✅ Script validation passed'.colorize(:green)
      puts ''
      display_pipeline_summary(pipeline)
      display_target_hosts(pipeline.hosts) if pipeline.hosts.any?
      display_tasks(pipeline.tasks) if pipeline.tasks.any?
      puts ''
    end

    def display_pipeline_summary(pipeline)
      puts '📋 Pipeline Summary:'.colorize(:cyan)
      puts "  Name: #{pipeline.name}".colorize(:light_blue)
      puts "  Hosts: #{pipeline.hosts.size}".colorize(:light_blue)
      puts "  Tasks: #{pipeline.tasks.size}".colorize(:light_blue)
    end

    def display_target_hosts(hosts)
      puts ''
      puts '🖥️  Target Hosts:'.colorize(:cyan)
      hosts.each do |host|
        puts "  • #{host.hostname}:#{host.port} (#{host.user})".colorize(:light_blue)
      end
    end

    def display_tasks(tasks)
      puts ''
      puts '🔧 Tasks to Execute:'.colorize(:cyan)
      tasks.each_with_index do |task, index|
        puts "  #{index + 1}. #{task.name}".colorize(:light_blue)
      end
    end

    def display_validation_errors(errors)
      puts '❌ Script validation failed:'.colorize(:red)
      puts ''
      errors.each { |err| puts "  • #{err}".colorize(:red) }
      puts ''
      exit 1
    end

    def display_validation_failure(error)
      puts "❌ Validation failed: #{error.message}".colorize(:red)
      puts ''
      exit 1
    end

    def handle_deployment_error(error)
      error "Deployment failed: #{error.message}"
      exit 1
    end

    def handle_unexpected_error(error)
      error "Unexpected error: #{error.message}"
      KdeployLogger.debug("Backtrace: #{error.backtrace.join("\n")}")
      exit 1
    end

    def show_summary_stats
      show_kdeploy_banner
      stats = Kdeploy.statistics
      deployment_summary = stats.deployment_summary(days: options[:days])
      task_summary = stats.task_summary(days: options[:days])
      global_summary = stats.global_summary

      case options[:format].downcase
      when 'json'
        display_json_summary(deployment_summary, task_summary, global_summary)
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
      export_file = options[:output] || generate_export_filename
      format = determine_export_format(export_file)

      Kdeploy.statistics.export_statistics(export_file, format: format)
      success "Statistics exported to #{export_file}"
    end

    def display_json_summary(deployment_summary, task_summary, global_summary)
      puts JSON.pretty_generate(
        {
          deployment_summary: deployment_summary,
          task_summary: task_summary,
          global_summary: global_summary
        }
      )
    end

    def print_summary_table(deployment_summary, task_summary, global_summary)
      puts "\n📊 Kdeploy Statistics Summary (Last #{options[:days]} days)".colorize(:cyan)
      puts '=' * 60

      print_deployment_section(deployment_summary)
      print_task_section(task_summary)
      print_global_section(global_summary)
    end

    def print_deployment_section(summary)
      puts "\n📦 Deployment Statistics".colorize(:yellow)
      if summary[:total_deployments].positive?
        puts "  Total Deployments: #{summary[:total_deployments]}"
        puts "  Successful: #{summary[:successful_deployments]} (#{summary[:success_rate]}%)"
        puts "  Failed: #{summary[:failed_deployments]}"
        puts "  Average Duration: #{summary[:avg_duration]}s"
        puts "  Total Duration: #{format_duration(summary[:total_duration])}"
      else
        puts "  No deployments in the last #{options[:days]} days"
      end
    end

    def print_task_section(summary)
      puts "\n🔧 Task Statistics".colorize(:yellow)
      if summary[:total_task_executions].positive?
        puts "  Total Task Executions: #{summary[:total_task_executions]}"
        puts "  Unique Tasks: #{summary[:unique_tasks]}"
        print_top_tasks(summary[:tasks]) if summary[:tasks].any?
      else
        puts "  No task executions in the last #{options[:days]} days"
      end
    end

    def print_top_tasks(tasks)
      puts '  Top Tasks:'
      sorted_tasks = tasks.sort_by { |_, stats| -stats[:total_executions] }.first(5)
      sorted_tasks.each do |name, stats|
        puts "    #{name}: #{stats[:total_executions]} executions (#{stats[:success_rate]}% success)"
      end
    end

    def print_global_section(summary)
      puts "\n🌍 Global Statistics".colorize(:yellow)
      puts "  Total Deployments: #{summary[:total_deployments]}"
      puts "  Total Tasks: #{summary[:total_tasks]}"
      puts "  Total Commands: #{summary[:total_commands]}"
      puts "  Total Execution Time: #{format_duration(summary[:total_execution_time])}"
      puts "  Session Duration: #{format_duration(summary[:session_duration])}"
      puts ''
    end

    def print_deployment_table(summary)
      puts "\n📦 Deployment Statistics (Last #{options[:days]} days)".colorize(:cyan)
      puts '=' * 60

      if summary[:total_deployments].zero?
        puts 'No deployments found'
        return
      end

      display_deployment_stats(summary)
    end

    def display_deployment_stats(summary)
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

      if summary[:total_task_executions].zero?
        puts 'No task executions found'
        return
      end

      display_task_summary(summary)
      display_task_details(summary[:tasks]) if summary[:tasks].any?
    end

    def display_task_summary(summary)
      puts "Total Executions: #{summary[:total_task_executions]}"
      puts "Unique Tasks: #{summary[:unique_tasks]}"
      puts ''
    end

    def display_task_details(tasks)
      puts 'Task Details:'
      print_task_header
      tasks.each { |name, stats| print_task_row(name, stats) }
      puts ''
    end

    def print_task_header
      printf "%-30s %10s %10s %10s %12s %12s\n",
             'Task Name', 'Executions', 'Success', 'Failed', 'Success Rate', 'Avg Duration'
      puts '-' * 95
    end

    def print_task_row(name, stats)
      printf "%-30s %10d %10d %10d %11.1f%% %11.2fs\n",
             name.truncate(28),
             stats[:total_executions],
             stats[:successful],
             stats[:failed],
             stats[:success_rate],
             stats[:avg_duration]
    end

    def print_failure_table(failed_tasks)
      puts "\n❌ Top Failed Tasks (Last #{options[:days]} days)".colorize(:red)
      puts '=' * 60

      if failed_tasks.empty?
        puts 'No failed tasks found'
        return
      end

      print_failure_header
      failed_tasks.each { |task| print_failure_row(task) }
      puts ''
    end

    def print_failure_header
      printf "%-30s %10s %20s\n", 'Task Name', 'Failures', 'Last Failure'
      puts '-' * 62
    end

    def print_failure_row(task)
      last_failure_time = Time.at(task[:last_failure][:timestamp]).strftime('%Y-%m-%d %H:%M:%S')
      printf "%-30s %10d %20s\n",
             task[:task_name].truncate(28),
             task[:failure_count],
             last_failure_time
    end

    def print_trend_table(trends)
      puts "\n📈 Performance Trends (Last #{options[:days]} days)".colorize(:cyan)
      puts '=' * 80

      if trends[:trends].empty?
        puts 'No trend data available'
        return
      end

      print_trend_header
      trends[:trends].each { |date, stats| print_trend_row(date, stats) }
      puts ''
    end

    def print_trend_header
      printf "%-12s %10s %10s %10s %12s %12s\n",
             'Date', 'Total', 'Success', 'Failed', 'Success Rate', 'Avg Duration'
      puts '-' * 78
    end

    def print_trend_row(date, stats)
      printf "%-12s %10d %10d %10d %11.1f%% %11.2fs\n",
             date,
             stats[:total],
             stats[:successful],
             stats[:failed],
             stats[:success_rate],
             stats[:avg_duration]
    end

    def print_global_table(global_summary)
      puts "\n🌍 Global Statistics".colorize(:cyan)
      puts '=' * 60

      print_global_deployment_stats(global_summary)
      print_global_task_stats(global_summary)
      print_global_command_stats(global_summary)
      print_global_execution_stats(global_summary)
    end

    def print_global_deployment_stats(summary)
      puts 'Deployments:'
      puts "  Total: #{summary[:total_deployments]}"
      puts "  Successful: #{summary[:successful_deployments]}"
      puts "  Failed: #{summary[:failed_deployments]}"
    end

    def print_global_task_stats(summary)
      puts "\nTasks:"
      puts "  Total: #{summary[:total_tasks]}"
      puts "  Successful: #{summary[:successful_tasks]}"
      puts "  Failed: #{summary[:failed_tasks]}"
    end

    def print_global_command_stats(summary)
      puts "\nCommands:"
      puts "  Total: #{summary[:total_commands]}"
      puts "  Successful: #{summary[:successful_commands]}"
      puts "  Failed: #{summary[:failed_commands]}"
    end

    def print_global_execution_stats(summary)
      puts "\nExecution Time:"
      puts "  Total: #{format_duration(summary[:total_execution_time])}"
      puts "  Session: #{format_duration(summary[:session_duration])}"
      puts "  Session Started: #{summary[:session_start_time].strftime('%Y-%m-%d %H:%M:%S')}"
      puts ''
    end

    def format_duration(seconds)
      return '0s' if seconds.nil? || seconds.zero?

      if seconds < 60
        "#{seconds.round(1)}s"
      elsif seconds < 3600
        format_minutes(seconds)
      else
        format_hours(seconds)
      end
    end

    def format_minutes(seconds)
      minutes = (seconds / 60).to_i
      remaining_seconds = (seconds % 60).to_i
      "#{minutes}m #{remaining_seconds}s"
    end

    def format_hours(seconds)
      hours = (seconds / 3600).to_i
      remaining_minutes = ((seconds % 3600) / 60).to_i
      "#{hours}h #{remaining_minutes}m"
    end

    def generate_export_filename
      "kdeploy_stats_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"
    end

    def determine_export_format(filename)
      File.extname(filename) == '.csv' ? :csv : :json
    end
  end
end
