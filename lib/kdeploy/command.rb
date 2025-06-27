# frozen_string_literal: true

module Kdeploy
  class Command
    attr_reader :name, :command, :options, :result

    def initialize(name, command, options = {})
      @name = name
      @command = command
      @options = default_options.merge(options)
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

      # Replace host variables
      host.vars.each do |key, value|
        processed = processed.gsub("{{#{key}}}", value.to_s)
        processed = processed.gsub("${#{key}}", value.to_s)
      end

      # Replace host information
      processed = processed.gsub('{{hostname}}', host.hostname)
      processed = processed.gsub('{{user}}', host.user)
      processed.gsub('{{port}}', host.port.to_s)
    end

    def execute_with_retry(connection, command)
      retry_count = @options[:retry_count] || Kdeploy.configuration&.retry_count || 0
      retry_delay = @options[:retry_delay] || Kdeploy.configuration&.retry_delay || 1

      result = nil
      attempts = 0

      loop do
        attempts += 1
        result = connection.execute(command, timeout: @options[:timeout])

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
        # Show command output at info level for successful commands
        unless @result[:stdout].strip.empty?
          KdeployLogger.info('📤 Output:')
          @result[:stdout].strip.split("\n").each do |line|
            KdeployLogger.info("   #{line}")
          end
        end
      else
        level = @options[:ignore_errors] ? :warn : :error
        icon = @options[:ignore_errors] ? '⚠️' : '❌'
        KdeployLogger.send(level,
                           "#{icon} Command '#{@name}' failed on #{host} in #{duration.round(2)}s (exit code: #{@result[:exit_code]})")
        KdeployLogger.send(level, "📤 STDERR: #{@result[:stderr]}") unless @result[:stderr].empty?
        # Also show stdout for failed commands if available
        KdeployLogger.send(level, "📤 STDOUT: #{@result[:stdout]}") unless @result[:stdout].strip.empty?
      end
    end
  end
end
