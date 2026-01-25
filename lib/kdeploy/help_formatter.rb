# frozen_string_literal: true

require 'pastel'

module Kdeploy
  # Formats help text for CLI
  class HelpFormatter
    def initialize
      @pastel = Pastel.new
    end

    def format_help
      <<~HELP
        #{@pastel.bright_white('📖 Available Commands:')}

        #{format_commands}

        #{format_examples}

        #{format_documentation}
      HELP
    end

    private

    def format_commands
      <<~COMMANDS
        #{@pastel.bright_yellow('🚀')} #{@pastel.bright_white('execute TASK_FILE [TASK]')}     Execute deployment tasks from file
        #{@pastel.dim('    --limit HOSTS')}              Limit to specific hosts (comma-separated)
        #{@pastel.dim('    --parallel NUM')}             Number of parallel executions (default: 10; overridden by .kdeploy.yml)
        #{@pastel.dim('    --dry-run')}                  Show what would be done without executing
        #{@pastel.dim('    --debug')}                    Show detailed command output (stdout/stderr)
        #{@pastel.dim('    --no-banner')}                Do not print banner (automation-friendly)
        #{@pastel.dim('    --format FORMAT')}            Output format (text|json)
        #{@pastel.dim('    --retries N')}                Retry count for network operations (default: 0; overridden by .kdeploy.yml)
        #{@pastel.dim('    --retry-delay SECONDS')}      Retry delay seconds (default: 1; overridden by .kdeploy.yml)

        #{@pastel.bright_yellow('🆕')} #{@pastel.bright_white('init [DIR]')}                  Initialize new deployment project
        #{@pastel.bright_yellow('ℹ️')} #{@pastel.bright_white('version')}                    Show version information
        #{@pastel.bright_yellow('❓')} #{@pastel.bright_white('help [COMMAND]')}              Show help information
      COMMANDS
    end

    def format_examples
      <<~EXAMPLES
        #{@pastel.bright_white('💡 Examples:')}

        #{@pastel.dim('# Initialize a new project')}
        #{@pastel.bright_cyan('kdeploy init my-deployment')}

        #{@pastel.dim('# Deploy to web servers')}
        #{@pastel.bright_cyan('kdeploy execute deploy.rb deploy_web')}

        #{@pastel.dim('# Backup database')}
        #{@pastel.bright_cyan('kdeploy execute deploy.rb backup_db')}

        #{@pastel.dim('# Run maintenance on specific hosts')}
        #{@pastel.bright_cyan('kdeploy execute deploy.rb maintenance --limit web01')}

        #{@pastel.dim('# Preview deployment')}
        #{@pastel.bright_cyan('kdeploy execute deploy.rb deploy_web --dry-run')}

        #{@pastel.dim('# Machine-readable output')}
        #{@pastel.bright_cyan('kdeploy execute deploy.rb deploy_web --format json --no-banner')}

        #{@pastel.dim('# Retry transient network failures')}
        #{@pastel.bright_cyan('kdeploy execute deploy.rb deploy_web --retries 3 --retry-delay 1')}
      EXAMPLES
    end

    def format_documentation
      <<~DOCS
        #{@pastel.bright_white('📚 Documentation:')}
        #{@pastel.bright_cyan('https://github.com/kevin197011/kdeploy')}
      DOCS
    end
  end
end
