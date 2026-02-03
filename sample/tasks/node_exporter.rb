# frozen_string_literal: true

# ============================================================================
# Node Exporter Deployment Tasks (Chef-style resource DSL)
# ============================================================================

# Install node-exporter (download from GitHub, extract to /usr/local/bin)
task :install_node_exporter do
  run <<~SHELL
    useradd --no-create-home --shell /bin/false node-exporter 2>/dev/null || true
    VERSION="1.7.0"
    URL="https://github.com/prometheus/node_exporter/releases/download/v${VERSION}/node_exporter-${VERSION}.linux-amd64.tar.gz"
    cd /tmp
    (command -v wget >/dev/null && wget -q "${URL}" -O node_exporter.tar.gz) || \
      (command -v curl >/dev/null && curl -sSL "${URL}" -o node_exporter.tar.gz) || \
      { echo "wget or curl required"; exit 1; }
    tar -xzf node_exporter.tar.gz
    cp node_exporter-${VERSION}.linux-amd64/node_exporter /usr/local/bin/
    chown node-exporter:node-exporter /usr/local/bin/node_exporter
    chmod +x /usr/local/bin/node_exporter
    rm -rf node_exporter.tar.gz node_exporter-${VERSION}.linux-amd64
  SHELL
end

# Configure node-exporter systemd service
task :configure_node_exporter do
  template '/etc/systemd/system/node-exporter.service',
           source: './config/node_exporter.service.erb'
  run 'systemctl daemon-reload', sudo: true
  service 'node-exporter', action: :enable
end

# Deploy node-exporter (install + configure + start)
task :deploy_node_exporter do
  run <<~SHELL
    useradd --no-create-home --shell /bin/false node-exporter 2>/dev/null || true
    VERSION="1.7.0"
    URL="https://github.com/prometheus/node_exporter/releases/download/v${VERSION}/node_exporter-${VERSION}.linux-amd64.tar.gz"
    cd /tmp
    (command -v wget >/dev/null && wget -q "${URL}" -O node_exporter.tar.gz) || \
      (command -v curl >/dev/null && curl -sSL "${URL}" -o node_exporter.tar.gz) || \
      { echo "wget or curl required"; exit 1; }
    tar -xzf node_exporter.tar.gz
    cp node_exporter-${VERSION}.linux-amd64/node_exporter /usr/local/bin/
    chown node-exporter:node-exporter /usr/local/bin/node_exporter
    chmod +x /usr/local/bin/node_exporter
    rm -rf node_exporter.tar.gz node_exporter-${VERSION}.linux-amd64
  SHELL

  template '/etc/systemd/system/node-exporter.service',
           source: './config/node_exporter.service.erb'
  run 'systemctl daemon-reload', sudo: true
  service 'node-exporter', action: %i[enable start]
  run 'sleep 2'
  run 'systemctl status node-exporter --no-pager || true', sudo: true
end

# Start node-exporter service
task :start_node_exporter do
  service 'node-exporter', action: :start
end

# Stop node-exporter service
task :stop_node_exporter do
  service 'node-exporter', action: :stop
end

# Restart node-exporter service
task :restart_node_exporter do
  service 'node-exporter', action: :restart
  run 'sleep 2'
  run 'systemctl status node-exporter --no-pager || true', sudo: true
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
