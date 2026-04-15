# frozen_string_literal: true

require_relative 'kdeploy/version'
require_relative 'kdeploy/errors'
require_relative 'kdeploy/config/configuration'
require_relative 'kdeploy/output/output'
require_relative 'kdeploy/banner'
require_relative 'kdeploy/executor/file_filter'
require_relative 'kdeploy/dsl/dsl'
require_relative 'kdeploy/executor/executor'
require_relative 'kdeploy/executor/command_executor'
require_relative 'kdeploy/output/output_formatter'
require_relative 'kdeploy/cli/help_formatter'
require_relative 'kdeploy/runner/runner'
require_relative 'kdeploy/dsl/initializer'
require_relative 'kdeploy/template/template'
require_relative 'kdeploy/post_install'
require_relative 'kdeploy/cli/cli'

# Kdeploy - A lightweight agentless deployment automation tool
module Kdeploy
  # Your code goes here...
end
