# frozen_string_literal: true

module Kdeploy
  # Host class for managing remote host configuration and connection details
  class Host
    attr_reader :hostname, :user, :port, :ssh_options, :roles, :vars
    attr_accessor :connection

    def initialize(hostname, user: nil, port: nil, ssh_options: {}, roles: [], vars: {})
      @hostname = hostname
      @user = user || vars['user'] || vars[:user] || Config.default_user || ENV.fetch('USER', 'root')
      @port = port || Config.default_port || 22
      @ssh_options = ssh_options || {}
      @roles = Array(roles).map(&:to_s)
      @vars = vars || {}
      @connection = nil
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
      @vars[key.to_sym] = value
    end

    # Get connection string for display
    # @return [String] Connection string
    def connection_string
      "#{@user}@#{@hostname}:#{@port}"
    end

    # Get SSH connection options
    # @return [Hash] SSH connection options
    def connection_options
      options = {}

      # SSH key file
      if @ssh_options['key_file'] || @ssh_options[:key_file]
        key_file = @ssh_options['key_file'] || @ssh_options[:key_file]
        options[:keys] = [File.expand_path(key_file)]
      end

      # SSH key data
      options[:key_data] = Array(@ssh_options['key_data'] || @ssh_options[:key_data]) if @ssh_options['key_data'] || @ssh_options[:key_data]

      # Other SSH options
      options[:password] = @ssh_options['password'] || @ssh_options[:password] if @ssh_options['password'] || @ssh_options[:password]
      options[:passphrase] = @ssh_options['passphrase'] || @ssh_options[:passphrase] if @ssh_options['passphrase'] || @ssh_options[:passphrase]

      # Host key verification
      if @ssh_options.key?('verify_host_key') || @ssh_options.key?(:verify_host_key)
        verify_host_key = @ssh_options['verify_host_key'] || @ssh_options[:verify_host_key]
        options[:verify_host_key] = verify_host_key ? :always : :never
      end

      # Connection timeout
      options[:timeout] = @ssh_options['timeout'] || @ssh_options[:timeout] if @ssh_options['timeout'] || @ssh_options[:timeout]

      # 代理设置
      options[:proxy] = @ssh_options['proxy'] || @ssh_options[:proxy] if @ssh_options['proxy'] || @ssh_options[:proxy]

      # 压缩设置
      options[:compression] = @ssh_options['compression'] || @ssh_options[:compression] if @ssh_options['compression'] || @ssh_options[:compression]

      # 加密设置
      options[:encryption] = @ssh_options['encryption'] || @ssh_options[:encryption] if @ssh_options['encryption'] || @ssh_options[:encryption]

      # HMAC设置
      options[:hmac] = @ssh_options['hmac'] || @ssh_options[:hmac] if @ssh_options['hmac'] || @ssh_options[:hmac]

      # 主机密钥算法
      options[:host_key] = @ssh_options['host_key'] || @ssh_options[:host_key] if @ssh_options['host_key'] || @ssh_options[:host_key]

      # 密钥交换算法
      options[:kex] = @ssh_options['kex'] || @ssh_options[:kex] if @ssh_options['kex'] || @ssh_options[:kex]

      # 认证方法
      if @ssh_options['auth_methods'] || @ssh_options[:auth_methods]
        options[:auth_methods] = @ssh_options['auth_methods'] || @ssh_options[:auth_methods]
      end

      # 最大认证尝试次数
      options[:max_tries] = @ssh_options['max_tries'] || @ssh_options[:max_tries] if @ssh_options['max_tries'] || @ssh_options[:max_tries]

      # 连接重试次数
      options[:retries] = @ssh_options['retries'] || @ssh_options[:retries] if @ssh_options['retries'] || @ssh_options[:retries]

      # 连接重试延迟
      options[:retry_delay] = @ssh_options['retry_delay'] || @ssh_options[:retry_delay] if @ssh_options['retry_delay'] || @ssh_options[:retry_delay]

      # 连接保持时间
      options[:keepalive] = @ssh_options['keepalive'] || @ssh_options[:keepalive] if @ssh_options['keepalive'] || @ssh_options[:keepalive]

      # 连接保持间隔
      if @ssh_options['keepalive_interval'] || @ssh_options[:keepalive_interval]
        options[:keepalive_interval] = @ssh_options['keepalive_interval'] || @ssh_options[:keepalive_interval]
      end

      # 连接池大小
      options[:pool_size] = @ssh_options['pool_size'] || @ssh_options[:pool_size] if @ssh_options['pool_size'] || @ssh_options[:pool_size]

      # 连接池超时
      if @ssh_options['pool_timeout'] || @ssh_options[:pool_timeout]
        options[:pool_timeout] = @ssh_options['pool_timeout'] || @ssh_options[:pool_timeout]
      end

      options
    end

    # Get connection
    def connection
      @connection ||= SSHConnection.new(self)
    end

    # Close connection
    def close
      @connection&.close
      @connection = nil
    end

    # Check connection status
    def connected?
      @connection&.connected?
    end

    # Reconnect
    def reconnect
      close
      connection
    end

    # Execute command
    def execute(command, options = {})
      connection.execute(command, options)
    end

    # Upload file
    def upload(source, target, options = {})
      connection.upload(source, target, options)
    end

    # Download file
    def download(source, target, options = {})
      connection.download(source, target, options)
    end

    # Check if file exists
    def file_exists?(path)
      connection.file_exists?(path)
    end

    # Check if directory exists
    def directory_exists?(path)
      connection.directory_exists?(path)
    end

    # Create directory
    def mkdir(path, options = {})
      connection.mkdir(path, options)
    end

    # Remove file
    def remove(path, options = {})
      connection.remove(path, options)
    end

    # Remove directory
    def rmdir(path, options = {})
      connection.rmdir(path, options)
    end

    # Change file permissions
    def chmod(path, mode, options = {})
      connection.chmod(path, mode, options)
    end

    # Change file owner
    def chown(path, user, group = nil, options = {})
      connection.chown(path, user, group, options)
    end

    # Get file content
    def read_file(path)
      connection.read_file(path)
    end

    # Write file content
    def write_file(path, content, options = {})
      connection.write_file(path, content, options)
    end

    # Append file content
    def append_file(path, content, options = {})
      connection.append_file(path, content, options)
    end

    # Get file attributes
    def stat(path)
      connection.stat(path)
    end

    # Get file list
    def ls(path = '.')
      connection.ls(path)
    end

    # String representation of the host
    # @return [String] Connection string
    def to_s
      connection_string
    end

    # Detailed string representation of the host
    # @return [String] Host details
    def inspect
      "#<#{self.class} #{connection_string} roles=#{@roles} vars=#{@vars.keys}>"
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
