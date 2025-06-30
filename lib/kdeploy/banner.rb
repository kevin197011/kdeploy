# frozen_string_literal: true

module Kdeploy
  # Banner module for displaying ASCII art banner
  module Banner
    class << self
      def show
        puts banner.colorize(:light_blue)
      end

      private

      def banner
        <<~BANNER
                    _            _
            /\\ /\\__| | ___ _ __ | | ___  _   _
           / //_/ _` |/ _ \\ '_ \\| |/ _ \\| | | |
          / __ \\ (_| |  __/ |_) | | (_) | |_| |
          \\/  \\/\\__,_|\\___| .__/|_|\\___/ \\__, |
                          |_|            |___/

            ⚡ Lightweight Agentless Deployment Tool
            🚀 Deploy with confidence, scale with ease
        BANNER
      end
    end
  end
end
