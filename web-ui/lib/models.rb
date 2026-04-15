# frozen_string_literal: true

require 'json'

require_relative 'db'

module Kdeploy
  module Web
    # Database models for job console
    module Models
      DB.db

      # Job definition model
      class Job < Sequel::Model(:jobs)
        def default_variables
          JSON.parse(default_variables_json || '{}')
        rescue JSON::ParserError
          {}
        end

        def to_h
          {
            id: id,
            name: name,
            task_file_path: task_file_path,
            default_variables: default_variables,
            created_at: created_at,
            updated_at: updated_at
          }
        end
      end

      # Deployment run model
      class Run < Sequel::Model(:runs)
        def to_h
          {
            id: id,
            job_id: job_id,
            task_name: task_name,
            status: status,
            cancel_requested: cancel_requested,
            limit: limit,
            parallel: parallel,
            retries: retries,
            retry_delay: retry_delay,
            format: format,
            started_at: started_at,
            finished_at: finished_at,
            created_at: created_at,
            updated_at: updated_at
          }
        end
      end

      # Per-host run result model
      class RunHostResult < Sequel::Model(:run_host_results)
        def steps
          JSON.parse(steps_json || '[]')
        rescue JSON::ParserError
          []
        end

        def to_h
          {
            id: id,
            run_id: run_id,
            host_name: host_name,
            status: status,
            error: error,
            steps: steps
          }
        end
      end
    end
  end
end
