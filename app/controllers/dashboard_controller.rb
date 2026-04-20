class DashboardController < ApplicationController
  before_action :authenticate_user!

  CHART_SCALE_OPTIONS = [3, 5, 8, 10, 15].freeze
  PERIOD_OPTIONS = {
    "week" => { label: "Last 7 days", days: 6 },
    "month" => { label: "Last 30 days", days: 29 },
    "3_months" => { label: "Last 3 months", days: 89 },
    "6_months" => { label: "Last 6 months", days: 179 },
    "year" => { label: "Last year", days: 364 }
  }.freeze

  def index
    @jobs = current_user.jobs.includes(:applications, :job_resumes).order(created_at: :desc)
    @ai_analyses_count = JobResume.where(user: current_user).where.not(matched_at: nil).count
    load_hiring_activity
  end

  private

  def load_hiring_activity
    @chart_period_options = PERIOD_OPTIONS.map { |key, config| [config[:label], key] }
    @selected_chart_period = PERIOD_OPTIONS.key?(params[:period]) ? params[:period] : "month"
    period_config = PERIOD_OPTIONS.fetch(@selected_chart_period)
    @selected_chart_period_label = period_config[:label]

    window = period_config[:days].days.ago.to_date..Date.current
    dates = window.to_a

    applications_scope = Application.joins(:job).where(jobs: { user_id: current_user.id })
    recent_applications = applications_scope.where(created_at: window.first.beginning_of_day..window.last.end_of_day)
    recent_jobs = current_user.jobs.where(created_at: window.first.beginning_of_day..window.last.end_of_day)

    jobs_by_day = recent_jobs.group("DATE(jobs.created_at)").count
    applications_by_day = recent_applications.reorder(nil).group("DATE(applications.created_at)").count

    @hiring_activity = dates.map do |date|
      {
        date: date,
        jobs: jobs_by_day[date] || 0,
        applications: applications_by_day[date] || 0
      }
    end

    @hiring_activity_totals = {
      jobs: @hiring_activity.sum { |point| point[:jobs] },
      applications: @hiring_activity.sum { |point| point[:applications] },
      peak_day: @hiring_activity.max_by { |point| point[:applications] + point[:jobs] }
    }

    @chart_scale_options = CHART_SCALE_OPTIONS
    actual_max = @hiring_activity.map { |point| [point[:jobs], point[:applications]].max }.max.to_i
    requested_scale = params[:scale].to_i
    @selected_chart_scale = if CHART_SCALE_OPTIONS.include?(requested_scale)
      [requested_scale, actual_max, 1].max
    else
      [actual_max, 1].max
    end
  end
end
