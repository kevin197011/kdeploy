# frozen_string_literal: true

require 'pastel'

module Kdeploy
  # Banner display module for CLI output
  module Banner
    class << self
      def show
        pastel = Pastel.new
        <<~BANNER
          #{pastel.bright_blue(ASCII_LOGO)}

          #{pastel.bright_yellow('⚡')} #{pastel.bright_white('Lightweight Agentless Deployment Tool')}
          #{pastel.bright_yellow('🚀')} #{pastel.bright_white('Deploy with confidence, scale with ease')}

          =====================================================================================================

        BANNER
      end

      def show_version
        pastel = Pastel.new
        <<~VERSION
          #{show}
          #{pastel.bright_white("Version: #{VERSION}")}

        VERSION
      end

      def show_error(message)
        pastel = Pastel.new
        <<~ERROR
          #{show}
          #{pastel.red("Error: #{message}")}

        ERROR
      end

      def show_success(message)
        pastel = Pastel.new
        <<~SUCCESS
          #{show}
          #{pastel.green("Success: #{message}")}

        SUCCESS
      end

      ASCII_LOGO = <<~'LOGO'
                  _            _
          /\ /\__| | ___ _ __ | | ___  _   _
         / //_/ _` |/ _ \ '_ \| |/ _ \| | | |
        / __ \ (_| |  __/ |_) | | (_) | |_| |
        \/  \/\__,_|\___| .__/|_|\___/ \__, |
                        |_|            |___/
      LOGO
    end
  end
end
