# frozen_string_literal: true

require 'fileutils'

module Kdeploy
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

        # Define roles
        role :web, %w[web01 web02]
        role :db, %w[db01]

        # Define inventory
        inventory do
          host 'db01', user: 'root', ip: '10.0.0.3', key: '~/.ssh/id_rsa'
        end

        # Define deployment task for web servers
        task :deploy_web, roles: :web do
          # Stop service
          run 'sudo systemctl stop nginx'

          # Upload configuration using ERB template
          upload_template './config/nginx.conf.erb', '/etc/nginx/nginx.conf',
            domain_name: 'example.com',
            port: 3000,
            worker_processes: 4,
            worker_connections: 2048

          # Upload static configuration
          upload './config/app.conf', '/etc/nginx/conf.d/app.conf'

          # Restart service
          run 'sudo systemctl start nginx'

          # Check status
          run 'sudo systemctl status nginx'
        end

        # Define backup task for database servers
        task :backup_db, roles: :db do
          run 'tar -czf /tmp/backup.tar.gz /var/lib/postgresql/data'
          run 'aws s3 cp /tmp/backup.tar.gz s3://my-backups/'
          run 'rm /tmp/backup.tar.gz'
        end

        # Define task for specific hosts
        task :maintenance, on: %w[web01] do
          run 'sudo systemctl stop nginx'
          run 'sudo apt-get update && sudo apt-get upgrade -y'
          run 'sudo systemctl start nginx'
        end

        # Define task for all hosts
        task :update do
          run 'sudo apt-get update && sudo apt-get upgrade -y'
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

        ## Structure

        ```
        .
        ├── deploy.rb           # Deployment tasks
        ├── config/            # Configuration files
        │   ├── nginx.conf.erb # Nginx configuration template
        │   └── app.conf      # Static configuration
        └── README.md         # This file
        ```

        ## Configuration Templates

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

        ## Usage

        ```bash
        # Show what would be done
        kdeploy execute deploy.rb --dry-run

        # Deploy to web servers
        kdeploy execute deploy.rb deploy_web

        # Backup database
        kdeploy execute deploy.rb backup_db

        # Run maintenance on web01
        kdeploy execute deploy.rb maintenance

        # Update all hosts
        kdeploy execute deploy.rb update

        # Deploy to specific hosts
        kdeploy execute deploy.rb deploy_web --limit web01,web02
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
