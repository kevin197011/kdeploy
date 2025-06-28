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
  system 'bundle exec rubocop'
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
  system 'bundle exec yard doc'
end

# Clean build artifacts
task :clean do
  system 'rm -f *.gem'
  system 'rm -rf doc/'
  system 'rm -rf coverage/'
end

# Install gem locally
task :install do
  system 'gem build ./kdeploy.gemspec'
  system "gem install ./kdeploy-#{Kdeploy::VERSION}.gem"
end
