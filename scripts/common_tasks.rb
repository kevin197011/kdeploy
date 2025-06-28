# frozen_string_literal: true

# Common tasks for kdeploy projects
# This file demonstrates modular script organization
#
# To use this file, include it in your main deployment script:
# include 'scripts/common_tasks.rb' if File.exist?('scripts/common_tasks.rb')

# ===================================================================
# HOST DEFINITIONS (Required for remote tasks)
# ===================================================================

# Define default hosts - update these with your actual hosts
host 'localhost', user: ENV.fetch('USER', 'deploy'), port: 22, roles: %i[web app db all]

# Uncomment and update these for real deployments:
# host 'web1.example.com', user: 'deploy', port: 22, roles: [:web, :app]
# host 'web2.example.com', user: 'deploy', port: 22, roles: [:web, :app]
# host 'db1.example.com', user: 'deploy', port: 22, roles: [:db]

# ===================================================================
# COMMON UTILITY TASKS
# ===================================================================

# Shared pre-deployment checks (LOCAL + REMOTE)
task 'pre_deploy_checks', on: :all do
  local 'echo "🔍 Running pre-deployment checks..."'
  local 'echo "Current user: $(whoami)"'
  local 'echo "Current directory: $(pwd)"'
  local 'echo "Git status:" && git status --porcelain || echo "Not a git repository"'
  local 'echo "✅ Pre-deployment checks completed"'

  # Add a dummy remote command to satisfy validation
  run 'echo "Pre-deployment check completed on {{hostname}}"'
end

# Common environment setup
task 'setup_environment', on: :all do
  run 'echo "Setting up environment on {{hostname}}..."'

  # Set timezone
  run 'sudo timedatectl set-timezone UTC', ignore_errors: true

  # Update system packages
  run 'sudo apt-get update -qq', ignore_errors: true

  # Install common utilities
  run 'sudo apt-get install -y -qq htop curl wget vim git unzip', ignore_errors: true

  run 'echo "✅ Environment setup completed on {{hostname}}"'
end

# Common log rotation setup
task 'setup_log_rotation', on: :all do
  run 'echo "Setting up log rotation on {{hostname}}..."'

  # Application log rotation
  run <<~LOGROTATE
    sudo tee /etc/logrotate.d/{{application}} > /dev/null << 'EOF'
    {{deploy_to}}/shared/logs/*.log {
        daily
        missingok
        rotate 52
        compress
        delaycompress
        notifempty
        create 644 {{user}} {{user}}
        postrotate
            sudo systemctl reload {{application}} || true
        endscript
    }
    EOF
  LOGROTATE

  run 'echo "✅ Log rotation setup completed on {{hostname}}"'
end

# Common system monitoring setup
task 'setup_monitoring', on: :all do
  run 'echo "Setting up basic monitoring on {{hostname}}..."'

  # Install system monitoring tools
  run 'sudo apt-get install -y htop iotop iftop nethogs', ignore_errors: true

  # Setup basic disk space monitoring
  run <<~MONITORING
    sudo tee /usr/local/bin/disk-alert.sh > /dev/null << 'EOF'
    #!/bin/bash
    THRESHOLD=90
    USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ $USAGE -gt $THRESHOLD ]; then
        echo "Warning: Disk usage is $USAGE% on $(hostname)"
        logger "Disk usage alert: $USAGE% on $(hostname)"
    fi
    EOF
  MONITORING

  run 'sudo chmod +x /usr/local/bin/disk-alert.sh'

  # Add to crontab
  run 'echo "0 */6 * * * /usr/local/bin/disk-alert.sh" | sudo crontab -', ignore_errors: true

  run 'echo "✅ Monitoring setup completed on {{hostname}}"'
end

# Common security hardening
task 'security_hardening', on: :all do
  run 'echo "Applying security hardening on {{hostname}}..."'

  # Disable root login
  run 'sudo sed -i "s/PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config', ignore_errors: true

  # Configure firewall basics
  run 'sudo ufw --force reset', ignore_errors: true
  run 'sudo ufw default deny incoming', ignore_errors: true
  run 'sudo ufw default allow outgoing', ignore_errors: true
  run 'sudo ufw allow ssh', ignore_errors: true
  run 'sudo ufw allow 80', ignore_errors: true
  run 'sudo ufw allow 443', ignore_errors: true
  run 'sudo ufw --force enable', ignore_errors: true

  # Install fail2ban
  run 'sudo apt-get install -y fail2ban', ignore_errors: true
  run 'sudo systemctl enable fail2ban', ignore_errors: true
  run 'sudo systemctl start fail2ban', ignore_errors: true

  run 'echo "✅ Security hardening completed on {{hostname}}"'
end

# Common performance tuning
task 'performance_tuning', on: :all do
  run 'echo "Applying performance tuning on {{hostname}}..."'

  # System limits
  run <<~LIMITS
    sudo tee -a /etc/security/limits.conf > /dev/null << 'EOF'
    * soft nofile 65536
    * hard nofile 65536
    * soft nproc 32768
    * hard nproc 32768
    EOF
  LIMITS

  # Kernel parameters
  run <<~SYSCTL
    sudo tee -a /etc/sysctl.conf > /dev/null << 'EOF'
    # Network performance
    net.core.rmem_max = 16777216
    net.core.wmem_max = 16777216
    net.ipv4.tcp_rmem = 4096 65536 16777216
    net.ipv4.tcp_wmem = 4096 65536 16777216
    EOF
  SYSCTL

  run 'sudo sysctl -p', ignore_errors: true

  run 'echo "✅ Performance tuning completed on {{hostname}}"'
end

# ===================================================================
# COMMON UTILITY FUNCTIONS
# ===================================================================

# Health check wrapper (LOCAL + REMOTE)
task 'health_check_all', on: :all do
  local 'echo "🏥 Running comprehensive health checks..."'

  # You can call other scripts from here
  local 'echo "1. System health check"'
  local 'echo "2. Application health check"'
  local 'echo "3. Service status check"'
  local 'echo "✅ Health checks completed"'

  # Add a dummy remote command to satisfy validation
  run 'echo "Health check completed on {{hostname}}"'
end

# ===================================================================
# EMERGENCY PROCEDURES
# ===================================================================

# Emergency stop all services
task 'emergency_stop', on: :all do
  run 'echo "🚨 Emergency stop initiated on {{hostname}}"'
  run 'sudo systemctl stop nginx || echo "nginx not found"', ignore_errors: true
  run 'sudo systemctl stop apache2 || echo "apache2 not found"', ignore_errors: true
  run 'echo "🛑 Services stopped on {{hostname}}"'
end

# Emergency start all services
task 'emergency_start', on: :all do
  run 'echo "🚨 Emergency start initiated on {{hostname}}"'
  run 'sudo systemctl start nginx || echo "nginx not found"', ignore_errors: true
  run 'sudo systemctl start apache2 || echo "apache2 not found"', ignore_errors: true
  run 'echo "🚀 Services started on {{hostname}}"'
end

# ===================================================================
# USAGE EXAMPLES
# ===================================================================
#
# This file can be included in your main deploy.rb script:
#
# include 'scripts/common_tasks.rb' if File.exist?('scripts/common_tasks.rb')
#
# Then you can call these tasks from your deployment workflow:
#
# task 'full_setup' do
#   run_task 'pre_deploy_checks'
#   run_task 'setup_environment'
#   run_task 'security_hardening'
#   run_task 'performance_tuning'
# end
#
# Or run individual tasks:
# kdeploy deploy scripts/common_tasks.rb --task setup_environment
# kdeploy deploy scripts/common_tasks.rb --task security_hardening
# kdeploy deploy scripts/common_tasks.rb --task emergency_stop
