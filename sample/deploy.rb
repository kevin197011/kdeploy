# frozen_string_literal: true

# Define hosts
# For Vagrant VMs, use 'vagrant' user and Vagrant's generated SSH keys
# Vagrant uses port forwarding: web01 -> 127.0.0.1:2200, web02 -> 127.0.0.1:2201
# The keys are created in .vagrant/machines/{vm_name}/virtualbox/private_key
# We use relative paths that will be resolved from the sample directory
host 'web01', user: 'vagrant', ip: '127.0.0.1', port: 2200,
              key: File.expand_path('.vagrant/machines/web01/virtualbox/private_key', __dir__), use_sudo: true
host 'web02', user: 'vagrant', ip: '127.0.0.1', port: 2201,
              key: File.expand_path('.vagrant/machines/web02/virtualbox/private_key', __dir__), use_sudo: true

# Define roles
role :web, %w[web01 web02]

# Install nginx on web servers
task :install_nginx, roles: :web do
  run <<~SHELL
    # Check if nginx is already installed
    if command -v nginx &> /dev/null; then
      echo "nginx is already installed"
      nginx -v
    else
      # Update package list
      sudo apt-get update

      # Install nginx
      sudo apt-get install -y nginx

      # Start and enable nginx
      sudo systemctl start nginx
      sudo systemctl enable nginx

      echo "nginx installed successfully"
    fi
  SHELL
end

# Configure nginx
task :configure_nginx, roles: :web do
  # Backup existing config
  run 'sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup || true'

  # Upload main nginx configuration template
  upload_template './config/nginx.conf.erb', '/etc/nginx/nginx.conf',
                  domain_name: 'example.com',
                  port: 3000,
                  worker_processes: 4,
                  worker_connections: 2048

  # Upload app configuration
  run 'sudo mkdir -p /etc/nginx/conf.d'
  upload './config/app.conf', '/etc/nginx/conf.d/app.conf'

  # Test nginx configuration
  run 'sudo nginx -t'

  # Reload nginx
  run 'sudo systemctl reload nginx'
end

# Deploy web application (includes install and configure)
task :deploy_web, roles: :web do
  # Install nginx if not installed
  run <<~SHELL
    if ! command -v nginx &> /dev/null; then
      sudo apt-get update
      sudo apt-get install -y nginx
      sudo systemctl start nginx
      sudo systemctl enable nginx
    fi
  SHELL

  # Stop nginx for configuration
  run 'sudo systemctl stop nginx || true'

  # Upload configurations
  run 'sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup || true'

  upload_template './config/nginx.conf.erb', '/etc/nginx/nginx.conf',
                  domain_name: 'example.com',
                  port: 3000,
                  worker_processes: 4,
                  worker_connections: 2048

  run 'sudo mkdir -p /etc/nginx/conf.d'
  upload './config/app.conf', '/etc/nginx/conf.d/app.conf'

  # Test and start nginx
  run <<~SHELL
    sudo nginx -t
    sudo systemctl start nginx
    sudo systemctl status nginx --no-pager
  SHELL
end

# Start nginx service
task :start_nginx, roles: :web do
  run 'sudo systemctl start nginx'
  run 'sudo systemctl status nginx --no-pager'
end

# Stop nginx service
task :stop_nginx, roles: :web do
  run 'sudo systemctl stop nginx'
  run "echo 'nginx stopped'"
end

# Restart nginx service
task :restart_nginx, roles: :web do
  run 'sudo systemctl restart nginx'
  run 'sleep 2'
  run 'sudo systemctl status nginx --no-pager'
end

# Check nginx status
task :status_nginx, roles: :web do
  run <<~SHELL
    echo "=== Nginx Service Status ==="
    sudo systemctl status nginx --no-pager || true
    echo ""
    echo "=== Nginx Process ==="
    ps aux | grep nginx | grep -v grep || echo "No nginx process found"
    echo ""
    echo "=== Nginx Port Check ==="
    netstat -tlnp 2>/dev/null | grep 80 || ss -tlnp 2>/dev/null | grep 80 || echo "Port 80 not listening"
  SHELL
end

# Maintenance task for specific host
task :maintenance, on: %w[web01] do
  run <<~SHELL
    sudo systemctl stop nginx || true
    sudo apt-get update && sudo apt-get upgrade -y
    sudo systemctl start nginx
  SHELL
end

# Update system packages
task :update, roles: :web do
  run 'sudo apt-get update && sudo apt-get upgrade -y'
end
