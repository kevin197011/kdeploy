# frozen_string_literal: true

module Kdeploy
  class SSHConnection
    attr_reader :host, :session

    def initialize(host)
      @host = host
      @session = nil
    end

    # Establish SSH connection
    # @return [Boolean] True if connection successful
    def connect
      return if @session

      require 'net/ssh'

      KdeployLogger.debug("Connecting to #{@host}")

      begin
        @session = Net::SSH.start(
          @host.hostname,
          @host.user,
          port: @host.port,
          **@host.connection_options
        )
      rescue Net::SSH::AuthenticationFailed => e
        raise "SSH authentication failed for #{@host}: #{e.message}"
      rescue Net::SSH::ConnectionTimeout => e
        raise "SSH connection timed out for #{@host}: #{e.message}"
      rescue StandardError => e
        raise "SSH connection failed for #{@host}: #{e.message}"
      end

      KdeployLogger.debug("Connected to #{@host}")
    end

    # Check if connection is active
    # @return [Boolean] True if connected
    def connected?
      @connected && @session && !@session.closed?
    end

    # Execute command on remote host
    # @param command [String] Command to execute
    # @param timeout [Integer] Command timeout in seconds
    # @return [Hash] Result with stdout, stderr, exit_code
    def execute(command, timeout: nil)
      return execute_local(command) if @host.hostname == 'localhost'

      ensure_connected

      result = {
        stdout: '',
        stderr: '',
        exit_code: nil,
        success: false
      }

      timeout ||= Kdeploy.configuration&.command_timeout || 300

      KdeployLogger.debug("Executing on #{@host}: #{command}")

      begin
        Timeout.timeout(timeout) do
          channel = @session.open_channel do |ch|
            ch.exec(command) do |ch, success|
              unless success
                result[:stderr] = 'Failed to execute command'
                result[:exit_code] = 1
                return result
              end

              ch.on_data do |_ch, data|
                result[:stdout] += data
              end

              ch.on_extended_data do |_ch, _type, data|
                result[:stderr] += data
              end

              ch.on_request('exit-status') do |_ch, data|
                result[:exit_code] = data.read_long
              end
            end
          end

          channel.wait
        end
      rescue Timeout::Error
        result[:stderr] = "Command timed out after #{timeout} seconds"
        result[:exit_code] = 1
      end

      result[:success] = result[:exit_code]&.zero? || false

      KdeployLogger.debug("Command completed on #{@host}: exit_code=#{result[:exit_code]}")

      result
    rescue Net::SSH::Exception => e
      KdeployLogger.error("SSH execution error on #{@host}: #{e.message}")
      {
        stdout: '',
        stderr: e.message,
        exit_code: 1,
        success: false
      }
    end

    # Upload file to remote host
    # @param local_path [String] Local file path
    # @param remote_path [String] Remote file path
    # @return [Boolean] True if upload successful
    def upload(local_path, remote_path)
      ensure_connected

      KdeployLogger.debug("Uploading #{local_path} to #{@host}:#{remote_path}")

      @session.scp.upload!(local_path, remote_path)

      KdeployLogger.debug("Upload completed: #{local_path} -> #{@host}:#{remote_path}")
      true
    rescue Net::SCP::Error => e
      KdeployLogger.error("Upload failed #{local_path} -> #{@host}:#{remote_path}: #{e.message}")
      false
    end

    # Download file from remote host
    # @param remote_path [String] Remote file path
    # @param local_path [String] Local file path
    # @return [Boolean] True if download successful
    def download(remote_path, local_path)
      ensure_connected

      KdeployLogger.debug("Downloading #{@host}:#{remote_path} to #{local_path}")

      @session.scp.download!(remote_path, local_path)

      KdeployLogger.debug("Download completed: #{@host}:#{remote_path} -> #{local_path}")
      true
    rescue Net::SCP::Error => e
      KdeployLogger.error("Download failed #{@host}:#{remote_path} -> #{local_path}: #{e.message}")
      false
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
      return unless @session

      KdeployLogger.debug("Closing connection to #{@host}")
      @session.close
      @session = nil
    end

    private

    def ensure_connected
      connect unless connected?
      raise ConnectionError, "Not connected to #{@host}" unless connected?
    end

    def execute_local(command)
      require 'open3'

      KdeployLogger.debug("Executing locally: #{command}")

      begin
        stdout, stderr, status = Open3.capture3(command)

        result = {
          stdout: stdout,
          stderr: stderr,
          exit_code: status.exitstatus,
          success: status.success?
        }

        KdeployLogger.debug("Local command completed: exit_code=#{result[:exit_code]}")

        result
      rescue StandardError => e
        KdeployLogger.error("Local execution error: #{e.message}")
        {
          stdout: '',
          stderr: e.message,
          exit_code: 1,
          success: false
        }
      end
    end
  end
end
