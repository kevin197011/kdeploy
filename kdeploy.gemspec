# frozen_string_literal: true

require_relative 'lib/kdeploy/version'

Gem::Specification.new do |spec|
  spec.name = 'kdeploy'
  spec.version = Kdeploy::VERSION
  spec.authors = ['Norton']
  spec.email = ['kevin197011@outlook.com']

  spec.summary = 'A lightweight agentless deployment tool'
  spec.description = 'Kdeploy is a Ruby-based deployment automation tool that provides agentless remote deployment solutions with an elegant DSL'
  spec.homepage = 'https://github.com/kevin197011/kdeploy'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata = {
    'homepage_uri' => 'https://github.com/kevin197011/kdeploy',
    'source_code_uri' => 'https://github.com/kevin197011/kdeploy.git',
    'changelog_uri' => 'https://github.com/kevin197011/kdeploy/blob/main/CHANGELOG.md',
    'rubygems_mfa_required' => 'true'
  }

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob(%w[
                          lib/**/*
                          exe/*
                          *.md
                          *.txt
                        ]).reject { |f| File.directory?(f) }

  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Dependencies
  spec.add_dependency 'concurrent-ruby', '~> 1.2'
  spec.add_dependency 'net-scp', '~> 4.0'
  spec.add_dependency 'net-ssh', '~> 7.0'
  spec.add_dependency 'pastel', '~> 0.8'
  spec.add_dependency 'thor', '~> 1.2'
  spec.add_dependency 'tty-box', '~> 0.7'
  spec.add_dependency 'tty-table', '~> 0.12'

  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 1.21'

  # Post install message
  spec.post_install_message = <<~MESSAGE
    🎉 Thanks for installing kdeploy!

    To enable command completion, add the following to your shell config:

    For Bash (~/.bashrc):
      source "$(gem contents kdeploy | grep kdeploy.bash)"

    For Zsh (~/.zshrc):
      source "$(gem contents kdeploy | grep kdeploy.zsh)"
      autoload -Uz compinit && compinit

    Happy deploying! 🚀
  MESSAGE

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
