# frozen_string_literal: true

require 'json'
require 'sequel'
require 'sinatra/base'
require 'rack/protection'
require 'securerandom'

require 'kdeploy'

require_relative '../lib/auth'
require_relative '../lib/db'
require_relative '../lib/models'
require_relative '../lib/orchestrator'

module Kdeploy
  module Web
    # Minimal job console (MVP)
    class App < Sinatra::Base
      set :show_exceptions, false
      set :raise_errors, false
      set :static, true
      set :public_folder, File.expand_path('../public', __dir__)
      # We rely on token auth for MVP; disable Rack::Protection defaults.
      set :protection, false
      use Rack::Session::Cookie,
          key: 'kdeploy.session',
          same_site: :lax,
          secret: ENV.fetch('JOB_CONSOLE_SESSION_SECRET', SecureRandom.hex(32))
      # Sinatra host authorization (Rack 3) default is restrictive and can return 403.
      # Configure permitted hosts via env:
      #   JOB_CONSOLE_PERMITTED_HOSTS="localhost,example.org,.example.org"
      permitted_hosts = ENV.fetch('JOB_CONSOLE_PERMITTED_HOSTS', 'localhost,example.org').split(',').map(&:strip)
      set :host_authorization, { permitted_hosts: permitted_hosts }
      set :views, File.expand_path('../views', __dir__)

      before do
        content_type :json if request.path_info.start_with?('/api/')
      end

      use Auth

      helpers do
        def ui_logged_in?
          session[:ui_user]
        end

        def require_ui_login!
          return if ui_logged_in?
          return if request.path_info.start_with?('/login')

          redirect '/login'
        end
      end

      before do
        next if request.path_info.start_with?('/api/')

        require_ui_login!
      end

      get '/login' do
        erb :login
      end

      post '/login' do
        username = params['username'].to_s
        password = params['password'].to_s
        env_user = ENV.fetch('JOB_CONSOLE_UI_USER', 'admin')
        env_pass = ENV.fetch('JOB_CONSOLE_UI_PASSWORD', 'admin123')

        if username == env_user && password == env_pass
          session[:ui_user] = username
          redirect '/jobs'
        else
          @login_error = 'Invalid username or password'
          erb :login
        end
      end

      post '/logout' do
        session.clear
        redirect '/login'
      end

      get '/' do
        redirect '/editor'
      end

      # --- UI ---
      get '/editor' do
        @file_path = editor_task_path
        @content = File.exist?(@file_path) ? File.read(@file_path) : default_editor_content
        erb :editor
      end

      get '/editor/content' do
        path = editor_task_path
        content = File.exist?(path) ? File.read(path) : default_editor_content
        JSON.generate(path: path, content: content)
      end

      post '/editor/save' do
        payload = params
        content = payload.fetch('content', '').to_s
        path = editor_task_path
        File.write(path, content)
        JSON.generate(ok: true, path: path)
      end

      post '/editor/run' do
        payload = params
        content = payload.fetch('content', '').to_s
        path = editor_task_path
        File.write(path, content)

        job = ensure_editor_job(path)
        run = begin
          Orchestrator.enqueue_run(
            job: job,
            task_name: payload['task_name'],
            limit: payload['limit'],
            parallel: payload['parallel'],
            retries: payload['retries'],
            retry_delay: payload['retry_delay'],
            format: 'text'
          )
        rescue StandardError => e
          halt 429, JSON.generate(error: e.message)
        end

        JSON.generate(run_id: run.id)
      end
      get '/jobs' do
        redirect '/editor'
      end

      get '/jobs/new' do
        redirect '/editor'
      end

      get '/jobs/:id' do
        redirect '/editor'
      end

      get '/jobs/:id/edit' do
        redirect '/editor'
      end

      get '/runs' do
        redirect '/editor'
      end

      get '/runs/:id' do
        redirect '/editor'
      end

      get '/runs/:id/stream' do
        @run = Models::Run[params.fetch('id')]
        halt 404, 'run not found' unless @run
        @host_results = Models::RunHostResult.where(run_id: @run.id).order(:host_name).all
        JSON.generate(
          run: @run.to_h,
          hosts: @host_results.map(&:to_h)
        )
      end

      # --- API ---
      get '/api/jobs' do
        jobs = Models::Job.reverse_order(:updated_at).all
        JSON.generate(jobs.map(&:to_h))
      end

      post '/api/jobs' do
        payload = read_json_body
        validate_task_file_path!(payload.fetch('task_file_path'))
        job = Models::Job.create(
          name: payload.fetch('name'),
          task_file_path: payload.fetch('task_file_path'),
          default_variables_json: JSON.generate(payload.fetch('default_variables', {})),
          created_at: Time.now,
          updated_at: Time.now
        )
        status 201
        JSON.generate(job.to_h)
      end

      get '/api/jobs/:id' do
        job = Models::Job[params.fetch('id')]
        halt 404, JSON.generate(error: 'job not found') unless job
        JSON.generate(job.to_h)
      end

      put '/api/jobs/:id' do
        job = Models::Job[params.fetch('id')]
        halt 404, JSON.generate(error: 'job not found') unless job
        payload = read_json_body
        validate_task_file_path!(payload.fetch('task_file_path', job.task_file_path))
        job.update(
          name: payload.fetch('name', job.name),
          task_file_path: payload.fetch('task_file_path', job.task_file_path),
          default_variables_json: JSON.generate(
            payload.fetch('default_variables', JSON.parse(job.default_variables_json))
          ),
          updated_at: Time.now
        )
        JSON.generate(job.to_h)
      end

      post '/api/jobs/:id/runs' do
        job = Models::Job[params.fetch('id')]
        halt 404, JSON.generate(error: 'job not found') unless job
        payload = read_json_body

        run = begin
          Orchestrator.enqueue_run(
            job: job,
            task_name: payload['task_name'],
            limit: payload['limit'],
            parallel: payload['parallel'],
            retries: payload['retries'],
            retry_delay: payload['retry_delay'],
            format: payload['format']
          )
        rescue StandardError => e
          halt 429, JSON.generate(error: e.message)
        end

        status 201
        JSON.generate(run.to_h)
      end

      def read_json_body
        raw = request.body.read.to_s
        return {} if raw.strip.empty?

        JSON.parse(raw)
      end

      get '/api/runs/:id' do
        run = Models::Run[params.fetch('id')]
        halt 404, JSON.generate(error: 'run not found') unless run
        JSON.generate(run.to_h)
      end

      get '/api/runs/:id/results' do
        run = Models::Run[params.fetch('id')]
        halt 404, JSON.generate(error: 'run not found') unless run
        host_results = Models::RunHostResult.where(run_id: run.id).order(:host_name).all
        JSON.generate(
          run: run.to_h,
          hosts: host_results.map(&:to_h)
        )
      end

      post '/api/runs/:id/cancel' do
        run = Orchestrator.cancel_run(params.fetch('id'))
        halt 404, JSON.generate(error: 'run not found') unless run
        JSON.generate(run.to_h)
      end

      post '/api/runs/:id/rerun' do
        run = Orchestrator.rerun(params.fetch('id'))
        halt 404, JSON.generate(error: 'run not found') unless run
        status 201
        JSON.generate(run.to_h)
      end

      error do
        e = env['sinatra.error']
        status 500
        if request.path_info.start_with?('/api/')
          JSON.generate(error: e.class.to_s, message: e.message)
        else
          render_error_page('Something went wrong', "#{e.class}: #{e.message}", status: 500)
        end
      end

      def validate_task_file_path!(path)
        ExecutionAdapter.ensure_task_path_allowed!(path)
      rescue StandardError => e
        if request.path_info.start_with?('/api/')
          status 422
          halt JSON.generate(error: e.message)
        else
          render_error_page('Invalid task file', e.message, status: 422, hint: 'Check JOB_CONSOLE_TASK_BASE_DIR.')
        end
      end

      def render_error_page(title, message, status:, hint: nil)
        @error_title = title
        @error_message = message
        @error_hint = hint
        halt status, erb(:error)
      end

      def editor_task_path
        base_dir = ENV.fetch('JOB_CONSOLE_TASK_BASE_DIR', File.expand_path('deployments', Dir.pwd))
        FileUtils.mkdir_p(base_dir)
        File.join(File.expand_path(base_dir), 'deploy.rb')
      end

      def default_editor_content
        <<~RUBY
          # frozen_string_literal: true

          host 'web01', user: 'ubuntu', ip: '10.0.0.1'

          task :deploy_web do
            run 'echo hello'
          end
        RUBY
      end

      def ensure_editor_job(path)
        job = Models::Job.first(name: 'editor')
        now = Time.now
        if job
          job.update(task_file_path: path, updated_at: now)
          job
        else
          Models::Job.create(
            name: 'editor',
            task_file_path: path,
            default_variables_json: '{}',
            created_at: now,
            updated_at: now
          )
        end
      end
    end
  end
end
