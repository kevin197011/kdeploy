# frozen_string_literal: true

require 'yaml'

module Kdeploy
  # Configuration management for Kdeploy
  class Configuration
    DEFAULT_PARALLEL = 10
    DEFAULT_SSH_TIMEOUT = 30
    DEFAULT_VERIFY_HOST_KEY = :never
    DEFAULT_RETRIES = 0
    DEFAULT_RETRY_DELAY = 1
    CONFIG_FILE_NAME = '.kdeploy.yml'

    class << self
      attr_accessor :default_parallel,
                    :default_ssh_timeout,
                    :default_verify_host_key,
                    :default_retries,
                    :default_retry_delay

      def reset
        @default_parallel = DEFAULT_PARALLEL
        @default_ssh_timeout = DEFAULT_SSH_TIMEOUT
        @default_verify_host_key = DEFAULT_VERIFY_HOST_KEY
        @default_retries = DEFAULT_RETRIES
        @default_retry_delay = DEFAULT_RETRY_DELAY
      end

      def load_from_file(config_path = nil)
        config_path ||= find_config_file
        return unless config_path && File.exist?(config_path)

        config = YAML.safe_load_file(config_path, permitted_classes: [Symbol])
        apply_config(config)
      rescue StandardError => e
        warn "Warning: Failed to load config from #{config_path}: #{e.message}"
        nil
      end

      def find_config_file(start_dir = Dir.pwd)
        current_dir = File.expand_path(start_dir)

        loop do
          config_file = File.join(current_dir, CONFIG_FILE_NAME)
          return config_file if File.exist?(config_file)

          parent_dir = File.dirname(current_dir)
          break if parent_dir == current_dir

          current_dir = parent_dir
        end

        nil
      end

      private

      def apply_config(config)
        return unless config.is_a?(Hash)

        @default_parallel = config['parallel'] if config.key?('parallel')
        @default_ssh_timeout = config['ssh_timeout'] if config.key?('ssh_timeout')
        @default_verify_host_key = parse_verify_host_key(config['verify_host_key']) if config.key?('verify_host_key')
        @default_retries = config['retries'] if config.key?('retries')
        @default_retry_delay = config['retry_delay'] if config.key?('retry_delay')
      end

      def parse_verify_host_key(value)
        case value
        when true, 'true', 'yes', 'always'
          :always
        when false, 'false', 'no', 'never'
          :never
        when 'accept_new', 'accept-new'
          :accept_new
        else
          value.to_sym if value.respond_to?(:to_sym)
        end
      end
    end

    # Initialize with defaults
    reset
  end
end
