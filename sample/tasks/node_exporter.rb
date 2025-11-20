# frozen_string_literal: true

# ============================================================================
# Node Exporter Deployment Tasks
# ============================================================================

# Install node-exporter
task :install_node_exporter do
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
task :configure_node_exporter do
  run <<~SHELL
        # Create systemd service file
        sudo tee /etc/systemd/system/node-exporter.service > /dev/null <<'SERVICE_EOF'
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
    SERVICE_EOF

        # Reload systemd and enable service
        sudo systemctl daemon-reload
        sudo systemctl enable node-exporter

        echo "node-exporter service configured"
  SHELL
end

# Deploy node-exporter (install + configure + start)
task :deploy_node_exporter do
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
        sudo tee /etc/systemd/system/node-exporter.service > /dev/null <<'SERVICE_EOF'
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
    SERVICE_EOF

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
task :start_node_exporter do
  run 'sudo systemctl start node-exporter'
  run 'sudo systemctl status node-exporter --no-pager'
end

# Stop node-exporter service
task :stop_node_exporter do
  run 'sudo systemctl stop node-exporter'
  run "echo 'node-exporter stopped'"
end

# Restart node-exporter service
task :restart_node_exporter do
  run 'sudo systemctl restart node-exporter'
  run 'sleep 2'
  run 'sudo systemctl status node-exporter --no-pager'
end

# Check node-exporter status
task :status_node_exporter do
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
