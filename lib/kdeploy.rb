# frozen_string_literal: true

# External dependencies
require 'concurrent-ruby'
require 'net/ssh'
require 'net/scp'
require 'yaml'
require 'logger'
require 'colorize'
require 'thor'
require 'tty-prompt'
require 'erb'
require 'fileutils'
require 'json'

# Internal dependencies - ordered by dependency chain
module Kdeploy
  # Load all components
  autoload :VERSION,        'kdeploy/version'
  autoload :Configuration,  'kdeploy/configuration'
  autoload :Logger,         'kdeploy/logger'
  autoload :Host, 'kdeploy/host'
  autoload :Inventory,      'kdeploy/inventory'
  autoload :Template,       'kdeploy/template'
  autoload :SSHConnection,  'kdeploy/ssh_connection'
  autoload :Command,        'kdeploy/command'
  autoload :Task, 'kdeploy/task'
  autoload :Pipeline, 'kdeploy/pipeline'
  autoload :DSL,           'kdeploy/dsl'
  autoload :Runner,        'kdeploy/runner'
  autoload :Statistics, 'kdeploy/statistics'
  autoload :Banner,        'kdeploy/banner'
  autoload :CLI,           'kdeploy/cli'

  # Base error class for Kdeploy
  class Error < StandardError; end

  # Error raised when connection fails
  class ConnectionError < Error; end

  # Error raised when command execution fails
  class CommandError < Error; end

  # Error raised when configuration is invalid
  class ConfigurationError < Error; end

  class << self
    attr_accessor :configuration
    attr_reader :statistics

    # Initialize statistics
    # @return [Statistics] Statistics instance
    def statistics
      @statistics ||= Statistics.new
    end

    # Configure kdeploy
    # @yield [Configuration] Configuration instance
    # @return [Configuration] Configuration instance
    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
      configuration
    end

    # Load and execute deployment script
    # @param script_file [String] Path to deployment script
    # @return [Pipeline] Loaded pipeline
    # @raise [ConfigurationError] If script file not found
    def load_script(script_file)
      validate_script_file(script_file)
      script_dir = File.dirname(File.expand_path(script_file))
      create_pipeline(script_file, script_dir)
    end

    # Execute deployment pipeline
    # @param pipeline [Pipeline] Pipeline to execute
    # @return [Hash] Execution results
    def execute(pipeline)
      runner = Runner.new(pipeline)
      runner.execute
    end

    # Convenient method to load and execute script
    # @param script_file [String] Path to deployment script
    # @return [Hash] Execution results
    def run(script_file)
      pipeline = load_script(script_file)
      execute(pipeline)
    end

    private

    def validate_script_file(script_file)
      return if File.exist?(script_file)

      raise ConfigurationError, "Script file not found: #{script_file}"
    end

    def create_pipeline(script_file, script_dir)
      dsl = DSL.new(script_dir)
      dsl.instance_eval(File.read(script_file), script_file)
      dsl.pipeline
    end
  end
end
