# frozen_string_literal: true

module Kdeploy
  # Host class for managing remote host configuration and connection details
  class Host
    attr_reader :hostname, :user, :port, :ssh_options, :roles, :vars

    def initialize(hostname, user: nil, port: nil, ssh_options: {}, roles: [], vars: {})
      @hostname = hostname
      @user = user || Kdeploy.configuration&.default_user || ENV.fetch('USER', nil)
      @port = port || Kdeploy.configuration&.default_port || 22
      @ssh_options = ssh_options
      @roles = Array(roles)
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
    # @return [Object] Set value
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
      base_options = Kdeploy.configuration&.merged_ssh_options(@ssh_options) || @ssh_options
      base_options.merge(
        timeout: Kdeploy.configuration&.ssh_timeout || 30
      )
    end

    # String representation of the host
    # @return [String] Connection string
    def to_s
      connection_string
    end

    # Detailed string representation of the host
    # @return [String] Host details
    def inspect
      "#<Kdeploy::Host #{connection_string} roles=#{@roles} vars=#{@vars.keys}>"
    end

    # Compare hosts for equality
    # @param other [Host] Host to compare with
    # @return [Boolean] True if hosts are equal
    def ==(other)
      return false unless other.is_a?(Host)

      hostname == other.hostname &&
        user == other.user &&
        port == other.port
    end

    alias eql? ==

    # Generate hash code for host
    # @return [Integer] Hash code
    def hash
      [hostname, user, port].hash
    end
  end
end
