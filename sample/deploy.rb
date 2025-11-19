# frozen_string_literal: true

# Define hosts
# For Vagrant VMs, use 'vagrant' user and Vagrant's generated SSH keys
# Vagrant uses port forwarding: web01 -> 127.0.0.1:2200, web02 -> 127.0.0.1:2201
# The keys are created in .vagrant/machines/{vm_name}/virtualbox/private_key
# We use relative paths that will be resolved from the sample directory
host 'web01', user: 'vagrant', ip: '127.0.0.1', port: 2200,
              key: File.expand_path('.vagrant/machines/web01/virtualbox/private_key', __dir__), use_sudo: true

# Define roles
role :web, %w[web01]

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

# ============================================================================
# Node Exporter Deployment Tasks
# ============================================================================

# Install node-exporter
task :install_node_exporter, roles: :web do
  run <<~SHELL
    # Check if node-exporter is already installed
    if systemctl is-active --quiet node-exporter 2>/dev/null; then
      echo "node-exporter is already installed and running"
      node-exporter --version 2>/dev/null || echo "node-exporter service is running"
    else
      # Create node-exporter user
      sudo useradd --no-create-home --shell /bin/false node-exporter || true

      # Download node-exporter (latest version)
      NODE_EXPORTER_VERSION="1.7.0"
      NODE_EXPORTER_URL="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
      DOWNLOAD_DIR="/tmp"
      INSTALL_DIR="/usr/local/bin"

      echo "Downloading node-exporter ${NODE_EXPORTER_VERSION}..."
      cd ${DOWNLOAD_DIR}
      # Try wget first, then curl, ensure one is available
      if command -v wget >/dev/null 2>&1; then
        sudo wget -q ${NODE_EXPORTER_URL} -O node_exporter.tar.gz
      elif command -v curl >/dev/null 2>&1; then
        sudo curl -L ${NODE_EXPORTER_URL} -o node_exporter.tar.gz
      else
        echo "Error: wget or curl is required to download node-exporter"
        exit 1
      fi

      # Extract and install
      echo "Extracting node-exporter..."
      sudo tar -xzf node_exporter.tar.gz
      sudo cp node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter ${INSTALL_DIR}/
      sudo chown node-exporter:node-exporter ${INSTALL_DIR}/node_exporter
      sudo chmod +x ${INSTALL_DIR}/node_exporter

      # Cleanup
      sudo rm -rf node_exporter.tar.gz node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64

      echo "node-exporter installed successfully"
    fi
  SHELL
end

# Configure node-exporter systemd service
task :configure_node_exporter, roles: :web do
  run <<~SHELL
            # Create systemd service file
            sudo tee /etc/systemd/system/node-exporter.service > /dev/null <<EOF
      [Unit]
      Description=Node Exporter
      After=network.target

      [Service]
      User=node-exporter
      Group=node-exporter
      Type=simple
      ExecStart=/usr/local/bin/node_exporter
      Restart=always
      RestartSec=5

      [Install]
      WantedBy=multi-user.target
    EOF

            # Reload systemd and enable service
            sudo systemctl daemon-reload
            sudo systemctl enable node-exporter

            echo "node-exporter service configured"
  SHELL
end

# Deploy node-exporter (install + configure + start)
task :deploy_node_exporter, roles: :web do
  # Install node-exporter
  run <<~SHELL
    # Create node-exporter user
    sudo useradd --no-create-home --shell /bin/false node-exporter || true

    # Download node-exporter (latest version)
    NODE_EXPORTER_VERSION="1.7.0"
    NODE_EXPORTER_URL="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
    DOWNLOAD_DIR="/tmp"
    INSTALL_DIR="/usr/local/bin"

    echo "Downloading node-exporter ${NODE_EXPORTER_VERSION}..."
    cd ${DOWNLOAD_DIR}
    # Try wget first, then curl, ensure one is available
    if command -v wget >/dev/null 2>&1; then
      sudo wget -q ${NODE_EXPORTER_URL} -O node_exporter.tar.gz
    elif command -v curl >/dev/null 2>&1; then
      sudo curl -L ${NODE_EXPORTER_URL} -o node_exporter.tar.gz
    else
      echo "Error: wget or curl is required to download node-exporter"
      exit 1
    fi

    # Extract and install
    echo "Extracting node-exporter..."
    sudo tar -xzf node_exporter.tar.gz
    sudo cp node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter ${INSTALL_DIR}/
    sudo chown node-exporter:node-exporter ${INSTALL_DIR}/node_exporter
    sudo chmod +x ${INSTALL_DIR}/node_exporter

    # Cleanup
    sudo rm -rf node_exporter.tar.gz node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64
  SHELL

  # Configure systemd service
  run <<~SHELL
            # Create systemd service file
            sudo tee /etc/systemd/system/node-exporter.service > /dev/null <<EOF
      [Unit]
      Description=Node Exporter
      After=network.target

      [Service]
      User=node-exporter
      Group=node-exporter
      Type=simple
      ExecStart=/usr/local/bin/node_exporter
      Restart=always
      RestartSec=5

      [Install]
      WantedBy=multi-user.target
    EOF

            # Reload systemd and enable service
            sudo systemctl daemon-reload
            sudo systemctl enable node-exporter
  SHELL

  # Start service
  run <<~SHELL
    sudo systemctl start node-exporter
    sleep 2
    sudo systemctl status node-exporter --no-pager
  SHELL
end

# Start node-exporter service
task :start_node_exporter, roles: :web do
  run 'sudo systemctl start node-exporter'
  run 'sudo systemctl status node-exporter --no-pager'
end

# Stop node-exporter service
task :stop_node_exporter, roles: :web do
  run 'sudo systemctl stop node-exporter'
  run "echo 'node-exporter stopped'"
end

# Restart node-exporter service
task :restart_node_exporter, roles: :web do
  run 'sudo systemctl restart node-exporter'
  run 'sleep 2'
  run 'sudo systemctl status node-exporter --no-pager'
end

# Check node-exporter status
task :status_node_exporter, roles: :web do
  run <<~SHELL
    echo "=== Node Exporter Service Status ==="
    sudo systemctl status node-exporter --no-pager || true
    echo ""
    echo "=== Node Exporter Process ==="
    ps aux | grep node_exporter | grep -v grep || echo "No node-exporter process found"
    echo ""
    echo "=== Node Exporter Port Check ==="
    netstat -tlnp 2>/dev/null | grep 9100 || ss -tlnp 2>/dev/null | grep 9100 || echo "Port 9100 not listening"
    echo ""
    echo "=== Test Node Exporter Endpoint ==="
    curl -s http://localhost:9100/metrics | head -5 || echo "Cannot connect to node-exporter"
  SHELL
end
