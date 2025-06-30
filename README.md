# Kdeploy
```
          _            _
  /\ /\__| | ___ _ __ | | ___  _   _
 / //_/ _` |/ _ \ '_ \| |/ _ \| | | |
/ __ \ (_| |  __/ |_) | | (_) | |_| |
\/  \/\__,_|\___| .__/|_|\___/ \__, |
                |_|            |___/


⚡ Lightweight Agentless Deployment Tool
🚀 Deploy with confidence, scale with ease

```

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
- 🎨 **Color-coded Output**: Green for success, Red for errors, Yellow for warnings

## 📦 Installation

Add this line to your application's Gemfile:

```ruby
gem 'kdeploy'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install kdeploy
```

### Shell Completion

To enable command completion, add the following to your shell config:

For Bash (`~/.bashrc`):
```bash
source "$(gem contents kdeploy | grep kdeploy.bash)"
```

For Zsh (`~/.zshrc`):
```bash
source "$(gem contents kdeploy | grep kdeploy.zsh)"
autoload -Uz compinit && compinit
```

After adding the configuration:
1. For Bash: `source ~/.bashrc`
2. For Zsh: `source ~/.zshrc`

Now you can use Tab completion for:
- Commands: `kdeploy [TAB]`
- File paths: `kdeploy execute [TAB]`
- Options: `kdeploy execute deploy.rb [TAB]`

## 🚀 Quick Start

1. Initialize a new project:

```bash
kdeploy init my-deployment
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
kdeploy execute deploy.rb
```

## 📖 Usage Guide

### Task Execution

```bash
# Execute all tasks in the file
kdeploy execute deploy.rb

# Execute a specific task
kdeploy execute deploy.rb deploy_web

# Execute with dry run (preview mode)
kdeploy execute deploy.rb --dry-run

# Execute on specific hosts
kdeploy execute deploy.rb --limit web01,web02

# Execute with custom parallel count
kdeploy execute deploy.rb --parallel 5
```

When executing without specifying a task name (`kdeploy execute deploy.rb`), Kdeploy will:
1. Execute all defined tasks in the file
2. Run tasks in the order they were defined
3. Show task name before each task execution
4. Display color-coded output for better readability:
   - 🟢 Green: Normal output and success messages
   - 🔴 Red: Errors and failure messages
   - 🟡 Yellow: Warnings and notices

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