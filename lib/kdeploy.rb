# frozen_string_literal: true

require_relative 'kdeploy/version'
require_relative 'kdeploy/banner'
require_relative 'kdeploy/dsl'
require_relative 'kdeploy/executor'
require_relative 'kdeploy/runner'
require_relative 'kdeploy/initializer'
require_relative 'kdeploy/template'
require_relative 'kdeploy/post_install'
require_relative 'kdeploy/cli'

module Kdeploy
  class Error < StandardError; end
  # Your code goes here...
end
