class ApplicationsController < ApplicationController
  before_action :authenticate_user!, except: :create

  def index
    @applications = Application
      .joins(:job)
      .where(jobs: { user_id: current_user.id })
      .includes(:candidate, :job, resume_attachment: :blob)
      .order(created_at: :desc)
  end

  def show
    @application = Application
      .joins(:job)
      .where(jobs: { user_id: current_user.id })
      .includes(:candidate, :job, resume_attachment: :blob)
      .find(params[:id])
  end

  def create
    @job = Job.published.find_by!(slug: params[:id])

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
