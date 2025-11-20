# frozen_string_literal: true

# ============================================================================
# Nginx Deployment Tasks
# ============================================================================

# Install nginx on web servers
task :install_nginx do
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
task :configure_nginx do
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
task :deploy_web do
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
task :start_nginx do
  run 'sudo systemctl start nginx'
  run 'sudo systemctl status nginx --no-pager'
end

# Stop nginx service
task :stop_nginx do
  run 'sudo systemctl stop nginx'
  run "echo 'nginx stopped'"
end

# Restart nginx service
task :restart_nginx do
  run 'sudo systemctl restart nginx'
  run 'sleep 2'
  run 'sudo systemctl status nginx --no-pager'
end

# Check nginx status
task :status_nginx do
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
