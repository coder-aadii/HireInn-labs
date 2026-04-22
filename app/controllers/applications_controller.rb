class ApplicationsController < ApplicationController
  before_action :authenticate_user!, except: :create

  def index
    base_scope = Application
      .joins(:job, :candidate)
      .where(jobs: { user_id: current_user.id })
      .includes(:candidate, :job, resume_attachment: :blob)
    @jobs = Job
      .where(user_id: current_user.id)
      .order(:title)
    @search_query = params[:q].to_s.strip
    @selected_job_id = params[:job_id].to_s.strip

    @applications = base_scope
    if @search_query.present?
      search_term = "%#{ActiveRecord::Base.sanitize_sql_like(@search_query)}%"
      @applications = @applications.where(
        "candidates.name ILIKE :term OR candidates.email ILIKE :term OR jobs.title ILIKE :term",
        term: search_term
      ).references(:candidate, :job)
    end

    if @selected_job_id.present?
      @applications = @applications.where(job_id: @selected_job_id)
    end

    @applications = @applications.order(created_at: :desc)
  end

  def show
    @application = Application
      .joins(:job)
      .where(jobs: { user_id: current_user.id })
      .includes(:candidate, :job, resume_attachment: :blob)
      .find(params[:id])
  end

  def create
    @job = Job.published.find_by!(slug: params[:career_id] || params[:id])

    payload = application_params
    candidate = Candidate.find_or_initialize_by(email: payload[:email].to_s.strip.downcase)
    candidate.assign_attributes(name: payload[:name].to_s.strip, phone: payload[:phone].to_s.strip)

    @application = @job.applications.new(candidate: candidate, cover_letter: payload[:cover_letter])
    @application.resume.attach(payload[:resume]) if payload[:resume].present?

    if candidate.save && @application.save
      CareerApplicationMailer.new_application(@application).deliver_later
      redirect_to career_path(@job), notice: "Application submitted successfully."
    else
      flash.now[:alert] = "Please complete all required fields and attach your resume."
      @application = @application
      render "careers/show", status: :unprocessable_entity
    end
  end

  private

  def application_params
    payload = params[:application].presence || params
    payload.permit(:name, :email, :phone, :cover_letter, :resume)
  end
end
