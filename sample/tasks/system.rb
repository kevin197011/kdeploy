# frozen_string_literal: true

# ============================================================================
# System Maintenance Tasks (Chef-style resource DSL)
# ============================================================================

# Maintenance task for specific host
task :maintenance, on: %w[web01] do
  service 'nginx', action: :stop
  run 'apt-get update && apt-get upgrade -y', sudo: true
  service 'nginx', action: %i[start enable]
end

# Update system packages
task :update do
  run 'apt-get update && apt-get upgrade -y', sudo: true
end
