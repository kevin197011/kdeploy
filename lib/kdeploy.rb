# frozen_string_literal: true

# Copyright (c) 2023 kk
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

module Kdeploy
  class Error < StandardError; end
  # Your code goes here...
end

Dir.glob(File.join(File.dirname(__FILE__), 'kdeploy/*.rb')).each do |r|
  require_relative "kdeploy/#{File.basename(r, '.rb')}"
end
