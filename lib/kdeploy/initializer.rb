# frozen_string_literal: true

require 'fileutils'

module Kdeploy
  # Project initializer for creating new deployment projects
  class Initializer
    def initialize(target_dir = '.')
      @target_dir = File.expand_path(target_dir)
    end

    def run
      create_directory_structure
      create_deploy_file
      create_config_files
      create_readme
      show_success_message
    end

    private

    def create_directory_structure
      FileUtils.mkdir_p(@target_dir) unless @target_dir == '.'
      FileUtils.mkdir_p(File.join(@target_dir, 'config'))
    end

    def create_deploy_file
      File.write(File.join(@target_dir, 'deploy.rb'), <<~RUBY)
        # frozen_string_literal: true

        # Define hosts
        host 'web01', user: 'ubuntu', ip: '10.0.0.1', key: '~/.ssh/id_rsa'
        host 'web02', user: 'ubuntu', ip: '10.0.0.2', key: '~/.ssh/id_rsa'
        # Example: Host with sudo enabled (all commands automatically use sudo)
        # host 'web03', user: 'ubuntu', ip: '10.0.0.3', key: '~/.ssh/id_rsa', use_sudo: true
        host 'db01', user: 'root', ip: '10.0.0.3', key: '~/.ssh/id_rsa'

        # Define roles
        role :web, %w[web01 web02]
        role :db, %w[db01]

        # Define deployment task for web servers
        task :deploy_web, roles: :web do
          # Example: Using sudo option for specific command
          # run "systemctl stop nginx", sudo: true
          run <<~SHELL
            sudo systemctl stop nginx
            echo "Deploying..."
          SHELL

          upload_template './config/nginx.conf.erb', '/etc/nginx/nginx.conf',
            domain_name: 'example.com',
            port: 3000,
            worker_processes: 4,
            worker_connections: 2048

          upload './config/app.conf', '/etc/nginx/conf.d/app.conf'

          run <<~SHELL
            sudo systemctl start nginx
            sudo systemctl status nginx
          SHELL
        end

        # Define backup task for database servers
        task :backup_db, roles: :db do
          run <<~SHELL
            tar -czf /tmp/backup.tar.gz /var/lib/postgresql/data
            aws s3 cp /tmp/backup.tar.gz s3://my-backups/
            rm /tmp/backup.tar.gz
          SHELL
        end

        # Define task for specific hosts
        task :maintenance, on: %w[web01] do
          run <<~SHELL
            sudo systemctl stop nginx
            sudo apt-get update && sudo apt-get upgrade -y
            sudo systemctl start nginx
          SHELL
        end

        # Define task for all hosts
        task :update do
          # Example: Using sudo option for specific command
          # run "apt-get update && apt-get upgrade -y", sudo: true
          run <<~SHELL
            sudo apt-get update && sudo apt-get upgrade -y
          SHELL
        end

        # Example: Directory synchronization task
        task :sync_app, roles: :web do
          # Sync application directory, ignoring development files
          sync './app', '/var/www/app',
            ignore: ['.git', '*.log', 'node_modules', '.env.local', '*.tmp'],
            delete: true

          # Sync configuration files
          sync './config', '/etc/app',
            exclude: ['*.example', '*.bak']
        end
      RUBY
    end

    def create_config_files
      # 创建配置目录
      config_dir = File.join(@target_dir, 'config')
      FileUtils.mkdir_p(config_dir)

      # 创建 Nginx ERB 模板
      File.write(File.join(config_dir, 'nginx.conf.erb'), <<~CONF)
        user nginx;
        worker_processes <%= worker_processes %>;
        error_log /var/log/nginx/error.log;
        pid /run/nginx.pid;

        events {
            worker_connections <%= worker_connections %>;
        }

        http {
            include /etc/nginx/mime.types;
            default_type application/octet-stream;

            log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                          '$status $body_bytes_sent "$http_referer" '
                          '"$http_user_agent" "$http_x_forwarded_for"';

            access_log /var/log/nginx/access.log main;

            sendfile on;
            tcp_nopush on;
            tcp_nodelay on;
            keepalive_timeout 65;
            types_hash_max_size 2048;

            upstream app_servers {
                server 127.0.0.1:<%= port %>;
            }

            server {
                listen 80;
                server_name <%= domain_name %>;

                location / {
                    proxy_pass http://app_servers;
                    proxy_http_version 1.1;
                    proxy_set_header Upgrade $http_upgrade;
                    proxy_set_header Connection 'upgrade';
                    proxy_set_header Host $host;
                    proxy_cache_bypass $http_upgrade;
                }

                error_page 500 502 503 504 /50x.html;
                location = /50x.html {
                    root /usr/share/nginx/html;
                }
            }
        }
      CONF

      # 创建静态配置文件示例
      File.write(File.join(config_dir, 'app.conf'), <<~CONF)
        location /api {
            proxy_pass http://localhost:3000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_cache_bypass $http_upgrade;
        }
      CONF
    end

    def create_readme
      File.write(File.join(@target_dir, 'README.md'), <<~MD)
        # Deployment Project

        This is a deployment project created with Kdeploy.

        ## 📁 Structure

        ```
        .
        ├── deploy.rb           # Deployment tasks
        ├── config/            # Configuration files
        │   ├── nginx.conf.erb # Nginx configuration template
        │   └── app.conf      # Static configuration
        └── README.md         # This file
        ```

        ## 🔧 Configuration Templates

        The project uses ERB templates for dynamic configuration. For example, in `nginx.conf.erb`:

        ```erb
        worker_processes <%= worker_processes %>;
        server_name <%= domain_name %>;
        ```

        Variables are passed when uploading the template:

        ```ruby
        upload_template "./config/nginx.conf.erb", "/etc/nginx/nginx.conf",
          domain_name: "example.com",
          worker_processes: 4
        ```

        ## 🔐 Using Sudo

        Kdeploy supports sudo execution in two ways:

        1. **Host-level configuration** (all commands automatically use sudo):
        ```ruby
        host 'web01', user: 'ubuntu', ip: '10.0.0.1', key: '~/.ssh/id_rsa', use_sudo: true
        ```

        2. **Command-level configuration** (only specific commands use sudo):
        ```ruby
        run "systemctl restart nginx", sudo: true
        ```

        See the main documentation for more details on sudo usage.

        ## 🚀 Usage

        ### Task Execution

        ```bash
        # Execute all tasks in the file
        kdeploy execute deploy.rb

        # Execute a specific task
        kdeploy execute deploy.rb deploy_web

        # Execute with dry run (preview mode)
        kdeploy execute deploy.rb --dry-run

        # Execute on specific hosts
        kdeploy execute deploy.rb --limit web01,web02

        # Execute with custom parallel count
        kdeploy execute deploy.rb --parallel 5
        ```

        When executing without specifying a task name (`kdeploy execute deploy.rb`), Kdeploy will:
        1. Execute all defined tasks in the file
        2. Run tasks in the order they were defined
        3. Show task name before each task execution
        4. Display color-coded output for better readability:
            - 🟢 Green: Normal output and success messages
            - 🔴 Red: Errors and failure messages
            - 🟡 Yellow: Warnings and notices

        ### Available Tasks

        - **deploy_web**: Deploy and configure Nginx web servers
          ```bash
          kdeploy execute deploy.rb deploy_web
          ```

        - **backup_db**: Backup database to S3
          ```bash
          kdeploy execute deploy.rb backup_db
          ```

        - **maintenance**: Run maintenance on specific host
          ```bash
          kdeploy execute deploy.rb maintenance
          ```

        - **update**: Update all hosts
          ```bash
          kdeploy execute deploy.rb update
          ```

        - **sync_app**: Sync application directory to remote servers
          ```bash
          kdeploy execute deploy.rb sync_app
          ```
      MD
    end

    def show_success_message
      pastel = Pastel.new
      puts Kdeploy::Banner.show_success("Project initialized in #{@target_dir}")
      puts <<~INFO
        #{pastel.bright_white('Created files:')}
        #{pastel.dim("  #{File.join(@target_dir, 'deploy.rb')}")}
        #{pastel.dim("  #{File.join(@target_dir, 'config/nginx.conf.erb')}")}
        #{pastel.dim("  #{File.join(@target_dir, 'config/app.conf')}")}
        #{pastel.dim("  #{File.join(@target_dir, 'README.md')}")}

        #{pastel.bright_white('Try running:')}
        #{pastel.bright_cyan("  kdeploy execute #{File.join(@target_dir, 'deploy.rb')} deploy_web --dry-run")}
      INFO
    end
  end
end
