# frozen_string_literal: true

require 'json'
require 'fileutils'

module Kdeploy
  # Handles deployment statistics collection and analysis
  class Statistics
    attr_reader :data

    def initialize(stats_file: nil)
      @stats_file = stats_file || default_stats_file
      @data = load_statistics
      @session_start_time = Time.now
    end

    # Record a deployment execution
    # @param result [Hash] Deployment result
    def record_deployment(result)
      deployment_data = build_deployment_data(result)
      @data[:deployments] << deployment_data
      update_global_stats(deployment_data)
      save_statistics
    end

    # Record a task execution
    # @param task_name [String] Task name
    # @param result [Hash] Task execution result
    def record_task(task_name, result)
      task_data = build_task_data(task_name, result)
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
      command_data = build_command_data(command_name, host, success, duration)
      @data[:commands] << command_data
      update_command_stats(command_data)
      save_statistics
    end

    # Get deployment statistics summary
    # @param days [Integer] Number of days to include (default: 30)
    # @return [Hash] Statistics summary
    def deployment_summary(days: 30)
      cutoff_time = calculate_cutoff_time(days)
      recent_deployments = filter_recent_data(@data[:deployments], cutoff_time)

      return empty_summary if recent_deployments.empty?

      build_deployment_summary(recent_deployments, days)
    end

    # Get task statistics summary
    # @param days [Integer] Number of days to include (default: 30)
    # @return [Hash] Task statistics summary
    def task_summary(days: 30)
      cutoff_time = calculate_cutoff_time(days)
      recent_tasks = filter_recent_data(@data[:tasks], cutoff_time)

      return empty_task_summary(days) if recent_tasks.empty?

      build_task_summary(recent_tasks, days)
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
      cutoff_time = calculate_cutoff_time(days)
      recent_tasks = filter_recent_failed_tasks(cutoff_time)

      build_top_failed_tasks(recent_tasks, limit)
    end

    # Get performance trends
    # @param days [Integer] Number of days to analyze
    # @return [Hash] Performance trends
    def performance_trends(days: 7)
      cutoff_time = calculate_cutoff_time(days)
      recent_deployments = filter_recent_data(@data[:deployments], cutoff_time)

      return { period_days: days, trends: {} } if recent_deployments.empty?

      build_performance_trends(recent_deployments, days)
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
        export_to_json(file_path)
      when :csv
        export_to_csv(file_path)
      else
        raise ArgumentError, "Unsupported export format: #{format}"
      end
    end

    private

    def default_stats_file
      File.join(Dir.home, '.kdeploy', 'statistics.json')
    end

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
      KdeployLogger.error("Failed to save statistics: #{e.message}")
    end

    def build_deployment_data(result)
      {
        timestamp: Time.now.to_f,
        success: result[:success],
        duration: result[:duration],
        tasks_count: result[:tasks_count] || 0,
        success_count: result[:success_count] || 0,
        pipeline_name: result[:pipeline_name] || 'unknown',
        hosts_count: result[:hosts_count] || 0
      }
    end

    def build_task_data(task_name, result)
      {
        timestamp: Time.now.to_f,
        name: task_name,
        success: result[:success],
        duration: result[:duration],
        hosts_count: result[:hosts_count] || 0,
        success_count: result[:success_count] || 0
      }
    end

    def build_command_data(command_name, host, success, duration)
      {
        timestamp: Time.now.to_f,
        name: command_name,
        host: host,
        success: success,
        duration: duration
      }
    end

    def calculate_cutoff_time(days)
      Time.now - (days * 24 * 60 * 60)
    end

    def filter_recent_data(data, cutoff_time)
      data.select { |d| d[:timestamp] >= cutoff_time.to_f }
    end

    def filter_recent_failed_tasks(cutoff_time)
      @data[:tasks].select { |t| t[:timestamp] >= cutoff_time.to_f && !t[:success] }
    end

    def build_deployment_summary(deployments, days)
      successful = deployments.count { |d| d[:success] }
      failed = deployments.size - successful
      durations = deployments.map { |d| d[:duration] }

      {
        period_days: days,
        total_deployments: deployments.size,
        successful_deployments: successful,
        failed_deployments: failed,
        success_rate: calculate_success_rate(successful, deployments.size),
        avg_duration: calculate_average(durations),
        min_duration: durations.min&.round(2),
        max_duration: durations.max&.round(2),
        total_duration: durations.sum.round(2)
      }
    end

    def build_task_summary(tasks, days)
      task_groups = tasks.group_by { |t| t[:name] }
      task_stats = build_task_group_stats(task_groups)

      {
        period_days: days,
        total_task_executions: tasks.size,
        unique_tasks: task_groups.size,
        tasks: task_stats
      }
    end

    def build_task_group_stats(task_groups)
      task_groups.transform_values do |tasks|
        successful = tasks.count { |t| t[:success] }
        failed = tasks.size - successful
        durations = tasks.map { |t| t[:duration] }

        {
          total_executions: tasks.size,
          successful: successful,
          failed: failed,
          success_rate: calculate_success_rate(successful, tasks.size),
          avg_duration: calculate_average(durations),
          total_duration: durations.sum.round(2)
        }
      end
    end

    def build_top_failed_tasks(tasks, limit)
      failure_counts = calculate_failure_counts(tasks, limit)
      failure_counts.map do |task_name, count|
        {
          task_name: task_name,
          failure_count: count,
          last_failure: find_last_failure(tasks, task_name)
        }
      end
    end

    def calculate_failure_counts(tasks, limit)
      tasks.group_by { |t| t[:name] }
        .transform_values(&:size)
        .sort_by { |_, count| -count }
        .first(limit)
        .to_h
    end

    def find_last_failure(tasks, task_name)
      tasks.select { |t| t[:name] == task_name }
        .max_by { |t| t[:timestamp] }
    end

    def build_performance_trends(deployments, days)
      daily_stats = group_by_day(deployments)
      trends = calculate_daily_trends(daily_stats)

      {
        period_days: days,
        trends: trends
      }
    end

    def group_by_day(deployments)
      deployments.group_by do |d|
        Time.at(d[:timestamp]).strftime('%Y-%m-%d')
      end
    end

    def calculate_daily_trends(daily_stats)
      daily_stats.transform_values do |deployments|
        successful = deployments.count { |d| d[:success] }
        durations = deployments.map { |d| d[:duration] }

        {
          total: deployments.size,
          successful: successful,
          failed: deployments.size - successful,
          success_rate: calculate_success_rate(successful, deployments.size),
          avg_duration: calculate_average(durations)
        }
      end
    end

    def calculate_success_rate(successful, total)
      (successful.to_f / total * 100).round(2)
    end

    def calculate_average(values)
      values.empty? ? 0 : (values.sum / values.size).round(2)
    end

    def empty_summary
      {
        period_days: 30,
        total_deployments: 0,
        successful_deployments: 0,
        failed_deployments: 0,
        success_rate: 0,
        avg_duration: 0,
        min_duration: 0,
        max_duration: 0,
        total_duration: 0
      }
    end

    def empty_task_summary(days)
      {
        period_days: days,
        total_task_executions: 0,
        unique_tasks: 0,
        tasks: {}
      }
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
          total_execution_time: 0
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
      @data[:global][:total_execution_time] += task_data[:duration]
    end

    def update_command_stats(command_data)
      @data[:global][:commands][:total] += 1
      if command_data[:success]
        @data[:global][:commands][:successful] += 1
      else
        @data[:global][:commands][:failed] += 1
      end
      @data[:global][:total_execution_time] += command_data[:duration]
    end

    def export_to_json(file_path)
      File.write(file_path, JSON.pretty_generate(@data))
    end

    def export_to_csv(file_path)
      require 'csv'

      CSV.open(file_path, 'w') do |csv|
        export_deployments_to_csv(csv)
        csv << []
        export_tasks_to_csv(csv)
        csv << []
        export_commands_to_csv(csv)
      end
    end

    def export_deployments_to_csv(csv)
      csv << ['Deployments']
      csv << ['Timestamp', 'Success', 'Duration', 'Tasks Count', 'Success Count',
              'Pipeline Name', 'Hosts Count']
      @data[:deployments].each do |d|
        csv << [
          Time.at(d[:timestamp]).strftime('%Y-%m-%d %H:%M:%S'),
          d[:success],
          d[:duration],
          d[:tasks_count],
          d[:success_count],
          d[:pipeline_name],
          d[:hosts_count]
        ]
      end
    end

    def export_tasks_to_csv(csv)
      csv << ['Tasks']
      csv << ['Timestamp', 'Name', 'Success', 'Duration', 'Hosts Count',
              'Success Count']
      @data[:tasks].each do |t|
        csv << [
          Time.at(t[:timestamp]).strftime('%Y-%m-%d %H:%M:%S'),
          t[:name],
          t[:success],
          t[:duration],
          t[:hosts_count],
          t[:success_count]
        ]
      end
    end

    def export_commands_to_csv(csv)
      csv << ['Commands']
      csv << %w[Timestamp Name Host Success Duration]
      @data[:commands].each do |c|
        csv << [
          Time.at(c[:timestamp]).strftime('%Y-%m-%d %H:%M:%S'),
          c[:name],
          c[:host],
          c[:success],
          c[:duration]
        ]
      end
    end
  end
end
