# frozen_string_literal: true

require 'json'
require 'fileutils'

module Kdeploy
  class Statistics
    attr_reader :data

    def initialize(stats_file: nil)
      @stats_file = stats_file || File.join(Dir.home, '.kdeploy', 'statistics.json')
      @data = load_statistics
      @session_start_time = Time.now
    end

    # Record a deployment execution
    # @param result [Hash] Deployment result
    def record_deployment(result)
      deployment_data = {
        timestamp: Time.now.to_f,
        success: result[:success],
        duration: result[:duration],
        tasks_count: result[:tasks_count] || 0,
        success_count: result[:success_count] || 0,
        pipeline_name: result[:pipeline_name] || 'unknown',
        hosts_count: result[:hosts_count] || 0
      }

      @data[:deployments] << deployment_data
      update_global_stats(deployment_data)
      save_statistics
    end

    # Record a task execution
    # @param task_name [String] Task name
    # @param result [Hash] Task execution result
    def record_task(task_name, result)
      task_data = {
        timestamp: Time.now.to_f,
        name: task_name,
        success: result[:success],
        duration: result[:duration],
        hosts_count: result[:hosts_count] || 0,
        success_count: result[:success_count] || 0
      }

      @data[:tasks] << task_data
      update_task_stats(task_data)
      save_statistics
    end

    # Record a command execution
    # @param command_name [String] Command name
    # @param host [String] Target host
    # @param success [Boolean] Execution success
    # @param duration [Float] Execution duration
    def record_command(command_name, host, success, duration)
      command_data = {
        timestamp: Time.now.to_f,
        name: command_name,
        host: host,
        success: success,
        duration: duration
      }

      @data[:commands] << command_data
      update_command_stats(command_data)
      save_statistics
    end

    # Get deployment statistics summary
    # @param days [Integer] Number of days to include (default: 30)
    # @return [Hash] Statistics summary
    def deployment_summary(days: 30)
      cutoff_time = Time.now - (days * 24 * 60 * 60)
      recent_deployments = @data[:deployments].select { |d| d[:timestamp] >= cutoff_time.to_f }

      return empty_summary if recent_deployments.empty?

      successful = recent_deployments.count { |d| d[:success] }
      failed = recent_deployments.size - successful

      durations = recent_deployments.map { |d| d[:duration] }

      {
        period_days: days,
        total_deployments: recent_deployments.size,
        successful_deployments: successful,
        failed_deployments: failed,
        success_rate: (successful.to_f / recent_deployments.size * 100).round(2),
        avg_duration: (durations.sum / durations.size).round(2),
        min_duration: durations.min&.round(2),
        max_duration: durations.max&.round(2),
        total_duration: durations.sum.round(2)
      }
    end

    # Get task statistics summary
    # @param days [Integer] Number of days to include (default: 30)
    # @return [Hash] Task statistics summary
    def task_summary(days: 30)
      cutoff_time = Time.now - (days * 24 * 60 * 60)
      recent_tasks = @data[:tasks].select { |t| t[:timestamp] >= cutoff_time.to_f }

      return { period_days: days, tasks: {} } if recent_tasks.empty?

      task_groups = recent_tasks.group_by { |t| t[:name] }
      task_stats = {}

      task_groups.each do |task_name, tasks|
        successful = tasks.count { |t| t[:success] }
        failed = tasks.size - successful
        durations = tasks.map { |t| t[:duration] }

        task_stats[task_name] = {
          total_executions: tasks.size,
          successful: successful,
          failed: failed,
          success_rate: (successful.to_f / tasks.size * 100).round(2),
          avg_duration: (durations.sum / durations.size).round(2),
          total_duration: durations.sum.round(2)
        }
      end

      {
        period_days: days,
        total_task_executions: recent_tasks.size,
        unique_tasks: task_groups.size,
        tasks: task_stats
      }
    end

    # Get global statistics
    # @return [Hash] Global statistics
    def global_summary
      {
        total_deployments: @data[:global][:deployments][:total],
        successful_deployments: @data[:global][:deployments][:successful],
        failed_deployments: @data[:global][:deployments][:failed],
        total_tasks: @data[:global][:tasks][:total],
        successful_tasks: @data[:global][:tasks][:successful],
        failed_tasks: @data[:global][:tasks][:failed],
        total_commands: @data[:global][:commands][:total],
        successful_commands: @data[:global][:commands][:successful],
        failed_commands: @data[:global][:commands][:failed],
        total_execution_time: @data[:global][:total_execution_time].round(2),
        session_start_time: @session_start_time,
        session_duration: (Time.now - @session_start_time).round(2)
      }
    end

    # Get top failed tasks
    # @param limit [Integer] Number of tasks to return
    # @param days [Integer] Number of days to include
    # @return [Array] Top failed tasks
    def top_failed_tasks(limit: 10, days: 30)
      cutoff_time = Time.now - (days * 24 * 60 * 60)
      recent_tasks = @data[:tasks].select { |t| t[:timestamp] >= cutoff_time.to_f && !t[:success] }

      failure_counts = recent_tasks.group_by { |t| t[:name] }
        .transform_values(&:size)
        .sort_by { |_, count| -count }
        .first(limit)

      failure_counts.map do |task_name, failures|
        {
          task_name: task_name,
          failure_count: failures,
          last_failure: recent_tasks.select { |t| t[:name] == task_name }.max_by { |t| t[:timestamp] }
        }
      end
    end

    # Get performance trends
    # @param days [Integer] Number of days to analyze
    # @return [Hash] Performance trends
    def performance_trends(days: 7)
      cutoff_time = Time.now - (days * 24 * 60 * 60)
      recent_deployments = @data[:deployments].select { |d| d[:timestamp] >= cutoff_time.to_f }

      return { period_days: days, trends: {} } if recent_deployments.empty?

      # Group by day
      daily_stats = recent_deployments.group_by do |d|
        Time.at(d[:timestamp]).strftime('%Y-%m-%d')
      end

      trends = daily_stats.transform_values do |deployments|
        successful = deployments.count { |d| d[:success] }
        durations = deployments.map { |d| d[:duration] }

        {
          total: deployments.size,
          successful: successful,
          failed: deployments.size - successful,
          success_rate: (successful.to_f / deployments.size * 100).round(2),
          avg_duration: durations.empty? ? 0 : (durations.sum / durations.size).round(2)
        }
      end

      {
        period_days: days,
        trends: trends.sort.to_h
      }
    end

    # Clear all statistics
    def clear_statistics!
      @data = default_statistics_structure
      save_statistics
    end

    # Export statistics to file
    # @param file_path [String] Export file path
    # @param format [Symbol] Export format (:json, :csv)
    def export_statistics(file_path, format: :json)
      case format
      when :json
        File.write(file_path, JSON.pretty_generate(@data))
      when :csv
        export_to_csv(file_path)
      else
        raise ArgumentError, "Unsupported export format: #{format}"
      end
    end

    private

    def load_statistics
      return default_statistics_structure unless File.exist?(@stats_file)

      begin
        JSON.parse(File.read(@stats_file), symbolize_names: true)
      rescue JSON::ParserError, StandardError
        KdeployLogger.warn('Failed to load statistics file, creating new one')
        default_statistics_structure
      end
    end

    def save_statistics
      FileUtils.mkdir_p(File.dirname(@stats_file))
      File.write(@stats_file, JSON.pretty_generate(@data))
    rescue StandardError => e
      KdeployLogger.warn("Failed to save statistics: #{e.message}")
    end

    def default_statistics_structure
      {
        deployments: [],
        tasks: [],
        commands: [],
        global: {
          deployments: { total: 0, successful: 0, failed: 0 },
          tasks: { total: 0, successful: 0, failed: 0 },
          commands: { total: 0, successful: 0, failed: 0 },
          total_execution_time: 0.0
        }
      }
    end

    def update_global_stats(deployment_data)
      @data[:global][:deployments][:total] += 1
      if deployment_data[:success]
        @data[:global][:deployments][:successful] += 1
      else
        @data[:global][:deployments][:failed] += 1
      end
      @data[:global][:total_execution_time] += deployment_data[:duration]
    end

    def update_task_stats(task_data)
      @data[:global][:tasks][:total] += 1
      if task_data[:success]
        @data[:global][:tasks][:successful] += 1
      else
        @data[:global][:tasks][:failed] += 1
      end
    end

    def update_command_stats(command_data)
      @data[:global][:commands][:total] += 1
      if command_data[:success]
        @data[:global][:commands][:successful] += 1
      else
        @data[:global][:commands][:failed] += 1
      end
    end

    def empty_summary
      {
        period_days: 0,
        total_deployments: 0,
        successful_deployments: 0,
        failed_deployments: 0,
        success_rate: 0.0,
        avg_duration: 0.0,
        min_duration: 0.0,
        max_duration: 0.0,
        total_duration: 0.0
      }
    end

    def export_to_csv(file_path)
      require 'csv'

      CSV.open(file_path, 'w') do |csv|
        # Deployments
        csv << %w[Type Timestamp Name Success Duration Tasks_Count Success_Count Hosts_Count]
        @data[:deployments].each do |d|
          csv << ['deployment', Time.at(d[:timestamp]), d[:pipeline_name], d[:success], d[:duration],
                  d[:tasks_count], d[:success_count], d[:hosts_count]]
        end

        # Tasks
        @data[:tasks].each do |t|
          csv << ['task', Time.at(t[:timestamp]), t[:name], t[:success], t[:duration],
                  nil, t[:success_count], t[:hosts_count]]
        end

        # Commands
        @data[:commands].each do |c|
          csv << ['command', Time.at(c[:timestamp]), c[:name], c[:success], c[:duration],
                  nil, nil, c[:host]]
        end
      end
    end
  end
end
