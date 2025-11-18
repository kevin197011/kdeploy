# frozen_string_literal: true

module Kdeploy
  # Base error class for all Kdeploy errors
  class Error < StandardError; end

  # Raised when a task is not found
  class TaskNotFoundError < Error
    def initialize(task_name)
      super("Task not found: #{task_name}")
    end
  end

  # Raised when a host is not found
  class HostNotFoundError < Error
    def initialize(host_name)
      super("Host not found: #{host_name}")
    end
  end

  # Raised when SSH operation fails
  class SSHError < Error
    def initialize(message, original_error = nil)
      super("SSH operation failed: #{message}")
      @original_error = original_error
    end

    attr_reader :original_error
  end

  # Raised when SCP operation fails
  class SCPError < Error
    def initialize(message, original_error = nil)
      super("SCP upload failed: #{message}")
      @original_error = original_error
    end

    attr_reader :original_error
  end

  # Raised when template operation fails
  class TemplateError < Error
    def initialize(message, original_error = nil)
      super("Template operation failed: #{message}")
      @original_error = original_error
    end

    attr_reader :original_error
  end

  # Raised when configuration is invalid
  class ConfigurationError < Error
    def initialize(message)
      super("Configuration error: #{message}")
    end
  end

  # Raised when file operation fails
  class FileNotFoundError < Error
    def initialize(file_path)
      super("File not found: #{file_path}")
    end
  end
end
