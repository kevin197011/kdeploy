# frozen_string_literal: true

# Complete kdeploy test deployment script demonstrating output features

# Set global variables for template substitution
set 'application', 'myapp'
set 'environment', 'production'
set 'version', '1.0.0'

# Test local commands with output display
local 'echo "🚀 Starting deployment of {{application}} v{{version}}"'
local 'echo "Environment: {{environment}}"'

# Multi-line local command (heredoc)
local <<~PREPARATION
  echo "=== Pre-deployment Checks ==="
  echo "Current user: $(whoami)"
  echo "Current date: $(date)"
  echo "System uptime:"
  uptime
  echo "Disk usage:"
  df -h | head -5
  echo "=== Preparation completed ==="
PREPARATION

# Define a test host (you can uncomment this for actual SSH testing)
# Note: Requires SSH server running on localhost
# host 'localhost', user: ENV.fetch('USER', nil), port: 22, roles: [:app]

# Simulate remote deployment with local execution
# (This demonstrates what would happen with real SSH hosts)
task 'simulate_deployment' do
  local 'echo "📦 Deploying {{application}} version {{version}} to {{environment}}"'

  # Simulate checking deployment status
  local <<~DEPLOYMENT_CHECK
    echo "🔍 Checking deployment status..."
    echo "Application: {{application}}"
    echo "Version: {{version}}"
    echo "Environment: {{environment}}"
    echo "✅ Deployment simulation completed!"
  DEPLOYMENT_CHECK
end

# Show final status
local 'echo "🎉 Deployment process completed successfully!"'
