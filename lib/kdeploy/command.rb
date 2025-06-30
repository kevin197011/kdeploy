# frozen_string_literal: true

module Kdeploy
  class Command
    attr_reader :command, :options, :result, :type
    attr_accessor :source, :target, :task_name

    def initialize(command, options = {})
      @command = command
      @options = default_options.merge(options)
      @type = @options.delete(:type) || :command
      @result = nil
      @missing_variables = Set.new
    end

    # 验证变量
    def validate_variables(variables)
      @missing_variables.clear
      template_variables.each do |var|
        @missing_variables << var unless variables.key?(var)
      end
    end

    # 获取缺失的变量
    attr_reader :missing_variables

    # 执行命令
    def execute(host)
      start_time = Time.now

      # 处理命令模板
      processed_command = process_command_template(host)

      # 根据命令类型执行不同的操作
      @result = case @type
                when :command
                  execute_command(host, processed_command)
                when :local
                  execute_local_command(processed_command)
                when :upload
                  upload_file(host)
                when :download
                  download_file(host)
                when :template
                  upload_template(host)
                when :script
                  execute_script(host, processed_command)
                when :ruby
                  execute_ruby(processed_command)
                when :python
                  execute_python(processed_command)
                when :node
                  execute_node(processed_command)
                when :shell
                  execute_shell(host, processed_command)
                when :ansible
                  execute_ansible(processed_command)
                when :docker
                  execute_docker(processed_command)
                when :kubectl
                  execute_kubectl(processed_command)
                when :database
                  execute_database(processed_command)
                when :redis
                  execute_redis(processed_command)
                when :http
                  execute_http(processed_command)
                when :websocket
                  execute_websocket(processed_command)
                when :grpc
                  execute_grpc(processed_command)
                when :graphql
                  execute_graphql(processed_command)
                when :mail
                  execute_mail(processed_command)
                when :sms
                  execute_sms(processed_command)
                when :push
                  execute_push(processed_command)
                when :payment
                  execute_payment(processed_command)
                when :auth
                  execute_auth(processed_command)
                when :authorize
                  execute_authorize(processed_command)
                when :audit
                  execute_audit(processed_command)
                when :log
                  execute_log(processed_command)
                when :monitor
                  execute_monitor(processed_command)
                when :trace
                  execute_trace(processed_command)
                when :metric
                  execute_metric(processed_command)
                when :alert
                  execute_alert(processed_command)
                when :dashboard
                  execute_dashboard(processed_command)
                else
                  raise ExecutionError, "Unknown command type: #{@type}"
                end

      duration = Time.now - start_time
      log_result(host, duration)

      @result
    rescue StandardError => e
      duration = Time.now - start_time
      Config.logger.error("Command failed after #{duration.round(2)}s: #{e.message}")
      raise ExecutionError, e.message unless @options[:ignore_errors]

      {
        success: false,
        error: e.message,
        duration: duration
      }
    end

    # Check if command should run on host
    # @param host [Host] Target host
    # @return [Boolean] True if command should run
    def should_run_on?(host)
      return true unless @options[:only] || @options[:except]

      if @options[:only]
        roles = Array(@options[:only])
        return roles.any? { |role| host.has_role?(role) }
      end

      if @options[:except]
        roles = Array(@options[:except])
        return roles.none? { |role| host.has_role?(role) }
      end

      true
    end

    def result
      @result || {
        stdout: '',
        stderr: '',
        exit_code: nil,
        success: false
      }
    end

    private

    def default_options
      {
        timeout: 300,
        retry_count: 3,
        retry_delay: 5,
        ignore_errors: false,
        parallel: false,
        sudo: false,
        env: {},
        cwd: nil
      }
    end

    def template_variables
      variables = []
      @command.scan(/\{\{([^}]+)\}\}|\$\{([^}]+)\}/) do |match|
        variables << (match[0] || match[1])
      end
      variables.uniq
    end

    def process_command_template(host)
      template = @command.dup

      # 替换主机变量
      if host
        host.vars.each do |key, value|
          template.gsub!(/\{\{#{key}\}\}|\$\{#{key}\}/, value.to_s)
        end
      end

      # 替换环境变量
      @options[:env].each do |key, value|
        template.gsub!(/\{\{env_#{key}\}\}|\$\{env_#{key}\}/, value.to_s)
      end

      template
    end

    def execute_command(host, command)
      return execute_local_command(command) if @options[:local]

      connection = host.connection
      connection.execute(command, @options)
    end

    def execute_local_command(command)
      require 'open3'
      stdout, stderr, status = Open3.capture3(command)
      {
        success: status.success?,
        stdout: stdout,
        stderr: stderr,
        exit_code: status.exitstatus
      }
    end

    def upload_file(host)
      connection = host.connection
      connection.upload(@source, @target)
      { success: true }
    end

    def download_file(host)
      connection = host.connection
      connection.download(@source, @target)
      { success: true }
    end

    def upload_template(host)
      template = Template.new(@source, host.vars)
      content = template.render
      temp_file = Tempfile.new('kdeploy')
      temp_file.write(content)
      temp_file.close

      connection = host.connection
      connection.upload(temp_file.path, @target)
      { success: true }
    ensure
      temp_file&.unlink
    end

    def execute_script(host, script)
      temp_file = Tempfile.new(['kdeploy', '.sh'])
      temp_file.write(script)
      temp_file.close

      connection = host.connection
      connection.upload(temp_file.path, '/tmp/kdeploy_script.sh')
      connection.execute('chmod +x /tmp/kdeploy_script.sh')
      result = connection.execute('/tmp/kdeploy_script.sh')
      connection.execute('rm -f /tmp/kdeploy_script.sh')
      result
    ensure
      temp_file&.unlink
    end

    def execute_ruby(code)
      eval(code) # rubocop:disable Security/Eval
      { success: true }
    end

    def execute_python(code)
      require 'open3'
      stdout, stderr, status = Open3.capture3('python3', '-c', code)
      {
        success: status.success?,
        stdout: stdout,
        stderr: stderr,
        exit_code: status.exitstatus
      }
    end

    def execute_node(code)
      require 'open3'
      stdout, stderr, status = Open3.capture3('node', '-e', code)
      {
        success: status.success?,
        stdout: stdout,
        stderr: stderr,
        exit_code: status.exitstatus
      }
    end

    def execute_shell(host, script)
      execute_script(host, script)
    end

    def execute_ansible(playbook)
      require 'open3'
      stdout, stderr, status = Open3.capture3('ansible-playbook', playbook)
      {
        success: status.success?,
        stdout: stdout,
        stderr: stderr,
        exit_code: status.exitstatus
      }
    end

    def execute_docker(command)
      require 'open3'
      stdout, stderr, status = Open3.capture3('docker', *command.split)
      {
        success: status.success?,
        stdout: stdout,
        stderr: stderr,
        exit_code: status.exitstatus
      }
    end

    def execute_kubectl(command)
      require 'open3'
      stdout, stderr, status = Open3.capture3('kubectl', *command.split)
      {
        success: status.success?,
        stdout: stdout,
        stderr: stderr,
        exit_code: status.exitstatus
      }
    end

    def execute_database(_command)
      # 实现数据库命令执行
      { success: true }
    end

    def execute_redis(_command)
      # 实现Redis命令执行
      { success: true }
    end

    def execute_http(_request)
      # 实现HTTP请求执行
      { success: true }
    end

    def execute_websocket(_request)
      # 实现WebSocket请求执行
      { success: true }
    end

    def execute_grpc(_request)
      # 实现gRPC请求执行
      { success: true }
    end

    def execute_graphql(_query)
      # 实现GraphQL查询执行
      { success: true }
    end

    def execute_mail(_message)
      # 实现邮件发送
      { success: true }
    end

    def execute_sms(_message)
      # 实现短信发送
      { success: true }
    end

    def execute_push(_notification)
      # 实现推送通知
      { success: true }
    end

    def execute_payment(_transaction)
      # 实现支付操作
      { success: true }
    end

    def execute_auth(_credentials)
      # 实现认证操作
      { success: true }
    end

    def execute_authorize(_permission)
      # 实现授权操作
      { success: true }
    end

    def execute_audit(_event)
      # 实现审计操作
      { success: true }
    end

    def execute_log(message)
      Config.logger.info(message)
      { success: true }
    end

    def execute_monitor(_metric)
      # 实现监控操作
      { success: true }
    end

    def execute_trace(_span)
      # 实现追踪操作
      { success: true }
    end

    def execute_metric(_data)
      # 实现指标收集
      { success: true }
    end

    def execute_alert(_alarm)
      # 实现告警操作
      { success: true }
    end

    def execute_dashboard(_data)
      # 实现仪表盘操作
      { success: true }
    end

    def log_result(host, duration)
      if @result[:success]
        Config.logger.info("✅ Command completed on #{host&.hostname} in #{duration.round(2)}s")
        unless @result[:stdout].to_s.empty?
          Config.logger.debug('Output:')
          @result[:stdout].to_s.each_line { |line| Config.logger.debug("  #{line.chomp}") }
        end
      else
        Config.logger.error("❌ Command failed on #{host&.hostname} after #{duration.round(2)}s")
        unless @result[:stderr].to_s.empty?
          Config.logger.error('Error:')
          @result[:stderr].to_s.each_line { |line| Config.logger.error("  #{line.chomp}") }
        end
      end
    end
  end
end
