# frozen_string_literal: true

require 'fileutils'
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)
require_relative 'lib/kdeploy/version'

task default: %w[push]

desc 'Install the gem locally'
task :run do
  system('gem uninstall kdeploy -aIx') || true
  system('gem build kdeploy.gemspec') || abort('build failed')
  system("gem install kdeploy-#{Kdeploy::VERSION}.gem") || abort('install failed')
  system('kdeploy --version')
end

desc 'Clean up generated files'
task :clean do
  FileUtils.rm_f Dir.glob('*.gem')
  FileUtils.rm_rf 'pkg'
end

desc 'Bump version (patch/minor/major)'
task :bump, [:type] do |_t, args|
  type = (args[:type] || 'patch').to_sym
  old_v = Kdeploy::VERSION
  new_v = bump_and_save(type)
  puts "✅ #{old_v} -> #{new_v}"
end

desc 'Push with auto patch bump'
task push: :clean do
  system('bundle exec rubocop -A') || abort('rubocop failed')
  old_v = Kdeploy::VERSION
  new_v = bump_and_save(:patch)
  system('git add .') || abort('git add failed')
  system("git commit -m 'chore: bump to #{new_v}'") || abort('git commit failed')
  system('git pull') || abort('git pull failed')
  system('git push') || abort('git push failed')
  puts "✅ Pushed #{new_v} (was #{old_v})"
end

def bump_and_save(type)
  major, minor, patch = Kdeploy::VERSION.split('.').map(&:to_i)
  new_v = case type
          when :major then "#{major + 1}.0.0"
          when :minor then "#{major}.#{minor + 1}.0"
          when :patch then "#{major}.#{minor}.#{patch + 1}"
          else raise ArgumentError, "Invalid: #{type}. Use :major, :minor, :patch"
          end
  path = 'lib/kdeploy/version.rb'
  File.write(path, File.read(path).sub(/VERSION = ['"][\d.]+['"]/, "VERSION = '#{new_v}'"))
  load path
  new_v
end
