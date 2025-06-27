# frozen_string_literal: true

# Inventory-based deployment example for Kdeploy
# This script demonstrates how to use inventory.yml for host management

# Configure pipeline name
pipeline 'Inventory-based Web Application Deployment'

# Load hosts from inventory file
inventory 'sample_inventory.yml'

# System preparation for all production servers
task 'system_prep', on: :production do
  run 'sudo apt-get update -y'
  run 'sudo apt-get install -y curl wget git'
  run 'echo "Prepared system on {{hostname}} (server_id: {{server_id}})"'
end

# Deploy application to web servers group
task 'deploy_app', on: :webservers do
  run 'echo "Deploying {{application}} to {{hostname}}..."'
  run 'sudo mkdir -p {{deploy_to}}'
  run 'sudo chown {{user}}:{{user}} {{deploy_to}}'
  run 'cd {{deploy_to}} && git clone https://github.com/user/{{application}}.git . || git pull origin main'
  run 'cd {{deploy_to}} && npm install --production'
  run 'cd {{deploy_to}} && npm run build'
end

# Configure nginx on web servers
task 'configure_web', on: :webservers do
  run 'sudo systemctl status nginx || sudo apt-get install -y nginx'
  run 'echo "Configuring nginx on port {{nginx_port}}"'
  run 'sudo systemctl enable nginx'
  run 'sudo systemctl start nginx'
end

# Setup database on database servers
task 'setup_database', on: :databases do
  run 'sudo systemctl status postgresql || sudo apt-get install -y postgresql postgresql-contrib'
  run 'echo "Setting up database on port {{postgres_port}}"'
  run 'sudo systemctl enable postgresql'
  run 'sudo systemctl start postgresql'
  run 'sudo -u postgres createdb {{application}}_{{environment}} || echo "Database exists"'
end

# Start application services on web servers
task 'start_services', on: :webservers do
  run 'echo "Starting {{application}} service on {{hostname}}:{{app_port}}"'
  run 'cd {{deploy_to}} && npm start &'
  run 'sleep 3'
end

# Health check for web servers
task 'health_check', on: :webservers do
  run 'curl -f http://localhost:{{app_port}}/health || exit 1',
      name: 'app_health_check',
      timeout: 30,
      retry_count: 3
end

# Database backup (only on master database)
task 'backup_database', on: :databases do
  run 'test "{{master}}" = "true" && pg_dump {{application}}_{{environment}} > /tmp/backup_$(date +%Y%m%d).sql || echo "Skipping backup on slave"',
      name: 'database_backup'
end

# Check disk space on all servers
task 'check_disk', on: :production do
  run 'df -h | grep -E "(Filesystem|/dev/)"',
      name: 'disk_check'
end

# Conditional task based on environment
if ENV['BACKUP_ENABLED'] == 'true'
  task 'automated_backup', on: :databases do
    run 'echo "Running automated backup..."'
    run 'pg_dump {{application}}_{{environment}} | gzip > /backup/{{application}}_$(date +%Y%m%d_%H%M%S).sql.gz'
  end
end
