# frozen_string_literal: true

module Kdeploy
  class Inventory
    attr_reader :hosts, :groups, :vars

    def initialize(inventory_file)
      @data = YAML.load_file(inventory_file)
      @groups = {}
      @vars = @data['vars'] || @data[:vars] || {}

      parse_groups(@data)

      KdeployLogger.info("Loaded #{all_hosts.size} hosts from inventory: #{inventory_file}")
    end

    # Load inventory from YAML file
    # @param inventory_file [String] Path to inventory file
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

    # Get all hosts from all groups
    # @return [Array<Host>] All hosts
    def all_hosts
      hosts = Set.new
      @groups.each_value do |group|
        group[:hosts].each do |host|
          hosts.add(host)
        end
      end
      hosts.to_a
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

    # Get global variables
    # @return [Hash] Global variables
    def global_vars
      @vars
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

    # Parse inventory data from YAML
    # @param inventory_data [Hash] Parsed YAML data
    def parse_inventory(inventory_data)
      return unless inventory_data.is_a?(Hash)

      # Parse global variables
      @vars = inventory_data['vars'] || inventory_data[:vars] || {}

      # Parse groups
      parse_groups(inventory_data)

      # Parse individual hosts
      parse_hosts(inventory_data)

      # Apply group variables to hosts
      apply_group_variables
    end

    # Parse groups from inventory data
    # @param inventory_data [Hash] Inventory data
    def parse_groups(inventory_data)
      groups_data = inventory_data['groups'] || inventory_data[:groups] || {}

      groups_data.each do |group_name, group_config|
        group_name = group_name.to_s
        group_config ||= {}

        @groups[group_name] = {
          hosts: [],
          vars: group_config['vars'] || group_config[:vars] || {},
          children: Array(group_config['children'] || group_config[:children] || [])
        }

        # Parse hosts in group
        Array(group_config['hosts'] || group_config[:hosts]).each do |host_config|
          if host_config.is_a?(Hash)
            hostname = host_config['hostname'] || host_config[:hostname]
            next unless hostname

            # Create host object
            host = Host.new(
              hostname,
              user: host_config['user'] || host_config[:user],
              port: host_config['port'] || host_config[:port],
              roles: Array(host_config['roles'] || host_config[:roles] || [group_name]),
              vars: host_config['vars'] || host_config[:vars] || {},
              ssh_options: host_config['ssh'] || host_config[:ssh] || {}
            )

            # Add host to group
          else
            # Simple hostname string
            host = Host.new(host_config, roles: [group_name])
          end
          @groups[group_name][:hosts] << host
        end
      end

      # Resolve group children
      resolve_group_children
    end

    # Parse hosts from inventory data
    # @param inventory_data [Hash] Inventory data
    def parse_hosts(inventory_data)
      hosts_data = inventory_data['hosts'] || inventory_data[:hosts] || {}

      hosts_data.each do |hostname, host_config|
        host_config ||= {}

        # Determine host groups and roles
        host_groups = find_host_groups(hostname)
        host_roles = Array(host_config['roles'] || host_config[:roles] || host_groups)

        # Create host object
        @hosts[hostname] = Host.new(
          hostname,
          user: host_config['user'] || host_config[:user],
          port: host_config['port'] || host_config[:port],
          ssh_options: parse_ssh_options(host_config),
          roles: host_roles,
          vars: host_config['vars'] || host_config[:vars] || {}
        )
      end
    end

    # Parse SSH options from host config
    # @param host_config [Hash] Host configuration
    # @return [Hash] SSH options
    def parse_ssh_options(host_config)
      ssh_config = host_config['ssh'] || host_config[:ssh] || {}
      options = {}

      # SSH key file
      if ssh_config['key_file'] || ssh_config[:key_file]
        key_file = ssh_config['key_file'] || ssh_config[:key_file]
        options[:keys] = [File.expand_path(key_file)]
      end

      # SSH key data
      options[:key_data] = Array(ssh_config['key_data'] || ssh_config[:key_data]) if ssh_config['key_data'] || ssh_config[:key_data]

      # Other SSH options
      if ssh_config['password'] || ssh_config[:password]
        options[:password] =
          ssh_config['password'] || ssh_config[:password]
      end
      if ssh_config['passphrase'] || ssh_config[:passphrase]
        options[:passphrase] =
          ssh_config['passphrase'] || ssh_config[:passphrase]
      end

      # Host key verification
      if ssh_config.key?('verify_host_key') || ssh_config.key?(:verify_host_key)
        verify_host_key = ssh_config['verify_host_key'] || ssh_config[:verify_host_key]
        options[:verify_host_key] = verify_host_key ? :always : :never
      end

      # Connection timeout
      options[:timeout] = ssh_config['timeout'] || ssh_config[:timeout] if ssh_config['timeout'] || ssh_config[:timeout]

      options
    end

    # Find which groups a host belongs to
    # @param hostname [String] Hostname
    # @return [Array<String>] Group names
    def find_host_groups(hostname)
      groups = []
      @groups.each do |group_name, group_config|
        groups << group_name if group_config[:hosts].include?(hostname)
      end
      groups
    end

    # Resolve group children relationships
    def resolve_group_children
      @groups.each do |group_name, group_config|
        group_config[:children].each do |child_group|
          next unless @groups[child_group]

          # Add child group's hosts to parent group
          @groups[group_name][:hosts].concat(@groups[child_group][:hosts])
        end

        # Remove duplicates
        @groups[group_name][:hosts].uniq!
      end
    end

    # Apply group variables to hosts
    def apply_group_variables
      @hosts.each do |hostname, host|
        host_groups = find_host_groups(hostname)

        # Apply group variables in order
        host_groups.each do |group_name|
          group_vars = @groups[group_name][:vars] || {}
          group_vars.each do |key, value|
            host.set_var(key, value) unless host.var(key)
          end
        end

        # Apply global variables
        @vars.each do |key, value|
          host.set_var(key, value) unless host.var(key)
        end
      end
    end
  end
end
