# frozen_string_literal: true

module Kdeploy
  # Command class for executing commands on remote hosts
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
      processed_command = process_command_template(host)

      log_command_start(host, processed_command)
      @result = execute_with_retry(connection, processed_command)
      duration = Time.now - start_time

      log_result(host, duration)
      record_statistics(host.hostname, duration, @result[:success])

      @result[:success]
    rescue StandardError => e
      handle_execution_error(host, e, start_time)
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
      process_global_variables(processed)
      process_host_variables(processed, host)
      process_host_info(processed, host)
    end

    def process_global_variables(command)
      @global_variables.each_with_object(command) do |(key, value), cmd|
        cmd.gsub!("{{#{key}}}", value.to_s)
        cmd.gsub!("${#{key}}", value.to_s)
      end
    end

    def process_host_variables(command, host)
      host.vars.each_with_object(command) do |(key, value), cmd|
        cmd.gsub!("{{#{key}}}", value.to_s)
        cmd.gsub!("${#{key}}", value.to_s)
      end
    end

    def process_host_info(command, host)
      command.gsub('{{hostname}}', host.hostname)
        .gsub('{{user}}', host.user)
        .gsub('{{port}}', host.port.to_s)
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
          log_retry_attempt(attempts, retry_count, retry_delay)
          sleep(retry_delay)
        end
      end

      result
    end

    def log_command_start(host, command)
      KdeployLogger.info("🚀 Executing '#{@name}' on #{host}")
      KdeployLogger.debug("   Command: #{command}")
    end

    def log_retry_attempt(attempts, retry_count, retry_delay)
      KdeployLogger.warn(
        "Command '#{@name}' failed (attempt #{attempts}/#{retry_count + 1}), " \
        "retrying in #{retry_delay}s..."
      )
    end

    def log_result(host, duration)
      if @result[:success]
        log_success(host, duration)
      else
        log_failure(host, duration)
      end
    end

    def log_success(host, duration)
      KdeployLogger.info("✅ Command '#{@name}' completed on #{host} in #{duration.round(2)}s")
      return if @result[:stdout].strip.empty?

      KdeployLogger.info('📤 Output:')
      @result[:stdout].strip.split("\n").each do |line|
        KdeployLogger.info("   #{line}")
      end
    end

    def log_failure(host, duration)
      level = @options[:ignore_errors] ? :warn : :error
      icon = @options[:ignore_errors] ? '⚠️' : '❌'

      KdeployLogger.send(
        level,
        "#{icon} Command '#{@name}' failed on #{host} in #{duration.round(2)}s " \
        "(exit code: #{@result[:exit_code]})"
      )

      KdeployLogger.send(level, "📤 STDERR: #{@result[:stderr]}") unless @result[:stderr].empty?
      KdeployLogger.send(level, "📤 STDOUT: #{@result[:stdout]}") unless @result[:stdout].strip.empty?
    end

    def handle_execution_error(host, error, start_time)
      duration = Time.now - start_time
      KdeployLogger.error(
        "Command '#{@name}' failed on #{host} after #{duration.round(2)}s: #{error.message}"
      )

      @result = {
        stdout: '',
        stderr: error.message,
        exit_code: 1,
        success: false
      }

      record_statistics(host.hostname, duration, false)
      false
    end

    def record_statistics(hostname, duration, success)
      Kdeploy.statistics.record_command(@name, hostname, success, duration)
    end
  end
end
