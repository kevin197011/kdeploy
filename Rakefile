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

desc 'Bump version (patch/minor/major)'
task :bump, [:type] do |_t, args|
  type = (args[:type] || 'patch').to_sym
  old_version = Kdeploy::VERSION
  new_version = bump_version(type)
  update_version_file(new_version)

  # Reload version to get updated value
  load 'lib/kdeploy/version.rb'

  puts "✅ Version bumped from #{old_version} to #{new_version}"
end

desc 'Push changes with auto version bump'
task :push do
  Rake::Task['clean'].invoke
  system 'rubocop -A'

  # Auto bump patch version
  old_version = Kdeploy::VERSION
  new_version = bump_version(:patch)
  update_version_file(new_version)

  # Reload version to get updated value
  load 'lib/kdeploy/version.rb'

  system 'git add .'
  system "git commit -m 'chore: bump version from #{old_version} to #{new_version}'"
  system 'git pull'
  system 'git push'

  puts "✅ Pushed with version #{new_version} (was #{old_version})"
end

def bump_version(type = :patch)
  current = Kdeploy::VERSION
  major, minor, patch = current.split('.').map(&:to_i)

  case type
  when :major
    "#{major + 1}.0.0"
  when :minor
    "#{major}.#{minor + 1}.0"
  when :patch
    "#{major}.#{minor}.#{patch + 1}"
  else
    raise ArgumentError, "Invalid version type: #{type}. Use :major, :minor, or :patch"
  end
end

def update_version_file(new_version)
  version_file = 'lib/kdeploy/version.rb'
  content = File.read(version_file)
  updated_content = content.gsub(/VERSION = ['"][\d.]+['"]/, "VERSION = '#{new_version}'")
  File.write(version_file, updated_content)
end
