# frozen_string_literal: true

module Kdeploy
  # SSHConnection class for managing SSH connections to remote hosts
  class SSHConnection
    attr_reader :host, :session

    def initialize(host)
      @host = host
      @session = nil
      @connected = false
    end

    # Establish SSH connection
    # @return [Boolean] True if connection successful
    # @raise [ConnectionError] If connection fails
    def connect
      return true if connected?

      KdeployLogger.debug("Connecting to #{@host}")
      establish_connection
      KdeployLogger.debug("Connected to #{@host}")
      true
    rescue Net::SSH::Exception => e
      handle_connection_error(e)
    end

    # Check if connection is active
    # @return [Boolean] True if connected
    def connected?
      @connected && @session && !@session.closed?
    end

    # Execute command on remote host
    # @param command [String] Command to execute
    # @param timeout [Integer] Command timeout in seconds
    # @return [Hash] Result with stdout, stderr, exit_code, and success
    def execute(command, timeout: nil)
      ensure_connected

      result = initialize_result
      timeout ||= Kdeploy.configuration&.command_timeout || 300

      KdeployLogger.debug("Executing on #{@host}: #{command}")
      execute_command(command, result)
      KdeployLogger.debug("Command completed on #{@host}: exit_code=#{result[:exit_code]}")

      result
    rescue Net::SSH::Exception => e
      handle_execution_error(e)
    end

    # Upload file to remote host
    # @param local_path [String] Local file path
    # @param remote_path [String] Remote file path
    # @return [Boolean] True if upload successful
    def upload(local_path, remote_path)
      ensure_connected

      KdeployLogger.debug("Uploading #{local_path} to #{@host}:#{remote_path}")
      perform_upload(local_path, remote_path)
      KdeployLogger.debug("Upload completed: #{local_path} -> #{@host}:#{remote_path}")
      true
    rescue Net::SCP::Error => e
      handle_upload_error(e, local_path, remote_path)
    end

    # Download file from remote host
    # @param remote_path [String] Remote file path
    # @param local_path [String] Local file path
    # @return [Boolean] True if download successful
    def download(remote_path, local_path)
      ensure_connected

      KdeployLogger.debug("Downloading #{@host}:#{remote_path} to #{local_path}")
      perform_download(remote_path, local_path)
      KdeployLogger.debug("Download completed: #{@host}:#{remote_path} -> #{local_path}")
      true
    rescue Net::SCP::Error => e
      handle_download_error(e, remote_path, local_path)
    end

    # Close SSH connection
    def disconnect
      return unless @session

      @session.close unless @session.closed?
      @session = nil
      @connected = false
      KdeployLogger.debug("Disconnected from #{@host}")
    end

    # Clean up connection
    def cleanup
      disconnect
    end

    private

    def establish_connection
      @session = Net::SSH.start(
        @host.hostname,
        @host.user,
        port: @host.port,
        **@host.connection_options
      )
      @connected = true
    end

    def handle_connection_error(error)
      KdeployLogger.error("Failed to connect to #{@host}: #{error.message}")
      raise ConnectionError, "Failed to connect to #{@host}: #{error.message}"
    end

    def ensure_connected
      connect unless connected?
      raise ConnectionError, "Not connected to #{@host}" unless connected?
    end

    def initialize_result
      {
        stdout: '',
        stderr: '',
        exit_code: nil,
        success: false
      }
    end

    def execute_command(command, result)
      channel = create_command_channel(command, result)
      channel.wait
      result[:success] = result[:exit_code]&.zero? || false
    end

    def create_command_channel(command, result)
      @session.open_channel do |ch|
        ch.exec(command) do |ch, success|
          handle_command_execution(ch, success, result)
        end
      end
    end

    def handle_command_execution(channel, success, result)
      unless success
        result[:stderr] = 'Failed to execute command'
        result[:exit_code] = 1
        return
      end

      setup_command_callbacks(channel, result)
    end

    def setup_command_callbacks(channel, result)
      channel.on_data { |_ch, data| result[:stdout] += data }
      channel.on_extended_data { |_ch, _type, data| result[:stderr] += data }
      channel.on_request('exit-status') { |_ch, data| result[:exit_code] = data.read_long }
    end

    def handle_execution_error(error)
      KdeployLogger.error("SSH execution error on #{@host}: #{error.message}")
      {
        stdout: '',
        stderr: error.message,
        exit_code: 1,
        success: false
      }
    end

    def perform_upload(local_path, remote_path)
      @session.scp.upload!(local_path, remote_path)
    end

    def handle_upload_error(error, local_path, remote_path)
      KdeployLogger.error("Upload failed #{local_path} -> #{@host}:#{remote_path}: #{error.message}")
      false
    end

    def perform_download(remote_path, local_path)
      @session.scp.download!(remote_path, local_path)
    end

    def handle_download_error(error, remote_path, local_path)
      KdeployLogger.error("Download failed #{@host}:#{remote_path} -> #{local_path}: #{error.message}")
      false
    end
  end
end
