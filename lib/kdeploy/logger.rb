# frozen_string_literal: true

module Kdeploy
  class KdeployLogger
    class << self
      attr_accessor :instance

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

    def initialize(level: :info, file: nil)
      @logger = Logger.new(file || $stdout)
      @logger.level = logger_level(level)
      @logger.formatter = proc do |severity, datetime, _progname, msg|
        timestamp = datetime.strftime('%Y-%m-%d %H:%M:%S')
        colored_msg = colorize_message(severity, msg)
        "[#{timestamp}] #{severity}: #{colored_msg}\n"
      end
    end

    def debug(message)
      @logger.debug(message)
    end

    def info(message)
      @logger.info(message)
    end

    def warn(message)
      @logger.warn(message)
    end

    def error(message)
      @logger.error(message)
    end

    def fatal(message)
      @logger.fatal(message)
    end

    private

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
