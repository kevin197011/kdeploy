# frozen_string_literal: true

module Kdeploy
  # Inventory class for managing host inventory and configuration
  class Inventory
    attr_reader :hosts, :groups, :vars

    def initialize(inventory_file = nil)
      @hosts = {}
      @groups = {}
      @vars = {}
      load_from_file(inventory_file) if inventory_file && File.exist?(inventory_file)
    end

    # Load inventory from YAML file
    # @param inventory_file [String] Path to inventory file
    # @raise [ConfigurationError] If inventory file is invalid
    def load_from_file(inventory_file)
      inventory_data = YAML.load_file(inventory_file)
      parse_inventory(inventory_data)
    rescue Psych::SyntaxError => e
      raise ConfigurationError, "Invalid YAML syntax in inventory file: #{e.message}"
    rescue StandardError => e
      raise ConfigurationError, "Failed to load inventory file: #{e.message}"
    end

    # Get all hosts in a group
    # @param group_name [String, Symbol] Group name
    # @return [Array<Host>] Hosts in the group
    def hosts_in_group(group_name)
      group_name = group_name.to_s
      return [] unless @groups[group_name]

      @groups[group_name][:hosts].map { |hostname| @hosts[hostname] }.compact
    end

    # Get all hosts with specific role
    # @param role [String, Symbol] Role name
    # @return [Array<Host>] Hosts with the role
    def hosts_with_role(role)
      @hosts.values.select { |host| host.has_role?(role) }
    end

    # Get all hosts
    # @return [Array<Host>] All hosts
    def all_hosts
      @hosts.values
    end

    # Get host by hostname
    # @param hostname [String] Hostname
    # @return [Host, nil] Host object or nil
    def host(hostname)
      @hosts[hostname]
    end

    # Get group variable
    # @param group_name [String, Symbol] Group name
    # @param var_name [String, Symbol] Variable name
    # @return [Object] Variable value
    def group_var(group_name, var_name)
      group_name = group_name.to_s
      return nil unless @groups[group_name]

      @groups[group_name][:vars][var_name.to_s] || @groups[group_name][:vars][var_name.to_sym]
    end

    # Get global variable
    # @param var_name [String, Symbol] Variable name
    # @return [Object] Variable value
    def global_var(var_name)
      @vars[var_name.to_s] || @vars[var_name.to_sym]
    end

    # Export inventory summary
    # @return [Hash] Inventory summary
    def summary
      {
        total_hosts: @hosts.size,
        total_groups: @groups.size,
        hosts: @hosts.keys,
        groups: @groups.keys
      }
    end

    private

    def parse_inventory(inventory_data)
      return unless inventory_data.is_a?(Hash)

      @vars = extract_vars(inventory_data)
      parse_groups(inventory_data)
      parse_hosts(inventory_data)
      apply_group_variables
    end

    def extract_vars(data)
      data['vars'] || data[:vars] || {}
    end

    def parse_groups(inventory_data)
      groups_data = inventory_data['groups'] || inventory_data[:groups] || {}

      groups_data.each do |group_name, group_config|
        process_group(group_name.to_s, group_config || {})
      end

      resolve_group_children
    end

    def process_group(group_name, group_config)
      @groups[group_name] = {
        hosts: extract_group_hosts(group_config),
        vars: extract_group_vars(group_config),
        children: extract_group_children(group_config)
      }
    end

    def extract_group_hosts(config)
      Array(config['hosts'] || config[:hosts] || [])
    end

    def extract_group_vars(config)
      config['vars'] || config[:vars] || {}
    end

    def extract_group_children(config)
      Array(config['children'] || config[:children] || [])
    end

    def parse_hosts(inventory_data)
      hosts_data = inventory_data['hosts'] || inventory_data[:hosts] || {}

      hosts_data.each do |hostname, host_config|
        process_host(hostname, host_config || {})
      end
    end

    def process_host(hostname, host_config)
      host_groups = find_host_groups(hostname)
      host_roles = Array(host_config['roles'] || host_config[:roles] || host_groups)

      @hosts[hostname] = create_host(hostname, host_config, host_roles)
    end

    def create_host(hostname, config, roles)
      Host.new(
        hostname,
        user: config['user'] || config[:user],
        port: config['port'] || config[:port],
        ssh_options: parse_ssh_options(config),
        roles: roles,
        vars: config['vars'] || config[:vars] || {}
      )
    end

    def parse_ssh_options(host_config)
      ssh_config = host_config['ssh'] || host_config[:ssh] || {}
      options = {}

      process_ssh_key_options(ssh_config, options)
      process_ssh_auth_options(ssh_config, options)
      process_ssh_verification_options(ssh_config, options)
      process_ssh_timeout_option(ssh_config, options)

      options
    end

    def process_ssh_key_options(ssh_config, options)
      if ssh_config['key_file'] || ssh_config[:key_file]
        key_file = ssh_config['key_file'] || ssh_config[:key_file]
        options[:keys] = [File.expand_path(key_file)]
      end

      return unless ssh_config['key_data'] || ssh_config[:key_data]

      options[:key_data] = Array(ssh_config['key_data'] || ssh_config[:key_data])
    end

    def process_ssh_auth_options(ssh_config, options)
      options[:password] = ssh_config['password'] || ssh_config[:password] if ssh_config['password'] || ssh_config[:password]
      return unless ssh_config['passphrase'] || ssh_config[:passphrase]

      options[:passphrase] = ssh_config['passphrase'] || ssh_config[:passphrase]
    end

    def process_ssh_verification_options(ssh_config, options)
      return unless ssh_config.key?('verify_host_key') || ssh_config.key?(:verify_host_key)

      verify_host_key = ssh_config['verify_host_key'] || ssh_config[:verify_host_key]
      options[:verify_host_key] = verify_host_key ? :always : :never
    end

    def process_ssh_timeout_option(ssh_config, options)
      options[:timeout] = ssh_config['timeout'] || ssh_config[:timeout] if ssh_config['timeout'] || ssh_config[:timeout]
    end

    def find_host_groups(hostname)
      @groups.each_with_object([]) do |(group_name, group_config), groups|
        groups << group_name if group_config[:hosts].include?(hostname)
      end
    end

    def resolve_group_children
      @groups.each do |group_name, group_config|
        process_group_children(group_name, group_config)
      end
    end

    def process_group_children(group_name, group_config)
      group_config[:children].each do |child_group|
        next unless @groups[child_group]

        @groups[group_name][:hosts].concat(@groups[child_group][:hosts])
      end

      @groups[group_name][:hosts].uniq!
    end

    def apply_group_variables
      @hosts.each do |hostname, host|
        host_groups = find_host_groups(hostname)
        apply_group_vars_to_host(host, host_groups)
        apply_global_vars_to_host(host)
      end
    end

    def apply_group_vars_to_host(host, host_groups)
      host_groups.each do |group_name|
        group_vars = @groups[group_name][:vars] || {}
        group_vars.each do |key, value|
          host.set_var(key, value) unless host.var(key)
        end
      end
    end

    def apply_global_vars_to_host(host)
      @vars.each do |key, value|
        host.set_var(key, value) unless host.var(key)
      end
    end
  end
end
