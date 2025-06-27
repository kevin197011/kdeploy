# frozen_string_literal: true

# Basic deployment example for Kdeploy
# This script demonstrates basic deployment patterns

# Configure pipeline name
pipeline 'Basic Web Application Deployment'

# Option 1: Define hosts directly (traditional approach)
# host '192.168.1.100', user: 'deploy', roles: %i[web app], vars: { nginx_port: 80 }
# host '192.168.1.101', user: 'deploy', roles: %i[web app], vars: { nginx_port: 80 }
# host '192.168.1.102', user: 'deploy', roles: [:db], vars: { db_port: 5432 }

# Option 2: Load hosts from inventory file (recommended)
inventory 'sample_inventory.yml'

# Set global variables
set :application, 'myapp'
set :deploy_to, '/opt/myapp'
set :repo_url, 'https://github.com/user/myapp.git'
set :branch, 'main'

# System preparation task
task 'system_setup', on: :production do
  run 'sudo apt-get update -y'
  run 'sudo apt-get install -y curl wget git build-essential'
  run 'curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -'
  run 'sudo apt-get install -y nodejs'
end

# Application deployment task
task 'deploy_app', on: :webservers do
  run 'sudo mkdir -p {{deploy_to}}'
  run 'sudo chown deploy:deploy {{deploy_to}}'
  run 'cd {{deploy_to}} && git clone {{repo_url}} . || git pull origin {{branch}}'
  run 'cd {{deploy_to}} && npm install --production'
  run 'cd {{deploy_to}} && npm run build'
end

# Web server configuration
task 'configure_nginx', on: :webservers do
  # Upload nginx configuration
  upload 'config/nginx.conf', '/tmp/myapp_nginx.conf'
  run 'sudo mv /tmp/myapp_nginx.conf /etc/nginx/sites-available/myapp'
  run 'sudo ln -sf /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled/'
  run 'sudo nginx -t'
  run 'sudo systemctl reload nginx'
end

# Database setup
task 'setup_database', on: :databases do
  run 'sudo systemctl status postgresql || sudo apt-get install -y postgresql postgresql-contrib'
  run 'sudo systemctl enable postgresql'
  run 'sudo systemctl start postgresql'
  run 'sudo -u postgres createdb myapp_production || echo "Database already exists"'
end

# Application services
task 'start_services', on: :webservers do
  # Create systemd service file
  upload 'config/myapp.service', '/tmp/myapp.service'
  run 'sudo mv /tmp/myapp.service /etc/systemd/system/'
  run 'sudo systemctl daemon-reload'
  run 'sudo systemctl enable myapp'
  run 'sudo systemctl restart myapp'
end

# Health check
task 'health_check', on: :webservers do
  run 'sleep 5' # Wait for service to start
  run 'curl -f http://localhost:3000/health || exit 1',
      name: 'app_health_check',
      timeout: 30,
      retry_count: 3
end

# Cleanup task
task 'cleanup', on: :production do
  run 'sudo apt-get autoremove -y'
  run 'sudo apt-get autoclean'
  run 'find {{deploy_to}}/node_modules -name \'.cache\' -type d -exec rm -rf {} + || true'
end

# Rollback task (for emergency use)
task 'rollback', on: :webservers do
  run 'cd {{deploy_to}} && git reset --hard HEAD~1'
  run 'cd {{deploy_to}} && npm install --production'
  run 'cd {{deploy_to}} && npm run build'
  run 'sudo systemctl restart {{application}}'
end
