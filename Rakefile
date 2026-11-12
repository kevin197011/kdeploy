# frozen_string_literal: true

# Copyright (c) 2025 kk
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

require 'fileutils'
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require_relative 'lib/kdeploy/version'

RSpec::Core::RakeTask.new(:spec)

namespace :rubocop do
  desc 'Run RuboCop'
  task :check do
    sh 'bundle exec rubocop'
  end

  desc 'Run RuboCop with autocorrect'
  task :auto do
    sh 'bundle exec rubocop -A'
  end
end

desc 'Run RuboCop'
task rubocop: 'rubocop:check'

task default: :spec

desc 'Reinstall gem locally (uninstall → build → install from pkg/)'
task :run do
  sh 'gem uninstall kdeploy -aIx || true'
  Rake::Task['build'].invoke
  gem_path = File.join('pkg', "kdeploy-#{Kdeploy::VERSION}.gem")
  abort "missing #{gem_path}" unless File.exist?(gem_path)
  sh "gem install #{gem_path}"
  sh 'kdeploy --version'
end

desc 'Remove root *.gem leftovers (pkg/ is handled by clobber)'
task :clean_gems do
  FileUtils.rm_f Dir.glob('*.gem')
end

desc 'Bump version (patch/minor/major). Example: rake bump[minor]'
task :bump, [:type] do |_t, args|
  type = (args[:type] || 'patch').to_sym
  old_v = Kdeploy::VERSION
  new_v = bump_and_save!(type)
  puts "#{old_v} -> #{new_v}"
end

desc 'Maintainer release: rubocop -A, spec, patch bump, commit version, push'
task push: :clean_gems do
  Rake::Task['rubocop:auto'].invoke
  Rake::Task[:spec].invoke

  old_v = Kdeploy::VERSION
  new_v = bump_and_save!(:patch)

  sh 'git add lib/kdeploy/version.rb'
  sh "git commit -m 'chore: bump to #{new_v}'"
  sh 'git pull --rebase'
  sh 'git push'
  puts "Pushed #{new_v} (was #{old_v})"
end

def bump_and_save!(type)
  major, minor, patch = Kdeploy::VERSION.split('.').map(&:to_i)
  new_v =
    case type
    when :major then "#{major + 1}.0.0"
    when :minor then "#{major}.#{minor + 1}.0"
    when :patch then "#{major}.#{minor}.#{patch + 1}"
    else
      raise ArgumentError, "Invalid bump type: #{type} (use major/minor/patch)"
    end

  path = File.expand_path('lib/kdeploy/version.rb', __dir__)
  contents = File.read(path)
  updated = contents.sub(/VERSION = ['"][\d.]+['"]/, "VERSION = '#{new_v}'")
  raise "VERSION assignment not found in #{path}" if updated == contents

  File.write(path, updated)
  Kdeploy.send(:remove_const, :VERSION) if Kdeploy.const_defined?(:VERSION, false)
  load path
  raise "VERSION reload mismatch: #{Kdeploy::VERSION} != #{new_v}" unless new_v == Kdeploy::VERSION

  new_v
end
