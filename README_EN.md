# Kdeploy

```
          _            _
  /\ /\__| | ___ _ __ | | ___  _   _
 / //_/ _` |/ _ \ '_ \| |/ _ \| | | |
/ __ \ (_| |  __/ |_) | | (_) | |_| |
\/  \/\__,_|\___| .__/|_|\___/ \__, |
                |_|            |___/

⚡ Lightweight Agentless Deployment Tool
```

Define hosts and tasks in Ruby DSL; execute deployments and configuration across servers via SSH/SCP with no agent on targets.

[![Gem Version](https://img.shields.io/gem/v/kdeploy)](https://rubygems.org/gems/kdeploy)
[![Ruby](https://github.com/kevin197011/kdeploy/actions/workflows/gem-push.yml/badge.svg)](https://github.com/kevin197011/kdeploy/actions/workflows/gem-push.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Language**: [English](README_EN.md) | [中文](README.md)

**Full requirements, DSL, API, architecture**: [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md)

## Features

- Agentless SSH execution with multi-host concurrency
- Ruby DSL: hosts, roles, tasks; Chef-style resources (`package`, `service`, `template`, `sync`, etc.)
- File upload, ERB templates, directory sync (optional rsync fast path)
- Dry-run, JSON output/`--report`, `--tags` / `--extra-vars`, `wait_*` / `on_failure`, retry/timeout policies

**Stack**: Ruby, Thor, net-ssh, concurrent-ruby

## Installation

Requires Ruby >= 2.7 and SSH access to targets.

```bash
gem install kdeploy
kdeploy version
```

With Bundler: add `gem 'kdeploy'` and run `bundle install`.

If `kdeploy` is not found, add `$(ruby -e 'puts Gem.bindir')` to your `PATH`.

## Quick Start

```bash
kdeploy init my-deploy
cd my-deploy
```

Edit `deploy.rb`:

```ruby
host "web01", user: "ubuntu", ip: "10.0.0.1", key: "~/.ssh/id_rsa"
role :web, %w[web01]

task :deploy_web, roles: :web do
  package "nginx"
  template "/etc/nginx/nginx.conf", source: "./config/nginx.conf.erb", variables: { port: 3000 }
  run "nginx -t", sudo: true
  service "nginx", action: %i[enable restart]
end
```

Run:

```bash
kdeploy execute deploy.rb deploy_web --dry-run   # preview
kdeploy execute deploy.rb deploy_web             # execute
```

Common flags: `--limit web01`, `--parallel 5`, `--format json`, `--retries 3`. See [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md#fr-cli-04-execute-选项) for all options.

**Docker multi-host lab**: `cd docker/lab && docker compose --profile test up --build runner` ([docker/lab/README.md](docker/lab/README.md))

## Configuration

Place `.kdeploy.yml` in your project (walks up from CWD). Retry policy examples: `retry_policy.example.json`

## Non-goals

Kdeploy is **not** an Ansible/Chef convergence engine and has **no** Web UI / agent. See [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md).

## Security

- Default `verify_host_key` is `accept_new`. Prefer `always` for locked fleets; use `never` only for ephemeral labs.
- Prefer SSH keys and NOPASSWD sudo; treat task files with passwords as secrets.
- See [SECURITY.md](SECURITY.md)

Example:

```yaml
parallel: 10
ssh_timeout: 30
# Production:
verify_host_key: accept_new
retries: 0
```

## Samples

```bash
cd samples
kdeploy execute deploy.rb deploy_web --dry-run
```

Includes Nginx, Node Exporter, directory sync; Vagrant available for local testing.

## Development

```bash
git clone git@github.com:kevin197011/kdeploy.git && cd kdeploy
bundle install
bundle exec rspec
bundle exec rubocop
```

Requirements and acceptance criteria: [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Fork → feature branch → tests pass → PR. Use [Conventional Commits](https://www.conventionalcommits.org/).

## License

[MIT](LICENSE) · [Changelog](CHANGELOG.md) · [Security](SECURITY.md) · [Contributing](CONTRIBUTING.md)

## Links

- [GitHub](https://github.com/kevin197011/kdeploy) · [RubyGems](https://rubygems.org/gems/kdeploy) · [Issues](https://github.com/kevin197011/kdeploy/issues)
