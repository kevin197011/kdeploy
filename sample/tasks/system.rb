# frozen_string_literal: true

# ============================================================================
# System Maintenance Tasks
# ============================================================================

# Maintenance task for specific host
task :maintenance, on: %w[web01] do
  run <<~SHELL
    sudo systemctl stop nginx || true
    sudo apt-get update && sudo apt-get upgrade -y
    sudo systemctl start nginx
  SHELL
end

# Update system packages
task :update do
  run 'sudo apt-get update && sudo apt-get upgrade -y'
end
