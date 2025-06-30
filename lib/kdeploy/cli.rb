# frozen_string_literal: true

# Add String truncate method if not available
class String
  def truncate(length)
    return self if size <= length

    "#{self[0, length - 3]}..."
  end
end

module Kdeploy
  class CLI < Thor
    include Thor::Actions

    # Fix Thor deprecation warning
    def self.exit_on_failure?
      true
    end

    # 显示版本信息
    map %w[-v --version] => :version
    desc 'version', 'Display version information'
    def version
      puts Banner.render
      puts "Version #{VERSION}"
    end

    # 初始化项目
    desc 'init [NAME]', 'Initialize a new Kdeploy project'
    method_option :force, type: :boolean, aliases: '-f', desc: 'Force overwrite existing files'
    def init(name = nil)
      if name
        empty_directory(name)
        self.destination_root = name
      end

      # 创建项目结构
      directory('templates', 'templates')
      directory('scripts', 'scripts')
      directory('config', 'config')

      # 创建基础文件
      template('deploy.rb.tt', 'deploy.rb')
      template('inventory.yml.tt', 'inventory.yml')
      template('README.md.tt', 'README.md')
      template('Gemfile.tt', 'Gemfile')

      # 初始化 Git
      inside(destination_root) do
        run('git init') if options[:git] && !File.exist?('.git')
      end

      say '✅ Project initialized successfully!', :green
    end

    # 验证配置
    desc 'validate SCRIPT', 'Validate deployment script'
    method_option :inventory, type: :string, aliases: '-i', desc: 'Path to inventory file'
    def validate(script)
      Config.logger.info "Validating #{script}..."
      pipeline = load_script(script)

      if pipeline.valid?
        say '✅ Configuration is valid!', :green
      else
        say '❌ Configuration is invalid!', :red
        pipeline.errors.each do |error|
          say "  - #{error}", :red
        end
        exit 1
      end
    end

    # 执行部署
    desc 'deploy SCRIPT', 'Execute deployment script'
    method_option :inventory, type: :string, aliases: '-i', desc: 'Path to inventory file'
    method_option :verbose, type: :boolean, aliases: '-v', desc: 'Enable verbose output'
    method_option :dry_run, type: :boolean, desc: 'Perform a dry run'
    method_option :parallel, type: :boolean, desc: 'Enable parallel execution'
    method_option :task, type: :string, aliases: '-t', desc: 'Execute specific task'
    def deploy(script)
      Config.logger.info 'Starting deployment...'

      # 加载脚本
      pipeline = load_script(script)

      # 设置选项
      pipeline.dry_run = options[:dry_run]
      pipeline.parallel = options[:parallel]
      pipeline.verbose = options[:verbose]

      # 执行部署
      if options[:task]
        pipeline.execute_task(options[:task])
      else
        pipeline.execute
      end

      Config.logger.info 'Deployment completed successfully!'
    rescue Error => e
      Config.logger.error "Deployment failed: #{e.message}"
      exit 1
    end

    # 统计信息
    desc 'stats SUBCOMMAND', 'Show deployment statistics'
    subcommand 'stats', Stats

    # 配置管理
    desc 'config', 'Show current configuration'
    def config
      table = TTY::Table.new(
        header: %w[Setting Value],
        rows: [
          ['Project Root', Config.root],
          ['Templates Path', Config.templates_path],
          ['Inventory Path', Config.inventory_path],
          ['Log Level', Config.logger.level],
          ['Version', VERSION]
        ]
      )
      puts table.render(:unicode, padding: [0, 1])
    end

    private

    def load_script(script)
      raise Error, "Script file not found: #{script}" unless File.exist?(script)

      # 设置 inventory 路径
      Config.inventory_path = Pathname.new(options[:inventory]) if options[:inventory]

      # 加载并执行脚本
      script_dir = File.dirname(File.expand_path(script))
      dsl = DSL.new(script_dir)
      dsl.instance_eval(File.read(script), script)
      dsl.pipeline
    end

    def source_paths
      [File.join(File.dirname(__FILE__), 'templates')]
    end
  end

  # 统计子命令
  class Stats < Thor
    desc 'summary', 'Show deployment summary'
    def summary
      stats = Statistics.load
      table = TTY::Table.new(
        header: %w[Metric Value],
        rows: [
          ['Total Deployments', stats.total_deployments],
          ['Successful Deployments', stats.successful_deployments],
          ['Failed Deployments', stats.failed_deployments],
          ['Average Duration', "#{stats.average_duration.round(2)}s"],
          ['Total Tasks', stats.total_tasks],
          ['Success Rate', "#{(stats.success_rate * 100).round(2)}%"]
        ]
      )
      puts table.render(:unicode, padding: [0, 1])
    end

    desc 'deployments', 'Show deployment history'
    def deployments
      stats = Statistics.load
      table = TTY::Table.new(
        header: %w[ID Date Duration Status Tasks],
        rows: stats.deployments.map do |d|
          [d.id, d.date, "#{d.duration.round(2)}s", d.status, d.tasks.count]
        end
      )
      puts table.render(:unicode, padding: [0, 1])
    end

    desc 'tasks', 'Show task statistics'
    def tasks
      stats = Statistics.load
      table = TTY::Table.new(
        header: ['Task', 'Count', 'Avg Duration', 'Success Rate'],
        rows: stats.task_stats.map do |name, stat|
          [
            name,
            stat.count,
            "#{stat.average_duration.round(2)}s",
            "#{(stat.success_rate * 100).round(2)}%"
          ]
        end
      )
      puts table.render(:unicode, padding: [0, 1])
    end

    desc 'clear', 'Clear statistics'
    def clear
      return unless yes?('Are you sure you want to clear all statistics? (y/n)')

      Statistics.clear
      say 'Statistics cleared successfully!', :green
    end

    desc 'export [FILE]', 'Export statistics to JSON'
    def export(file = 'kdeploy_stats.json')
      stats = Statistics.load
      File.write(file, JSON.pretty_generate(stats.to_h))
      say "Statistics exported to #{file}", :green
    end
  end
end
