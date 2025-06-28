# frozen_string_literal: true

module Kdeploy
  class Runner
    attr_reader :pipeline

    def initialize(pipeline)
      @pipeline = pipeline
    end

    # Execute the deployment pipeline
    # @return [Hash] Execution results
    def execute
      validate_pipeline!
      setup_logging

      KdeployLogger.info("Starting deployment: #{@pipeline.name}")
      KdeployLogger.info("Pipeline summary: #{@pipeline.summary}")

      start_time = Time.now

      begin
        result = @pipeline.execute

        duration = Time.now - start_time

        # Enhanced result with pipeline info for statistics
        enhanced_result = result.merge(
          pipeline_name: @pipeline.name,
          hosts_count: @pipeline.hosts.size
        )

        # Record deployment statistics
        Kdeploy.statistics.record_deployment(enhanced_result)

        log_final_results(enhanced_result, duration)

        enhanced_result
      rescue StandardError => e
        duration = Time.now - start_time
        KdeployLogger.fatal("Deployment failed after #{duration.round(2)}s: #{e.message}")
        KdeployLogger.debug("Error backtrace: #{e.backtrace.join("\n")}")

        failed_result = {
          success: false,
          error: e.message,
          duration: duration,
          results: [],
          pipeline_name: @pipeline.name,
          hosts_count: @pipeline.hosts.size,
          tasks_count: @pipeline.tasks.size,
          success_count: 0
        }

        # Record failed deployment statistics
        Kdeploy.statistics.record_deployment(failed_result)

        failed_result
      end
    end

    # Dry run - validate and show what would be executed
    # @return [Hash] Validation results and execution plan
    def dry_run
      KdeployLogger.info("Performing dry run for pipeline: #{@pipeline.name}")

      validation_errors = @pipeline.validate

      if validation_errors.any?
        KdeployLogger.error('Pipeline validation failed:')
        validation_errors.each { |error| KdeployLogger.error("  - #{error}") }

        return {
          success: false,
          validation_errors: validation_errors,
          execution_plan: nil
        }
      end

      execution_plan = generate_execution_plan

      KdeployLogger.info('Dry run completed successfully')
      log_execution_plan(execution_plan)

      {
        success: true,
        validation_errors: [],
        execution_plan: execution_plan
      }
    end

    private

    def validate_pipeline!
      validation_errors = @pipeline.validate

      return if validation_errors.empty?

      error_message = "Pipeline validation failed:\n#{validation_errors.map { |e| "  - #{e}" }.join("\n")}"
      raise ConfigurationError, error_message
    end

    def setup_logging
      config = Kdeploy.configuration
      return unless config

      KdeployLogger.setup(
        level: config.log_level,
        file: config.log_file
      )
    end

    def log_final_results(result, duration)
      if result[:success]
        KdeployLogger.info("✅ Deployment completed successfully in #{duration.round(2)}s")
        KdeployLogger.info("📊 Summary: #{result[:success_count]}/#{result[:tasks_count]} tasks successful")
      else
        KdeployLogger.error("❌ Deployment failed in #{duration.round(2)}s")
        KdeployLogger.error("📊 Summary: #{result[:success_count]}/#{result[:tasks_count]} tasks successful")
      end

      # Log task details
      if result[:results].is_a?(Array)
        result[:results].each do |task_result|
          status = task_result[:success] ? '✅' : '❌'
          success_info = "#{task_result[:success_count]}/#{task_result[:hosts_count]} hosts successful"
          KdeployLogger.info("#{status} Task '#{task_result[:task_name]}': #{success_info}")
        end
      end

      # Log statistics summary
      global_stats = Kdeploy.statistics.global_summary
      KdeployLogger.info("📈 Global Stats: #{global_stats[:total_deployments]} deployments, " \
                         "#{global_stats[:successful_deployments]} successful, " \
                         "#{global_stats[:failed_deployments]} failed")
    end

    def generate_execution_plan
      plan = {
        pipeline_name: @pipeline.name,
        total_hosts: @pipeline.hosts.size,
        total_tasks: @pipeline.tasks.size,
        hosts: @pipeline.hosts.map(&:hostname),
        tasks: []
      }

      @pipeline.tasks.each do |task|
        task_plan = {
          name: task.name,
          target_hosts: task.hosts.map(&:hostname),
          commands: task.commands.map do |command|
            {
              name: command.name,
              command: command.command,
              options: command.options
            }
          end,
          options: task.options
        }

        plan[:tasks] << task_plan
      end

      plan
    end

    def log_execution_plan(plan)
      KdeployLogger.info('📋 Execution Plan:')
      KdeployLogger.info("  Pipeline: #{plan[:pipeline_name]}")
      KdeployLogger.info("  Hosts: #{plan[:total_hosts]} (#{plan[:hosts].join(', ')})")
      KdeployLogger.info("  Tasks: #{plan[:total_tasks]}")

      plan[:tasks].each_with_index do |task, index|
        KdeployLogger.info("    #{index + 1}. #{task[:name]}")
        KdeployLogger.info("       Targets: #{task[:target_hosts].join(', ')}")
        KdeployLogger.info("       Commands: #{task[:commands].size}")

        task[:commands].each_with_index do |command, cmd_index|
          KdeployLogger.info("         #{cmd_index + 1}. #{command[:name]}: #{command[:command]}")
        end

        if task[:options][:parallel]
          KdeployLogger.info("       Execution: Parallel (max: #{task[:options][:max_concurrent] || 'unlimited'})")
        else
          KdeployLogger.info('       Execution: Sequential')
        end
      end
    end
  end
end
