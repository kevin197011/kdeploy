# Kdeploy

A lightweight agentless deployment automation tool written in Ruby.

## 🌟 Features

- 🔑 **Agentless Remote Deployment**: Uses SSH for secure remote execution
- 📝 **Elegant Ruby DSL**: Simple and expressive task definition
- 🚀 **Concurrent Execution**: Efficient parallel task processing
- 📤 **File Upload Support**: Easy file and template deployment
- 📊 **Task Status Tracking**: Real-time execution monitoring
- 🔄 **ERB Template Support**: Dynamic configuration generation
- 🎯 **Role-based Deployment**: Target specific server roles
- 🔍 **Dry Run Mode**: Preview tasks before execution

## 📦 Installation

Add this line to your application's Gemfile:

```ruby
gem 'kdeploy'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install kdeploy
```

## 🚀 Quick Start

1. Initialize a new project:

```bash
$ kdeploy init my-deployment
```

2. Edit the deployment configuration:

```ruby
# deploy.rb

# Define hosts
host "web01", user: "ubuntu", ip: "10.0.0.1", key: "~/.ssh/id_rsa"
host "web02", user: "ubuntu", ip: "10.0.0.2", key: "~/.ssh/id_rsa"

# Define roles
role :web, %w[web01 web02]

# Define tasks
task :deploy, roles: :web do
  run "sudo systemctl stop nginx"
  upload_template "./config/nginx.conf.erb", "/etc/nginx/nginx.conf",
    domain_name: "example.com",
    port: 3000
  run "sudo systemctl start nginx"
end
```

3. Run the deployment:

```bash
$ kdeploy execute deploy.rb
```

## 📖 Usage Guide

### Host Definition

```ruby
# Single host
host "web01",
  user: "ubuntu",
  ip: "10.0.0.1",
  key: "~/.ssh/id_rsa"

# Multiple hosts
%w[web01 web02 web03].each do |name|
  host name,
    user: "ubuntu",
    ip: "10.0.0.#{name[-1]}",
    key: "~/.ssh/id_rsa"
end
```

### Role Management

```ruby
# Define roles
role :web, %w[web01 web02]
role :db, %w[db01 db02]
role :all, %w[web01 web02 db01 db02]

# Use roles in tasks
task :deploy_web, roles: :web do
  # Tasks for web servers
end

task :backup_db, roles: :db do
  # Tasks for database servers
end
```

### Task Definition

```ruby
# Basic task
task :simple do
  run "echo 'Hello, World!'"
end

# Role-based task
task :deploy, roles: :web do
  run "sudo systemctl stop nginx"
  upload "./config/nginx.conf", "/etc/nginx/nginx.conf"
  run "sudo systemctl start nginx"
end

# Host-specific task
task :maintenance, on: %w[web01] do
  run "sudo apt-get update"
  run "sudo apt-get upgrade -y"
end
```

### Template Support

Create an ERB template (`config/nginx.conf.erb`):

```erb
server {
    listen 80;
    server_name <%= domain_name %>;

    location / {
        proxy_pass http://localhost:<%= port %>;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

Use the template in your task:

```ruby
task :deploy_config do
  upload_template "./config/nginx.conf.erb", "/etc/nginx/sites-available/myapp.conf",
    domain_name: "example.com",
    port: 3000
end
```

### Command Line Options

```bash
# Execute with dry run
kdeploy execute deploy.rb --dry-run

# Limit to specific hosts
kdeploy execute deploy.rb --limit web01,web02

# Set parallel execution count
kdeploy execute deploy.rb --parallel 5

# Execute specific task
kdeploy execute deploy.rb deploy_web
```

## 🔧 Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## 🤝 Contributing

1. Fork it
2. Create your feature branch (`git checkout -b feature/my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/my-new-feature`)
5. Create a new Pull Request

## 📝 License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## 🔍 Code of Conduct

Everyone interacting in the Kdeploy project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/kdeploy/blob/main/CODE_OF_CONDUCT.md).