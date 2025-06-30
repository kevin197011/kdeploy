# frozen_string_literal: true

module Kdeploy
  class Task
    attr_reader :name, :commands, :roles, :options
    attr_accessor :global_variables

    def initialize(name, options = {})
      @name = name
      @commands = []
      @roles = Array(options[:on] || :all)
      @options = options
      @global_variables = {}
    end

    # 执行远程命令
    def run(command, options = {})
      cmd = Command.new(command, options)
      cmd.validate_variables(@global_variables)
      @commands << cmd
    end

    # 执行本地命令
    def local(command, options = {})
      cmd = Command.new(command, options.merge(local: true))
      cmd.validate_variables(@global_variables)
      @commands << cmd
    end

    # 上传文件
    def upload(source, target, options = {})
      cmd = Command.new("upload:#{source}:#{target}", options.merge(type: :upload))
      cmd.source = source
      cmd.target = target
      cmd.validate_variables(@global_variables)
      @commands << cmd
    end

    # 上传模板
    def upload_template(source, target, options = {})
      cmd = Command.new("template:#{source}:#{target}", options.merge(type: :template))
      cmd.source = source
      cmd.target = target
      cmd.validate_variables(@global_variables)
      @commands << cmd
    end

    # 下载文件
    def download(source, target, options = {})
      cmd = Command.new("download:#{source}:#{target}", options.merge(type: :download))
      cmd.source = source
      cmd.target = target
      cmd.validate_variables(@global_variables)
      @commands << cmd
    end

    # 执行任务
    def invoke(task_name)
      cmd = Command.new("invoke:#{task_name}", type: :invoke)
      cmd.task_name = task_name
      @commands << cmd
    end

    # 执行脚本
    def script(content, options = {})
      cmd = Command.new(content, options.merge(type: :script))
      cmd.validate_variables(@global_variables)
      @commands << cmd
    end

    # 执行Ruby代码
    def ruby(code, options = {})
      cmd = Command.new(code, options.merge(type: :ruby))
      cmd.validate_variables(@global_variables)
      @commands << cmd
    end

    # 执行Python代码
    def python(code, options = {})
      cmd = Command.new(code, options.merge(type: :python))
      cmd.validate_variables(@global_variables)
      @commands << cmd
    end

    # 执行Node.js代码
    def node(code, options = {})
      cmd = Command.new(code, options.merge(type: :node))
      cmd.validate_variables(@global_variables)
      @commands << cmd
    end

    # 执行Shell脚本
    def shell(script, options = {})
      cmd = Command.new(script, options.merge(type: :shell))
      cmd.validate_variables(@global_variables)
      @commands << cmd
    end

    # 执行Ansible
    def ansible(playbook, options = {})
      cmd = Command.new(playbook, options.merge(type: :ansible))
      cmd.validate_variables(@global_variables)
      @commands << cmd
    end

    # 执行Docker命令
    def docker(command, options = {})
      cmd = Command.new(command, options.merge(type: :docker))
      cmd.validate_variables(@global_variables)
      @commands << cmd
    end

    # 执行Kubernetes命令
    def kubectl(command, options = {})
      cmd = Command.new(command, options.merge(type: :kubectl))
      cmd.validate_variables(@global_variables)
      @commands << cmd
    end

    # 执行数据库命令
    def database(command, options = {})
      cmd = Command.new(command, options.merge(type: :database))
      cmd.validate_variables(@global_variables)
      @commands << cmd
    end

    # 执行Redis命令
    def redis(command, options = {})
      cmd = Command.new(command, options.merge(type: :redis))
      cmd.validate_variables(@global_variables)
      @commands << cmd
    end

    # 执行HTTP请求
    def http(request, options = {})
      cmd = Command.new(request, options.merge(type: :http))
      cmd.validate_variables(@global_variables)
      @commands << cmd
    end

    # 执行WebSocket请求
    def websocket(request, options = {})
      cmd = Command.new(request, options.merge(type: :websocket))
      cmd.validate_variables(@global_variables)
      @commands << cmd
    end

    # 执行gRPC请求
    def grpc(request, options = {})
      cmd = Command.new(request, options.merge(type: :grpc))
      cmd.validate_variables(@global_variables)
      @commands << cmd
    end

    # 执行GraphQL请求
    def graphql(query, options = {})
      cmd = Command.new(query, options.merge(type: :graphql))
      cmd.validate_variables(@global_variables)
      @commands << cmd
    end

    # 执行邮件发送
    def mail(message, options = {})
      cmd = Command.new(message, options.merge(type: :mail))
      cmd.validate_variables(@global_variables)
      @commands << cmd
    end

    # 执行短信发送
    def sms(message, options = {})
      cmd = Command.new(message, options.merge(type: :sms))
      cmd.validate_variables(@global_variables)
      @commands << cmd
    end

    # 执行推送通知
    def push(notification, options = {})
      cmd = Command.new(notification, options.merge(type: :push))
      cmd.validate_variables(@global_variables)
      @commands << cmd
    end

    # 执行支付操作
    def payment(transaction, options = {})
      cmd = Command.new(transaction, options.merge(type: :payment))
      cmd.validate_variables(@global_variables)
      @commands << cmd
    end

    # 执行认证操作
    def auth(credentials, options = {})
      cmd = Command.new(credentials, options.merge(type: :auth))
      cmd.validate_variables(@global_variables)
      @commands << cmd
    end

    # 执行授权操作
    def authorize(permission, options = {})
      cmd = Command.new(permission, options.merge(type: :authorize))
      cmd.validate_variables(@global_variables)
      @commands << cmd
    end

    # 执行审计操作
    def audit(event, options = {})
      cmd = Command.new(event, options.merge(type: :audit))
      cmd.validate_variables(@global_variables)
      @commands << cmd
    end

    # 执行日志记录
    def log(message, options = {})
      cmd = Command.new(message, options.merge(type: :log))
      cmd.validate_variables(@global_variables)
      @commands << cmd
    end

    # 执行监控操作
    def monitor(metric, options = {})
      cmd = Command.new(metric, options.merge(type: :monitor))
      cmd.validate_variables(@global_variables)
      @commands << cmd
    end

    # 执行追踪操作
    def trace(span, options = {})
      cmd = Command.new(span, options.merge(type: :trace))
      cmd.validate_variables(@global_variables)
      @commands << cmd
    end

    # 执行指标收集
    def metric(data, options = {})
      cmd = Command.new(data, options.merge(type: :metric))
      cmd.validate_variables(@global_variables)
      @commands << cmd
    end

    # 执行告警操作
    def alert(alarm, options = {})
      cmd = Command.new(alarm, options.merge(type: :alert))
      cmd.validate_variables(@global_variables)
      @commands << cmd
    end

    # 执行仪表盘操作
    def dashboard(data, options = {})
      cmd = Command.new(data, options.merge(type: :dashboard))
      cmd.validate_variables(@global_variables)
      @commands << cmd
    end

    # 验证变量
    def validate_variables
      missing_vars = Set.new

      @commands.each do |cmd|
        cmd.validate_variables(@global_variables)
        missing_vars.merge(cmd.missing_variables)
      end

      return if missing_vars.empty?

      Config.logger.error("Missing required variables: #{missing_vars.to_a.join(', ')}")
      Config.logger.error("Available variables: #{@global_variables.keys.join(', ')}")
      raise ValidationError, "Missing required variables: #{missing_vars.to_a.join(', ')}"
    end

    # 执行任务
    def execute(host)
      Config.logger.info("Executing task '#{name}' on #{host.hostname}")
      start_time = Time.now

      @commands.each do |cmd|
        cmd.execute(host)
      end

      duration = Time.now - start_time
      Config.logger.info("Task '#{name}' completed in #{duration.round(2)}s")
    rescue StandardError => e
      Config.logger.error("Task '#{name}' failed: #{e.message}")
      raise ExecutionError, "Task '#{name}' failed: #{e.message}"
    end
  end
end
