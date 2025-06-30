# frozen_string_literal: true

module Kdeploy
  # Custom logger class for Kdeploy with colorized output
  class KdeployLogger
    class << self
      attr_accessor :instance

      # Set up logger instance with specified level and output file
      # @param level [Symbol] Log level (:debug, :info, :warn, :error, :fatal)
      # @param file [String, IO] Output file or IO stream
      # @return [KdeployLogger] Logger instance
      def setup(level: :info, file: nil)
        @instance = new(level: level, file: file)
      end

      def method_missing(method_name, ...)
        return super unless respond_to_missing?(method_name, false)

        @instance ||= new
        @instance.send(method_name, ...)
      end

      def respond_to_missing?(method_name, include_private = false)
        return true if %i[debug info warn error fatal].include?(method_name)

        super
      end
    end

    # Initialize logger with specified level and output file
    # @param level [Symbol] Log level (:debug, :info, :warn, :error, :fatal)
    # @param file [String, IO] Output file or IO stream
    def initialize(level: :info, file: nil)
      @logger = Logger.new(file || $stdout)
      @logger.level = logger_level(level)
      @logger.formatter = method(:format_message)
    end

    # Log debug message
    # @param message [String] Message to log
    def debug(message)
      @logger.debug(message)
    end

    # Log info message
    # @param message [String] Message to log
    def info(message)
      @logger.info(message)
    end

    # Log warning message
    # @param message [String] Message to log
    def warn(message)
      @logger.warn(message)
    end

    # Log error message
    # @param message [String] Message to log
    def error(message)
      @logger.error(message)
    end

    # Log fatal message
    # @param message [String] Message to log
    def fatal(message)
      @logger.fatal(message)
    end

    private

    def format_message(severity, datetime, _progname, msg)
      timestamp = datetime.strftime('%Y-%m-%d %H:%M:%S')
      colored_msg = colorize_message(severity, msg)
      "[#{timestamp}] #{severity}: #{colored_msg}\n"
    end

    def logger_level(level)
      case level.to_sym
      when :debug then Logger::DEBUG
      when :info then Logger::INFO
      when :warn then Logger::WARN
      when :error then Logger::ERROR
      when :fatal then Logger::FATAL
      else Logger::INFO
      end
    end

    def colorize_message(severity, message)
      case severity
      when 'DEBUG' then message.colorize(:light_black)
      when 'INFO' then message.colorize(:green)
      when 'WARN' then message.colorize(:yellow)
      when 'ERROR' then message.colorize(:red)
      when 'FATAL' then message.colorize(:light_red)
      else message
      end
    end
  end
end
