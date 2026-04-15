class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    @jobs = current_user.jobs.order(created_at: :desc)
    load_hiring_activity
  end

  private

  def load_hiring_activity
    window = 29.days.ago.to_date..Date.current
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
  end
end
