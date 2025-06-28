# frozen_string_literal: true

require_relative 'lib/kdeploy/version'

Gem::Specification.new do |spec|
  spec.name = 'kdeploy'
  spec.version = Kdeploy::VERSION
  spec.authors = ['Kdeploy Team']
  spec.email = ['team@kdeploy.dev']

  spec.summary = 'Lightweight agentless deployment tool with DSL, heredoc, and ERB template support'
  spec.description = <<~DESC
    Kdeploy is a lightweight, agentless deployment tool similar to Chef, Puppet, and Ansible.
    It uses Ruby DSL for defining deployment pipelines with support for inventory management,
    parallel execution, SSH-based remote operations, heredoc syntax for multi-line scripts,
    and ERB templates for dynamic configuration generation.
  DESC
  spec.homepage = 'https://github.com/kevin197011/kdeploy'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/kevin197011/kdeploy'
  spec.metadata['changelog_uri'] = 'https://github.com/kevin197011/kdeploy/blob/main/CHANGELOG.md'
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[exe/ test/ spec/ features/ .git .circleci appveyor Gemfile])
    end
  end
  spec.bindir = 'bin'
  spec.executables = spec.files.grep(%r{\Abin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Dependencies
  spec.add_dependency 'colorize', '~> 0.8'
  spec.add_dependency 'concurrent-ruby', '~> 1.2'
  spec.add_dependency 'net-scp', '~> 4.0'
  spec.add_dependency 'net-ssh', '~> 7.0'
  spec.add_dependency 'thor', '~> 1.3'
  spec.add_dependency 'tty-prompt', '~> 0.23'
  spec.add_dependency 'yaml', '~> 0.2'

  # NOTE: Development dependencies are managed in Gemfile
end
