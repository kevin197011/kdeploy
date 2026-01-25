# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:jobs) do
      primary_key :id
      String :name, null: false
      String :task_file_path, null: false
      Text :default_variables_json, null: false, default: '{}'
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end

    create_table(:runs) do
      primary_key :id
      foreign_key :job_id, :jobs, null: false
      String :task_name, null: true
      String :status, null: false # queued|running|succeeded|failed|cancelled
      String :limit, null: true
      Integer :parallel, null: true
      Integer :retries, null: true
      Float :retry_delay, null: true
      String :format, null: false, default: 'text'
      DateTime :started_at, null: true
      DateTime :finished_at, null: true
      Text :text_output, null: true
      Text :json_output, null: true
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
      index [:job_id]
      index [:status]
    end

    create_table(:run_host_results) do
      primary_key :id
      foreign_key :run_id, :runs, null: false
      String :host_name, null: false
      String :status, null: false
      Text :error, null: true
      Text :steps_json, null: false, default: '[]'
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
      index [:run_id]
      index %i[run_id host_name], unique: true
    end
  end
end
