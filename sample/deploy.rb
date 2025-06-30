# frozen_string_literal: true

# Define hosts
host "web01", user: "ubuntu", ip: "10.0.0.1", key: "~/.ssh/id_rsa"
host "web02", user: "ubuntu", ip: "10.0.0.2", key: "~/.ssh/id_rsa"

# Define roles
role :web, %w[web01 web02]
role :db, %w[db01]

# Define inventory
inventory do
  host "db01", user: "root", ip: "10.0.0.3", key: "~/.ssh/id_rsa"
end

# Define deployment task for web servers
task :deploy_web, roles: :web do
  # Stop service
  run "sudo systemctl stop nginx"

  # Upload configuration using ERB template
  upload_template "./config/nginx.conf.erb", "/etc/nginx/nginx.conf",
    domain_name: "example.com",
    port: 3000,
    worker_processes: 4,
    worker_connections: 2048

  # Upload static configuration
  upload "./config/app.conf", "/etc/nginx/conf.d/app.conf"

  # Restart service
  run "sudo systemctl start nginx"

  # Check status
  run "sudo systemctl status nginx"
end

# Define backup task for database servers
task :backup_db, roles: :db do
  run "tar -czf /tmp/backup.tar.gz /var/lib/postgresql/data"
  run "aws s3 cp /tmp/backup.tar.gz s3://my-backups/"
  run "rm /tmp/backup.tar.gz"
end

# Define task for specific hosts
task :maintenance, on: %w[web01] do
  run "sudo systemctl stop nginx"
  run "sudo apt-get update && sudo apt-get upgrade -y"
  run "sudo systemctl start nginx"
end

# Define task for all hosts
task :update do
  run "sudo apt-get update && sudo apt-get upgrade -y"
end
