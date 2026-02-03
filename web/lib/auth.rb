# frozen_string_literal: true

require 'securerandom'
require 'json'

module Kdeploy
  module Web
    # Minimal auth for MVP:
    # - If JOB_CONSOLE_TOKEN is set, require `Authorization: Bearer <token>`.
    # - Otherwise allow all requests (dev convenience).
    class Auth
      def initialize(app)
        @app = app
      end

      def call(env)
        token = ENV.fetch('JOB_CONSOLE_TOKEN', nil)
        return unauthorized(env, 'token not configured') if token.nil? || token.empty?

        auth = env['HTTP_AUTHORIZATION'].to_s
        ok = auth.start_with?('Bearer ') && auth.delete_prefix('Bearer ').strip == token
        return unauthorized(env, 'unauthorized') unless ok

        @app.call(env)
      end

      private

      def unauthorized(env, message)
        path = env['PATH_INFO'].to_s
        body = if path.start_with?('/api/')
                 JSON.generate(error: message)
               else
                 message
               end
        [401, { 'Content-Type' => path.start_with?('/api/') ? 'application/json' : 'text/plain' }, [body]]
      end
    end
  end
end
