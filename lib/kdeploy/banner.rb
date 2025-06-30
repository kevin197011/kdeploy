module Kdeploy
  # ASCII banner and helper to print it consistently
  class Banner
    # Banner ASCII art template
    TEXT = <<~BANNER.freeze
                _            _
        /\\ /\\__| | ___ _ __ | | ___  _   _
       / //_/ _` |/ _ \\ '_ \\| |/ _ \\| | | |
      / __ \\ (_| |  __/ |_) | | (_) | |_| |
      \\/  \\/\\__,_|\\___| .__/|_|\\___/ \\__, |
                      |_|            |___/

        ⚡ Lightweight Agentless Deployment Tool v0.1.0
        🚀 Deploy with confidence, scale with ease
    BANNER

    class << self
      # Return raw banner text
      def text
        TEXT
      end

      # Print banner with specified color
      # @param color [Symbol] ANSI color name
      def print(color = :cyan)
        puts TEXT.colorize(color)
      end
    end
  end
end
