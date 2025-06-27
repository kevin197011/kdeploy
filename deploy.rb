# frozen_string_literal: true

# Simple kdeploy test deployment script

# Set global variables
set 'application', 'myapp'
set 'hostname', 'localhost'

# Test local commands (these work without SSH)
local 'echo "=== Starting kdeploy deployment process ==="'
local 'echo "Current user: $(whoami)"'
local 'echo "Current date: $(date)"'

# For demonstration with output, let's create a mock host that would show the process
# In practice, you'd use real hosts here

# Uncomment the lines below to test with mock/real SSH hosts:
# host 'localhost', user: ENV.fetch('USER', nil), port: 22, roles: [:test]
#
# task 'test_deployment', on: :test do
#   run 'echo "Testing kdeploy deployment on {{hostname}}..."'
#   run 'echo "Deploying application to {{hostname}}..."'
#
#   run <<~EOS
#     echo "Running system checks..."
#     uptime
#     echo "Listing temp files:"
#     ls /tmp | head -5
#   EOS
# end

# For now, demonstrate with local commands that show the heredoc functionality
task 'preparation_task' do
  local <<~SCRIPT
    echo "=== Preparation Phase ==="
    echo "Deploying application: myapp"
    echo "Target environment: localhost"
    echo "Preparation completed!"
  SCRIPT
end
