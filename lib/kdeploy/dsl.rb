# frozen_string_literal: true

module Kdeploy
  class DSL
    attr_reader :pipeline, :script_dir, :global_variables

    def initialize(script_dir)
      @script_dir = script_dir
      @pipeline = Pipeline.new
      @global_variables = {}
    end

    # 设置变量
    def set(name, value)
      @global_variables[name.to_s] = value
    end

    # 加载主机清单
    def inventory(file)
      inventory_file = File.expand_path(file, script_dir)
      raise ConfigError, "Inventory file not found: #{inventory_file}" unless File.exist?(inventory_file)

      @pipeline.inventory = Inventory.load(inventory_file)
      @global_variables.merge!(@pipeline.inventory.global_variables)
    end

    # 设置模板目录
    def template_dir(dir)
      template_dir = File.expand_path(dir, script_dir)
      raise ConfigError, "Template directory not found: #{template_dir}" unless Dir.exist?(template_dir)

      @pipeline.template_dir = template_dir
    end

    # 定义任务
    def task(name, options = {}, &block)
      task = Task.new(name, options)
      task.global_variables = @global_variables
      task.instance_eval(&block) if block_given?
      @pipeline.add_task(task)
    end

    # 执行本地命令
    def local(command)
      task = Task.new("local_#{command.truncate(20)}")
      task.global_variables = @global_variables
      task.local(command)
      @pipeline.add_task(task)
    end

    # 包含其他脚本
    def include(file)
      script_file = File.expand_path(file, script_dir)
      raise ConfigError, "Script file not found: #{script_file}" unless File.exist?(script_file)

      instance_eval(File.read(script_file), script_file)
    end

    # 导入公共任务
    def import(name)
      script_file = File.join(script_dir, 'scripts', "#{name}.rb")
      raise ConfigError, "Task script not found: #{script_file}" unless File.exist?(script_file)

      instance_eval(File.read(script_file), script_file)
    end

    # 设置角色
    def role(name, hosts)
      @pipeline.inventory.add_role(name, hosts)
    end

    # 设置主机组
    def group(name, hosts)
      @pipeline.inventory.add_group(name, hosts)
    end

    # 设置环境变量
    def env(name, value)
      @global_variables["env_#{name}"] = value
    end

    # 设置标签
    def tag(name, value)
      @global_variables["tag_#{name}"] = value
    end

    # 设置超时时间
    def timeout(seconds)
      @pipeline.timeout = seconds
    end

    # 设置并发数
    def concurrency(number)
      @pipeline.concurrency = number
    end

    # 设置重试次数
    def retries(count)
      @pipeline.retries = count
    end

    # 设置错误处理策略
    def on_error(strategy)
      @pipeline.error_strategy = strategy
    end

    # 设置通知配置
    def notify(config)
      @pipeline.notification_config = config
    end

    # 设置日志级别
    def log_level(level)
      Config.logger.level = level
    end

    # 设置日志文件
    def log_file(file)
      Config.logger.output = File.expand_path(file, script_dir)
    end

    # 设置统计配置
    def stats_config(config)
      @pipeline.stats_config = config
    end

    # 设置健康检查配置
    def health_check(config)
      @pipeline.health_check_config = config
    end

    # 设置备份配置
    def backup_config(config)
      @pipeline.backup_config = config
    end

    # 设置监控配置
    def monitoring_config(config)
      @pipeline.monitoring_config = config
    end

    # 设置告警配置
    def alert_config(config)
      @pipeline.alert_config = config
    end

    # 设置回滚配置
    def rollback_config(config)
      @pipeline.rollback_config = config
    end

    # 设置清理配置
    def cleanup_config(config)
      @pipeline.cleanup_config = config
    end

    # 设置安全配置
    def security_config(config)
      @pipeline.security_config = config
    end

    # 设置性能配置
    def performance_config(config)
      @pipeline.performance_config = config
    end

    # 设置缓存配置
    def cache_config(config)
      @pipeline.cache_config = config
    end

    # 设置代理配置
    def proxy_config(config)
      @pipeline.proxy_config = config
    end

    # 设置SSL配置
    def ssl_config(config)
      @pipeline.ssl_config = config
    end

    # 设置防火墙配置
    def firewall_config(config)
      @pipeline.firewall_config = config
    end

    # 设置负载均衡配置
    def load_balancer_config(config)
      @pipeline.load_balancer_config = config
    end

    # 设置服务发现配置
    def service_discovery_config(config)
      @pipeline.service_discovery_config = config
    end

    # 设置容器配置
    def container_config(config)
      @pipeline.container_config = config
    end

    # 设置数据库配置
    def database_config(config)
      @pipeline.database_config = config
    end

    # 设置缓存配置
    def cache_config(config)
      @pipeline.cache_config = config
    end

    # 设置消息队列配置
    def queue_config(config)
      @pipeline.queue_config = config
    end

    # 设置存储配置
    def storage_config(config)
      @pipeline.storage_config = config
    end

    # 设置CDN配置
    def cdn_config(config)
      @pipeline.cdn_config = config
    end

    # 设置DNS配置
    def dns_config(config)
      @pipeline.dns_config = config
    end

    # 设置邮件配置
    def mail_config(config)
      @pipeline.mail_config = config
    end

    # 设置短信配置
    def sms_config(config)
      @pipeline.sms_config = config
    end

    # 设置推送配置
    def push_config(config)
      @pipeline.push_config = config
    end

    # 设置支付配置
    def payment_config(config)
      @pipeline.payment_config = config
    end

    # 设置认证配置
    def auth_config(config)
      @pipeline.auth_config = config
    end

    # 设置授权配置
    def authorization_config(config)
      @pipeline.authorization_config = config
    end

    # 设置审计配置
    def audit_config(config)
      @pipeline.audit_config = config
    end

    # 设置日志配置
    def logging_config(config)
      @pipeline.logging_config = config
    end

    # 设置监控配置
    def monitoring_config(config)
      @pipeline.monitoring_config = config
    end

    # 设置追踪配置
    def tracing_config(config)
      @pipeline.tracing_config = config
    end

    # 设置指标配置
    def metrics_config(config)
      @pipeline.metrics_config = config
    end

    # 设置告警配置
    def alerting_config(config)
      @pipeline.alerting_config = config
    end

    # 设置仪表盘配置
    def dashboard_config(config)
      @pipeline.dashboard_config = config
    end
  end
end
