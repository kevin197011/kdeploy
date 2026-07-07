# Kdeploy

```
          _            _
  /\ /\__| | ___ _ __ | | ___  _   _
 / //_/ _` |/ _ \ '_ \| |/ _ \| | | |
/ __ \ (_| |  __/ |_) | | (_) | |_| |
\/  \/\__,_|\___| .__/|_|\___/ \__, |
                |_|            |___/

⚡ 轻量级无代理部署工具
```

用 Ruby DSL 定义主机与任务，通过 SSH/SCP 在多台服务器上并发执行部署与配置，目标机无需安装 agent。

[![Gem Version](https://img.shields.io/gem/v/kdeploy)](https://rubygems.org/gems/kdeploy)
[![Ruby](https://github.com/kevin197011/kdeploy/actions/workflows/gem-push.yml/badge.svg)](https://github.com/kevin197011/kdeploy/actions/workflows/gem-push.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**语言**: [English](README_EN.md) | [中文](README.md)

**详细需求、DSL、API、架构**：见 [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md)

## 功能概览

- 无代理 SSH 远程执行，多主机并发
- Ruby DSL：主机、角色、任务；Chef 风格资源（`package`、`service`、`template`、`sync` 等）
- 文件上传、ERB 模板、目录同步（可选 rsync 快速路径）
- 试运行、JSON 输出、重试/超时策略

**技术栈**：Ruby、Thor、net-ssh、concurrent-ruby

## 安装

要求：Ruby >= 2.7，目标机 SSH 可达。

```bash
gem install kdeploy
kdeploy version
```

Bundler：`gem 'kdeploy'` → `bundle install`

找不到命令时，将 `$(ruby -e 'puts Gem.bindir')` 加入 `PATH`。

## 快速开始

```bash
kdeploy init my-deploy
cd my-deploy
```

编辑 `deploy.rb`：

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

执行：

```bash
kdeploy execute deploy.rb deploy_web --dry-run   # 预览
kdeploy execute deploy.rb deploy_web             # 执行
```

常用选项：`--limit web01`、`--parallel 5`、`--format json`、`--retries 3`。完整选项见 [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md#fr-cli-04-execute-选项)。

**Docker 多机实测**：`cd docker/lab && docker compose --profile test up --build runner`（见 [docker/lab/README.md](docker/lab/README.md)）

## 配置

项目根目录可放 `.kdeploy.yml`（从当前目录向上查找）：

```yaml
parallel: 10
ssh_timeout: 30
verify_host_key: never
retries: 0
```

重试策略示例：`retry_policy.example.json`

## 示例

```bash
cd samples
kdeploy execute deploy.rb deploy_web --dry-run
```

含 Nginx、Node Exporter、目录同步等任务；可用 Vagrant 本地验证。

## 开发

```bash
git clone https://github.com/kevin197011/kdeploy.git && cd kdeploy
bundle install
bundle exec rspec
bundle exec rubocop
```

需求与验收标准：[docs/REQUIREMENTS.md](docs/REQUIREMENTS.md)

## 贡献

Fork → 功能分支 → 测试通过 → PR。提交信息遵循 [Conventional Commits](https://www.conventionalcommits.org/)。

## 许可证

[MIT](https://opensource.org/licenses/MIT)

## 链接

- [GitHub](https://github.com/kevin197011/kdeploy) · [RubyGems](https://rubygems.org/gems/kdeploy) · [Issues](https://github.com/kevin197011/kdeploy/issues)
