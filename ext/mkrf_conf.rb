#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'

# Create Rakefile for gem install hook
File.write(File.join(File.dirname(__FILE__), 'Rakefile'), <<~RAKEFILE)
  task :default do
    # Add lib directory to load path
    lib_path = File.expand_path('../../lib', __FILE__)
    $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)

    require 'kdeploy/post_install'
    Kdeploy::PostInstall.run
  end
RAKEFILE

# Run post-install script immediately for local development
if ENV['GEM_ENV'] != 'production'
  lib_path = File.expand_path('../lib', __dir__)
  $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
  require 'kdeploy/post_install'
  Kdeploy::PostInstall.run
end
