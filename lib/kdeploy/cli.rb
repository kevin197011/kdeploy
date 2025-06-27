# frozen_string_literal: true

require 'thor'
require 'tty-prompt'

module Kdeploy
  class CLI < Thor
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

    desc 'init [PROJECT_NAME]', 'Initialize new deployment project'
    option :name, aliases: '-n', desc: 'Project name'
    def init(project_name = nil)
      project_name ||= options[:name] || File.basename(Dir.pwd)

      info "Initializing kdeploy project: #{project_name}"

      create_project_structure(project_name)
      create_sample_files(project_name)

      success 'Project initialized successfully!'
      info "Edit #{project_name}/deploy.rb to configure your deployment"
    end

    desc 'validate SCRIPT', 'Validate deployment script'
    option :config, aliases: '-c', desc: 'Configuration file path'
    option :inventory, aliases: '-i', desc: 'Inventory file path'
    def validate(script_file)
      setup_configuration

      unless File.exist?(script_file)
        error "Script file not found: #{script_file}"
        exit 1
      end

      begin
        pipeline = Kdeploy.load_script(script_file)
        validation_errors = pipeline.validate

        if validation_errors.empty?
          success '✅ Script validation passed'
          info "Pipeline: #{pipeline.name}"
          info "Hosts: #{pipeline.hosts.size}"
          info "Tasks: #{pipeline.tasks.size}"
        else
          error '❌ Script validation failed:'
          validation_errors.each { |err| error "  - #{err}" }
          exit 1
        end
      rescue Kdeploy::Error => e
        error "Validation failed: #{e.message}"
        exit 1
      end
    end

    desc 'config', 'Show configuration'
    option :config, aliases: '-c', desc: 'Configuration file path'
    def config
      setup_configuration

      config = Kdeploy.configuration

      info 'Kdeploy Configuration:'
      info "  Max concurrent tasks: #{config.max_concurrent_tasks}"
      info "  SSH timeout: #{config.ssh_timeout}s"
      info "  Command timeout: #{config.command_timeout}s"
      info "  Retry count: #{config.retry_count}"
      info "  Retry delay: #{config.retry_delay}s"
      info "  Log level: #{config.log_level}"
      info "  Log file: #{config.log_file || 'stdout'}"
      info "  Inventory file: #{config.inventory_file}"
      info "  Template directory: #{config.template_dir}"
      info "  Default user: #{config.default_user}"
      info "  Default port: #{config.default_port}"
    end

    desc 'version', 'Show version'
    def version
      puts "kdeploy version #{Kdeploy::VERSION}"
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
