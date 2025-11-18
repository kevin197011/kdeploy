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
        #{@pastel.dim('    --parallel NUM')}             Number of parallel executions (default: 5)
        #{@pastel.dim('    --dry-run')}                  Show what would be done without executing

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
