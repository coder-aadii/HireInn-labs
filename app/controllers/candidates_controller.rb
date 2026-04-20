class CandidatesController < ApplicationController
  before_action :authenticate_user!

  def index
    @applications = Application
      .joins(:job)
      .where(jobs: { user_id: current_user.id })
      .includes(:candidate, :job, resume_attachment: :blob)
      .order(created_at: :desc)

    grouped = @applications.group_by(&:candidate)

    @candidate_cards = grouped.map do |candidate, applications|
      latest_application = applications.max_by(&:created_at)

      {
        candidate: candidate,
        applications: applications,
        applications_count: applications.size,
        active_jobs_count: applications.map(&:job_id).uniq.size,
        latest_application: latest_application,
        latest_job: latest_application&.job,
        latest_status: latest_application&.status,
        last_applied_at: latest_application&.created_at
      }
    end.sort_by { |entry| entry[:last_applied_at] || Time.at(0) }.reverse

    @candidate_stats = {
      total: @candidate_cards.size,
      new_this_week: @candidate_cards.count { |entry| entry[:last_applied_at]&.>= 7.days.ago },
      active_conversations: @candidate_cards.count { |entry| entry[:applications_count] > 1 },
      resumes_attached: @applications.count { |application| application.resume.attached? }
    }
  end
end
