# frozen_string_literal: true

require 'json'
require 'rack/test'

ENV['JOB_CONSOLE_DB'] = 'sqlite::memory:'

require_relative '../../web/app/app'

RSpec.describe Kdeploy::Web::App do
  include Rack::Test::Methods

  def app
    described_class
  end

  before do
    # Force reconnect for in-memory DB
    Kdeploy::Web::DB.connect!(url: ENV.fetch('JOB_CONSOLE_DB', nil))
    migrations_dir = File.expand_path('../../web/db/migrate', __dir__)
    Sequel::Migrator.run(Kdeploy::Web::DB.db, migrations_dir)
    ENV.delete('JOB_CONSOLE_TOKEN')
  end

  it 'creates and lists jobs via API' do
    post '/api/jobs', JSON.generate(name: 'demo', task_file_path: 'sample/deploy.rb', default_variables: { a: 1 }),
         'CONTENT_TYPE' => 'application/json'
    expect(last_response.status).to eq(201)
    created = JSON.parse(last_response.body)
    expect(created['name']).to eq('demo')

    get '/api/jobs'
    expect(last_response.status).to eq(200)
    list = JSON.parse(last_response.body)
    expect(list.length).to eq(1)
    expect(list.first['name']).to eq('demo')
  end

  it 'rejects unauthorized requests when token is set' do
    ENV['JOB_CONSOLE_TOKEN'] = 't'
    get '/api/jobs'
    expect(last_response.status).to eq(401)
  end

  it 'cancels a queued run via API' do
    job = Kdeploy::Web::Models::Job.create(
      name: 'demo',
      task_file_path: 'sample/deploy.rb',
      default_variables_json: '{}',
      created_at: Time.now,
      updated_at: Time.now
    )

    allow(Kdeploy::Web::Orchestrator).to receive(:start_worker!).and_return(nil)
    run = Kdeploy::Web::Orchestrator.enqueue_run(job: job, task_name: nil, limit: nil, parallel: nil, retries: nil,
                                                 retry_delay: nil, format: 'text')

    post "/api/runs/#{run.id}/cancel"
    expect(last_response.status).to eq(200)
    body = JSON.parse(last_response.body)
    expect(body['status']).to eq('cancelled')
  end

  it 'creates a rerun via API' do
    job = Kdeploy::Web::Models::Job.create(
      name: 'demo',
      task_file_path: 'sample/deploy.rb',
      default_variables_json: '{}',
      created_at: Time.now,
      updated_at: Time.now
    )

    allow(Kdeploy::Web::Orchestrator).to receive(:start_worker!).and_return(nil)
    run = Kdeploy::Web::Orchestrator.enqueue_run(job: job, task_name: 'deploy_web', limit: 'web01', parallel: 2,
                                                 retries: 1, retry_delay: 1, format: 'text')

    post "/api/runs/#{run.id}/rerun"
    expect(last_response.status).to eq(201)
    body = JSON.parse(last_response.body)
    expect(body['job_id']).to eq(job.id)
    expect(body['task_name']).to eq('deploy_web')
    expect(body['limit']).to eq('web01')
  end
end
