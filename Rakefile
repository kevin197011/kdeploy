# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

require_relative 'lib/kdeploy/version'

task default: %w[push]

desc 'Install the gem locally'
task :install do
  system 'gem uninstall kdeploy -aIx'
  system 'gem build kdeploy.gemspec'
  system "gem install kdeploy-#{Kdeploy::VERSION}.gem"
end

desc 'Clean up generated files'
task :clean do
  FileUtils.rm_f Dir.glob('*.gem')
  FileUtils.rm_f 'pkg'
end

task :push do
  Rake::Task['clean'].invoke
  system 'rubocop -A'
  system 'git add .'
  system "git commit -m 'Update #{Time.now}'"
  system 'git pull'
  system 'git push'
end
