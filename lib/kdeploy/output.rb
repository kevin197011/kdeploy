# frozen_string_literal: true

require 'pastel'

module Kdeploy
  # Abstract output interface
  class Output
    def write(message)
      raise NotImplementedError, 'Subclasses must implement write'
    end

    def write_line(message)
      write("#{message}\n")
    end

    def write_error(message)
      write_line(message)
    end
  end

  # Console output implementation
  class ConsoleOutput < Output
    def initialize
      super
      @pastel = Pastel.new
    end

    def write(message)
      print(message)
    end

    def write_line(message)
      puts(message)
    end

    def write_error(message)
      puts(@pastel.red(message))
    end

    attr_reader :pastel
  end

  # Silent output for testing
  class SilentOutput < Output
    attr_reader :messages, :errors

    def initialize
      super
      @messages = []
      @errors = []
    end

    def write(message)
      @messages << message
    end

    def write_line(message)
      @messages << "#{message}\n"
    end

    def write_error(message)
      @errors << message
      @messages << "#{message}\n"
    end

    def clear
      @messages.clear
      @errors.clear
    end
  end
end
