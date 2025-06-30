# frozen_string_literal: true

module Kdeploy
  # Configuration class for managing global settings
  class Configuration
    attr_accessor :max_concurrent_tasks, :ssh_timeout, :command_timeout,
                  :retry_count, :retry_delay, :log_level, :log_file,
                  :default_user, :default_port, :ssh_options, :inventory_file,
                  :template_dir

    def initialize
      set_default_values
    end

    # Load configuration from YAML file
    # @param config_file [String] Path to configuration file
    # @return [void]
    def load_from_file(config_file)
      return unless File.exist?(config_file)

      config = YAML.load_file(config_file)
      return unless config.is_a?(Hash)

      apply_configuration(config)
    end

    # Merge SSH options with defaults
    # @param options [Hash] SSH options to merge
    # @return [Hash] Merged SSH options
    def merged_ssh_options(options = {})
      ssh_options.merge(options)
    end

    private

    def set_default_values
      set_default_timeouts
      set_default_retry_settings
      set_default_logging
      set_default_ssh_settings
      set_default_paths
    end

    def set_default_timeouts
      @max_concurrent_tasks = 10
      @ssh_timeout = 30
      @command_timeout = 300
    end

    def set_default_retry_settings
      @retry_count = 3
      @retry_delay = 1
    end

    def set_default_logging
      @log_level = :info
      @log_file = nil
    end

    def set_default_ssh_settings
      @default_user = ENV.fetch('USER', 'root')
      @default_port = 22
      @ssh_options = {
        verify_host_key: :never,
        non_interactive: true,
        use_agent: true,
        forward_agent: false
      }
    end

    def set_default_paths
      @inventory_file = 'inventory.yml'
      @template_dir = 'templates'
    end

    def apply_configuration(config)
      config.each do |key, value|
        method_name = "#{key}="
        send(method_name, value) if respond_to?(method_name)
      end
    end
  end
end
