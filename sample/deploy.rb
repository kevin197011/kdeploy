# frozen_string_literal: true

# Define hosts
host 'web01', user: 'ubuntu', ip: '10.0.0.1', key: '~/.ssh/id_rsa'
host 'web02', user: 'ubuntu', ip: '10.0.0.2', key: '~/.ssh/id_rsa'
host 'db01', user: 'root', ip: '10.0.0.3', key: '~/.ssh/id_rsa'

# Define roles
role :web, %w[web01 web02]
role :db, %w[db01]

# Define deployment task for web servers
task :deploy_web, roles: :web do
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
  run <<~SHELL
    sudo apt-get update && sudo apt-get upgrade -y
  SHELL
end
