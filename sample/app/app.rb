# frozen_string_literal: true

# Sample Ruby application file
# This demonstrates syncing application code files

require 'sinatra'

class App < Sinatra::Base
  get '/' do
    'Hello from Kdeploy Sample App!'
  end

  get '/health' do
    { status: 'ok', timestamp: Time.now.to_i }.to_json
  end
end
