# frozen_string_literal: true

require 'concurrent-ruby'
require 'net/ssh'
require 'net/scp'
require 'yaml'
require 'logger'
require 'colorize'

require_relative 'kdeploy/version'
require_relative 'kdeploy/configuration'
require_relative 'kdeploy/logger'
require_relative 'kdeploy/host'
require_relative 'kdeploy/inventory'
require_relative 'kdeploy/template'
require_relative 'kdeploy/ssh_connection'
require_relative 'kdeploy/command'
require_relative 'kdeploy/task'
require_relative 'kdeploy/pipeline'
require_relative 'kdeploy/dsl'
require_relative 'kdeploy/runner'
require_relative 'kdeploy/statistics'
require_relative 'kdeploy/cli'

module Kdeploy
  class Error < StandardError; end
  class ConnectionError < Error; end
  class CommandError < Error; end
  class ConfigurationError < Error; end

  class << self
    attr_accessor :configuration
    attr_reader :statistics

    # Initialize statistics
    def statistics
      @statistics ||= Statistics.new
    end

    # Configure kdeploy
    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
      configuration
    end

    # Load and execute deployment script
    # @param script_file [String] Path to deployment script
    def load_script(script_file)
      raise ConfigurationError, "Script file not found: #{script_file}" unless File.exist?(script_file)

      script_dir = File.dirname(File.expand_path(script_file))
      dsl = DSL.new(script_dir)
      dsl.instance_eval(File.read(script_file), script_file)
      dsl.pipeline
    end

    # Execute deployment pipeline
    # @param pipeline [Pipeline] Pipeline to execute
    def execute(pipeline)
      runner = Runner.new(pipeline)
      runner.execute
    end

    # Convenient method to load and execute script
    # @param script_file [String] Path to deployment script
    def run(script_file)
      pipeline = load_script(script_file)
      execute(pipeline)
    end
  end
end
