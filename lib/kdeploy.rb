# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext'
require 'colorize'
require 'concurrent'
require 'erb'
require 'erubi'
require 'fileutils'
require 'json'
require 'logger'
require 'net/scp'
require 'net/ssh'
require 'pastel'
require 'pathname'
require 'thor'
require 'tty-logger'
require 'tty-prompt'
require 'tty-progressbar'
require 'tty-spinner'
require 'tty-table'
require 'yaml'
require 'zeitwerk'

# 设置自动加载
loader = Zeitwerk::Loader.for_gem
loader.setup

module Kdeploy
  class Error < StandardError; end
  class ValidationError < Error; end
  class ConfigError < Error; end
  class ExecutionError < Error; end
  class TemplateError < Error; end

  # 配置模块
  module Config
    extend self

    attr_accessor :logger, :prompt, :pastel, :spinner

    def setup
      self.logger = TTY::Logger.new do |config|
        config.level = :info
        config.metadata = [:time]
      end

      self.prompt = TTY::Prompt.new
      self.pastel = Pastel.new
      self.spinner = TTY::Spinner.new('[:spinner] :title', format: :dots)
    end

    def root
      @root ||= Pathname.new(Dir.pwd)
    end

    def templates_path
      root.join('templates')
    end

    def inventory_path
      root.join('inventory.yml')
    end
  end

  # 初始化配置
  Config.setup
end

# 加载所有子模块
require_relative 'kdeploy/version'
require_relative 'kdeploy/banner'
require_relative 'kdeploy/cli'
require_relative 'kdeploy/command'
require_relative 'kdeploy/configuration'
require_relative 'kdeploy/dsl'
require_relative 'kdeploy/host'
require_relative 'kdeploy/inventory'
require_relative 'kdeploy/logger'
require_relative 'kdeploy/pipeline'
require_relative 'kdeploy/runner'
require_relative 'kdeploy/ssh_connection'
require_relative 'kdeploy/statistics'
require_relative 'kdeploy/task'
require_relative 'kdeploy/template'
