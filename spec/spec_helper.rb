# frozen_string_literal: true

require 'bundler/setup'
require 'kdeploy'
require 'rspec'
# require 'simplecov'

# # Start SimpleCov
# SimpleCov.start do
#   add_filter '/spec/'
#   add_filter '/vendor/'
#
#   add_group 'Core', 'lib/kdeploy.rb'
#   add_group 'Configuration', 'lib/kdeploy/configuration.rb'
#   add_group 'Connection', %w[lib/kdeploy/ssh_connection.rb lib/kdeploy/host.rb]
#   add_group 'Execution', %w[lib/kdeploy/command.rb lib/kdeploy/task.rb lib/kdeploy/pipeline.rb]
#   add_group 'DSL', 'lib/kdeploy/dsl.rb'
#   add_group 'Runner', 'lib/kdeploy/runner.rb'
#   add_group 'CLI', 'lib/kdeploy/cli.rb'
#
#   minimum_coverage 80
# end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on Module and main
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Filter out third-party code
  config.filter_run_when_matching :focus

  # Run specs in random order to surface order dependencies
  config.order = :random
  Kernel.srand config.seed

  # Clean up configuration after each test
  config.after do
    Kdeploy.configuration = nil
  end

  # Shared examples and helpers
  config.shared_context_metadata_behavior = :apply_to_host_groups
end

# Helper method to create test host
def create_test_host(hostname = 'test.example.com', **options)
  defaults = {
    user: 'testuser',
    port: 22,
    roles: [:test],
    vars: {}
  }

  Kdeploy::Host.new(hostname, **defaults, **options)
end

# Helper method to create test pipeline
def create_test_pipeline(name = 'test')
  Kdeploy::Pipeline.new(name)
end

# Mock SSH connection for testing
class MockSSHConnection
  attr_reader :host, :connected

  def initialize(host)
    @host = host
    @connected = false
  end

  def connect
    @connected = true
  end

  def connected?
    @connected
  end

  def execute(command, timeout: nil)
    {
      stdout: "Mock output for: #{command}",
      stderr: '',
      exit_code: 0,
      success: true
    }
  end

  def upload(_local_path, _remote_path)
    true
  end

  def download(_remote_path, _local_path)
    true
  end

  def disconnect
    @connected = false
  end

  def cleanup
    disconnect
  end
end
