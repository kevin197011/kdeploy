# frozen_string_literal: true

module Kdeploy
  class Host
    attr_reader :hostname, :user, :port, :ssh_options, :roles, :vars

    def initialize(hostname, user: nil, port: nil, ssh_options: {}, roles: [], vars: {})
      @hostname = hostname
      @user = user || Kdeploy.configuration&.default_user || ENV.fetch('USER', 'root')
      @port = port || Kdeploy.configuration&.default_port || 22
      @ssh_options = ssh_options || {}
      @roles = Array(roles).map(&:to_s)
      @vars = vars || {}
    end

    # Check if host has specific role
    # @param role [String, Symbol] Role to check
    # @return [Boolean] True if host has role
    def has_role?(role)
      @roles.include?(role.to_s) || @roles.include?(role.to_sym)
    end

    # Get variable value
    # @param key [String, Symbol] Variable key
    # @return [Object] Variable value
    def var(key)
      @vars[key.to_s] || @vars[key.to_sym]
    end

    # Set variable value
    # @param key [String, Symbol] Variable key
    # @param value [Object] Variable value
    def set_var(key, value)
      @vars[key.to_s] = value
    end

    # Get connection string for display
    # @return [String] Connection string
    def connection_string
      "#{@user}@#{@hostname}:#{@port}"
    end

    # Get SSH connection options
    # @return [Hash] SSH options
    def connection_options
      options = @ssh_options.dup || {}

      # Convert key_file to keys option
      options[:keys] = [options.delete('key_file') || options.delete(:key_file)] if options['key_file'] || options[:key_file]

      # Convert verify_host_key to verify_host_key option
      if options.key?('verify_host_key') || options.key?(:verify_host_key)
        verify = options.delete('verify_host_key') || options.delete(:verify_host_key)
        options[:verify_host_key] = verify ? :always : :never
      end

      # Add default options
      options[:timeout] = options['timeout'] || options[:timeout] || 10
      options[:keepalive] = true
      options[:keepalive_interval] = 30
      options[:non_interactive] = true
      options[:verify_host_key] = :never unless options.key?(:verify_host_key)

      options
    end

    def to_s
      "#{@user}@#{@hostname}:#{@port}"
    end

    def inspect
      "#<Kdeploy::Host #{connection_string} roles=#{@roles} vars=#{@vars.keys}>"
    end

    def ==(other)
      return false unless other.is_a?(Host)

      hostname == other.hostname &&
        user == other.user &&
        port == other.port
    end

    alias eql? ==

    def hash
      [hostname, user, port].hash
    end
  end
end
