# frozen_string_literal: true

require 'json'
require 'sequel'
require 'sinatra/base'
require 'rack/protection'

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
      # We rely on token auth for MVP; disable Rack::Protection defaults.
      set :protection, false
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

      get '/' do
        redirect '/jobs'
      end

      # --- UI ---
      get '/jobs' do
        @jobs = Models::Job.reverse_order(:updated_at).all
        erb :jobs
      end

      get '/jobs/new' do
        @job = Models::Job.new
        erb :job_form
      end

      post '/jobs' do
        payload = params
        job = Models::Job.create(
          name: payload.fetch('name'),
          task_file_path: payload.fetch('task_file_path'),
          default_variables_json: payload.fetch('default_variables_json', '{}'),
          created_at: Time.now,
          updated_at: Time.now
        )
        redirect "/jobs/#{job.id}"
      end

      get '/jobs/:id' do
        @job = Models::Job[params.fetch('id')]
        halt 404, 'job not found' unless @job
        erb :job_detail
      end

      get '/jobs/:id/edit' do
        @job = Models::Job[params.fetch('id')]
        halt 404, 'job not found' unless @job
        erb :job_form
      end

      post '/jobs/:id' do
        job = Models::Job[params.fetch('id')]
        halt 404, 'job not found' unless job
        job.update(
          name: params.fetch('name'),
          task_file_path: params.fetch('task_file_path'),
          default_variables_json: params.fetch('default_variables_json', '{}'),
          updated_at: Time.now
        )
        redirect "/jobs/#{job.id}"
      end

      get '/runs' do
        @runs = Models::Run.reverse_order(:created_at).limit(200).all
        erb :runs
      end

      get '/runs/:id' do
        @run = Models::Run[params.fetch('id')]
        halt 404, 'run not found' unless @run
        @host_results = Models::RunHostResult.where(run_id: @run.id).order(:host_name).all
        erb :run_detail
      end

      post '/runs/:id/cancel' do
        run = Orchestrator.cancel_run(params.fetch('id'))
        halt 404, 'run not found' unless run
        redirect "/runs/#{run.id}"
      end

      post '/runs/:id/rerun' do
        run = Orchestrator.rerun(params.fetch('id'))
        halt 404, 'run not found' unless run
        redirect "/runs/#{run.id}"
      end

      post '/jobs/:id/runs' do
        job = Models::Job[params.fetch('id')]
        halt 404, 'job not found' unless job

        run = begin
          Orchestrator.enqueue_run(
            job: job,
            task_name: params['task_name'],
            limit: params['limit'],
            parallel: params['parallel'],
            retries: params['retries'],
            retry_delay: params['retry_delay'],
            format: params['format']
          )
        rescue StandardError => e
          halt 429, e.message
        end

        redirect "/runs/#{run.id}"
      end

      # --- API ---
      get '/api/jobs' do
        jobs = Models::Job.reverse_order(:updated_at).all
        JSON.generate(jobs.map(&:to_h))
      end

      post '/api/jobs' do
        payload = read_json_body
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
          "error: #{e.class}: #{e.message}"
        end
      end
    end
  end
end
