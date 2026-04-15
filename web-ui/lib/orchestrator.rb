# frozen_string_literal: true

require 'json'

require_relative 'models'

module Kdeploy
  module Web
    # In-process orchestrator for MVP (single instance worker queue).
    module Orchestrator
      @queue = Queue.new
      @worker_started = false

      class << self
        def cancel_run(run_id)
          run = Models::Run[run_id]
          return nil unless run

          case run.status
          when 'queued'
            run.update(
              status: 'cancelled',
              cancel_requested: true,
              finished_at: Time.now,
              updated_at: Time.now
            )
          when 'running'
            # Best-effort: mark requested. Execution engine may not support hard interrupt.
            run.update(cancel_requested: true, updated_at: Time.now)
          end
          run
        end

        def rerun(run_id)
          src = Models::Run[run_id]
          return nil unless src

          job = Models::Job[src.job_id]
          raise "job not found for run #{src.id}" unless job

          enqueue_run(
            job: job,
            task_name: src.task_name,
            limit: src.limit,
            parallel: src.parallel,
            retries: src.retries,
            retry_delay: src.retry_delay,
            format: src.format
          )
        end

        def enqueue_run(job:, task_name:, limit:, parallel:, retries:, retry_delay:, format:)
          enforce_limits!
          run = Models::Run.create(
            job_id: job.id,
            task_name: task_name,
            status: 'queued',
            cancel_requested: false,
            limit: limit,
            parallel: int_or_nil(parallel),
            retries: int_or_nil(retries),
            retry_delay: float_or_nil(retry_delay),
            format: format || 'text',
            created_at: Time.now,
            updated_at: Time.now
          )

          start_worker!
          @queue << run.id
          run
        end

        def start_worker!
          return if @worker_started

          @worker_started = true
          workers.times do
            Thread.new do
              loop do
                run_id = @queue.pop
                execute_run(run_id)
              rescue StandardError
                # Keep worker alive; errors are recorded per run.
                next
              end
            end
          end
        end

        private

        def execute_run(run_id)
          run = Models::Run[run_id]
          return unless run
          return if run.status == 'cancelled'

          run.update(status: 'running', started_at: Time.now, updated_at: Time.now)
          job = Models::Job[run.job_id]
          raise "job not found for run #{run.id}" unless job

          results, text_output, json_output = ExecutionAdapter.execute(
            task_file_path: job.task_file_path,
            task_name: run.task_name,
            limit: run.limit,
            parallel: run.parallel,
            retries: run.retries,
            retry_delay: run.retry_delay,
            format: run.format,
            on_step: lambda { |host, step, result|
              upsert_host_step(run, host, step, result)
            }
          )

          finalize_host_results(run, results)

          status = results.values.any? { |r| r[:status] == :failed } ? 'failed' : 'succeeded'
          status = 'cancelled' if run.cancel_requested
          run.update(
            status: status,
            finished_at: Time.now,
            text_output: text_output,
            json_output: json_output,
            updated_at: Time.now
          )
        rescue StandardError => e
          run&.update(
            status: 'failed',
            finished_at: Time.now,
            text_output: "#{e.class}: #{e.message}",
            updated_at: Time.now
          )
        end

        def upsert_host_step(run, host, step, result)
          row = Models::RunHostResult.first(run_id: run.id, host_name: host)
          steps = row ? JSON.parse(row.steps_json) : []
          steps << serialize_step(step)
          now = Time.now
          if row
            row.update(
              status: result[:status].to_s,
              error: result[:error],
              steps_json: JSON.generate(steps),
              updated_at: now
            )
          else
            Models::RunHostResult.create(
              run_id: run.id,
              host_name: host,
              status: result[:status].to_s,
              error: result[:error],
              steps_json: JSON.generate(steps),
              created_at: now,
              updated_at: now
            )
          end
          run.update(updated_at: now)
        rescue StandardError
          # Best-effort streaming; ignore failures
        end

        def finalize_host_results(run, results)
          results.each do |host, result|
            row = Models::RunHostResult.first(run_id: run.id, host_name: host)
            steps = Array(result[:output]).map { |step| serialize_step(step) }
            now = Time.now
            if row
              row.update(
                status: result[:status].to_s,
                error: result[:error],
                steps_json: JSON.generate(steps),
                updated_at: now
              )
            else
              Models::RunHostResult.create(
                run_id: run.id,
                host_name: host,
                status: result[:status].to_s,
                error: result[:error],
                steps_json: JSON.generate(steps),
                created_at: now,
                updated_at: now
              )
            end
          end
        end

        def serialize_step(step)
          out = {
            type: step[:type].to_s,
            command: step[:command],
            duration: step[:duration]
          }

          if step[:output].is_a?(Hash)
            out[:stdout] = step[:output][:stdout]
            out[:stderr] = step[:output][:stderr]
            out[:exit_status] = step[:output][:exit_status]
          end

          out[:result] = step[:result] if step[:type] == :sync
          out
        end

        def enforce_limits!
          max_queue = ENV.fetch('JOB_CONSOLE_MAX_QUEUE', '100').to_i
          max_running = ENV.fetch('JOB_CONSOLE_MAX_RUNNING', '1').to_i

          queued = Models::Run.where(status: 'queued').count
          running = Models::Run.where(status: 'running').count

          raise 'queue limit exceeded' if queued >= max_queue
          raise 'running limit exceeded' if running >= max_running && max_running.positive?
        end

        def workers
          v = ENV.fetch('JOB_CONSOLE_MAX_RUNNING', '1').to_i
          v.positive? ? v : 1
        end

        def int_or_nil(value)
          return nil if value.nil? || value.to_s.strip.empty?

          value.to_i
        end

        def float_or_nil(value)
          return nil if value.nil? || value.to_s.strip.empty?

          value.to_f
        end
      end
    end
  end
end

require_relative 'execution_adapter'
