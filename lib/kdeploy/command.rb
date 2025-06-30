# frozen_string_literal: true

module Kdeploy
  class Command
    attr_reader :name, :command, :options, :result

    def initialize(name, command, options = {})
      @name = name
      @command = command
      @options = default_options.merge(options)
      @global_variables = options.delete(:global_variables) || {}
      @result = nil
    end

    # Execute command on specified host
    # @param host [Host] Target host
    # @param connection [SSHConnection] SSH connection
    # @return [Boolean] True if command succeeded
    def execute(host, connection)
      start_time = Time.now

      # Process command template with host variables
      processed_command = process_command_template(host)

      KdeployLogger.info("🚀 Executing '#{@name}' on #{host}")
      KdeployLogger.debug("   Command: #{processed_command}")

      # Execute with retry logic
      @result = execute_with_retry(connection, processed_command)

      duration = Time.now - start_time
      log_result(host, duration)

      # Record command statistics
      Kdeploy.statistics.record_command(@name, host.hostname, @result[:success], duration)

      @result[:success]
    rescue StandardError => e
      duration = Time.now - start_time
      KdeployLogger.error("Command '#{@name}' failed on #{host} after #{duration.round(2)}s: #{e.message}")
      @result = {
        stdout: '',
        stderr: e.message,
        exit_code: 1,
        success: false
      }

      # Record failed command statistics
      Kdeploy.statistics.record_command(@name, host.hostname, false, duration)

      false
    end

    # Check if command should run on host
    # @param host [Host] Target host
    # @return [Boolean] True if command should run
    def should_run_on?(host)
      return true unless @options[:only] || @options[:except]

      if @options[:only]
        roles = Array(@options[:only])
        return roles.any? { |role| host.has_role?(role) }
      end

      if @options[:except]
        roles = Array(@options[:except])
        return roles.none? { |role| host.has_role?(role) }
      end

      true
    end

    def result
      @result || {
        stdout: '',
        stderr: '',
        exit_code: nil,
        success: false
      }
    end

    private

    def default_options
      {
        timeout: nil,
        retry_count: nil,
        retry_delay: nil,
        ignore_errors: false,
        only: nil,
        except: nil
      }
    end

    def process_command_template(host)
      processed = @command.dup

      # Replace global variables first (lower priority)
      @global_variables.each do |key, value|
        processed = processed.gsub(/\{\{#{key}\}\}|\$\{#{key}\}/, value.to_s)
      end

      if host
        # Replace host variables (higher priority, can override globals)
        host.vars.each do |key, value|
          processed = processed.gsub(/\{\{#{key}\}\}|\$\{#{key}\}/, value.to_s)
        end

        # Replace host information (highest priority)
        processed = processed.gsub(/\{\{hostname\}\}|\$\{hostname\}/, host.hostname)
        processed = processed.gsub(/\{\{user\}\}|\$\{user\}/, host.user)
        processed = processed.gsub(/\{\{port\}\}|\$\{port\}/, host.port.to_s)
      end

      # Replace any remaining variables with empty string
      processed = processed.gsub(/\{\{[^}]+\}\}|\$\{[^}]+\}/, '')

      # Log the processed command
      KdeployLogger.debug("Processed command: #{processed}")

      processed
    end

    def execute_with_retry(connection, command)
      retry_count = @options[:retry_count] || Kdeploy.configuration&.retry_count || 0
      retry_delay = @options[:retry_delay] || Kdeploy.configuration&.retry_delay || 1
      timeout = @options[:timeout] || Kdeploy.configuration&.command_timeout || 300

      result = nil
      attempts = 0

      loop do
        attempts += 1
        result = connection.execute(command, timeout: timeout)

        break if result[:success] || attempts > retry_count

        if attempts <= retry_count
          KdeployLogger.warn("Command '#{@name}' failed (attempt #{attempts}/#{retry_count + 1}), retrying in #{retry_delay}s...")
          sleep(retry_delay)
        end
      end

      result
    end

    def log_result(host, duration)
      if @result[:success]
        KdeployLogger.info("✅ Command '#{@name}' completed on #{host} in #{duration.round(2)}s")
      else
        KdeployLogger.error("❌ Command '#{@name}' failed on #{host} after #{duration.round(2)}s")
      end

      unless @result[:stdout].empty?
        KdeployLogger.info('📤 Output:')
        @result[:stdout].each_line do |line|
          KdeployLogger.info("   #{line.chomp}")
        end
      end

      return if @result[:stderr].empty?

      KdeployLogger.error('📥 Error:')
      @result[:stderr].each_line do |line|
        KdeployLogger.error("   #{line.chomp}")
      end
    end
  end
end
