# frozen_string_literal: true

# ============================================================================
# Host and Role Definitions
# ============================================================================
# For Vagrant VMs, use 'vagrant' user and Vagrant's generated SSH keys
# Vagrant uses port forwarding: web01 -> 127.0.0.1:2200, web02 -> 127.0.0.1:2201
# The keys are created in .vagrant/machines/{vm_name}/virtualbox/private_key
# We use relative paths that will be resolved from the sample directory
host 'web01', user: 'vagrant', ip: '127.0.0.1', port: 2200,
              key: File.expand_path('.vagrant/machines/web01/virtualbox/private_key', __dir__), use_sudo: true

# Define roles
role :web, %w[web01]

# ============================================================================
# Task Files Inclusion
# ============================================================================
# Include task files and automatically assign all tasks to roles
# You can comment out any task file to exclude it from execution

# Nginx deployment tasks - all tasks assigned to :web role
include_tasks 'tasks/nginx.rb', roles: :web

# Node Exporter deployment tasks - all tasks assigned to :web role
include_tasks 'tasks/node_exporter.rb', roles: :web

# System maintenance tasks - all tasks assigned to :web role
include_tasks 'tasks/system.rb', roles: :web
# NOTE: maintenance task in system.rb already has 'on: %w[web01]' defined, which takes precedence

# Directory synchronization tasks - all tasks assigned to :web role
include_tasks 'tasks/sync.rb', roles: :web
