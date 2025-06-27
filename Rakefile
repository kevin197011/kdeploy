# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'time'

# Default task runs tests and RuboCop, then pushes code
task default: %w[push]

# Run RSpec tests
RSpec::Core::RakeTask.new(:test) do |spec|
  spec.pattern = 'spec/**{,/*/**}/*_spec.rb'
end

# Run RuboCop
task :rubocop do
  sh 'bundle exec rubocop'
end

# Auto-commit and push changes
task :push do
  system 'bundle exec rubocop -A'
  system 'git add .'
  system "git commit -m 'Update #{Time.now}'"
  system 'git pull'
  system 'git push'
end

# Documentation task
task :doc do
  sh 'bundle exec yard doc'
end

# Build gem
task :build do
  sh 'gem build kdeploy.gemspec'
end

# Install gem locally
task install: :build do
  sh "gem install kdeploy-#{Kdeploy::VERSION}.gem"
end

# Clean build artifacts
task :clean do
  sh 'rm -f *.gem'
  sh 'rm -rf doc/'
  sh 'rm -rf coverage/'
end

# Install gem locally
task :install do
  sh 'gem build kdeploy.gemspec'
  sh "gem install kdeploy-#{Kdeploy::VERSION}.gem"
end
