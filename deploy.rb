# frozen_string_literal: true

# Simple kdeploy test deployment script

# Define test host
host 'localhost', user: ENV.fetch('USER', nil), port: 22, roles: [:test]

# Test deployment task
task 'test_deployment', on: :test do
  run 'echo "Testing kdeploy deployment on $(hostname)"'
  run 'echo "Current user: $(whoami)"'
  run 'echo "Current date: $(date)"'
  run 'echo "System info: $(uname -a)"'
end
