class JobsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_job, only: %i[show edit update destroy]

  def index
    @query = params[:q]
    @jobs = current_user.jobs.order(created_at: :desc)
    @jobs = @jobs.search(@query) if @query.present?
  end

  def show
    @job_resumes = @job.job_resumes.order(created_at: :desc)
    @resumes = @job_resumes
  end

  def new
    @job = current_user.jobs.new
  end

  def create
    @job = current_user.jobs.new(job_params)
    if params[:generate_ai].present?
      generate_ai_description!
      status = flash.now[:alert].present? ? :unprocessable_entity : :ok
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("flash", partial: "shared/flash"),
            turbo_stream.replace("ai_notice", partial: "jobs/ai_notice"),
            turbo_stream.replace("job_ai_preview", partial: "jobs/ai_preview", locals: { job: @job }),
            turbo_stream.replace("job_form", partial: "jobs/form", locals: { job: @job })
          ], status: status
        end
        format.html { render :new, status: status }
      end
      return
    end

    apply_skills!
    apply_publish_timestamp!

    if @job.save
      redirect_to @job, notice: "Job created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @job.assign_attributes(job_params)
    apply_skills!
    apply_publish_timestamp!

    if @job.save
      redirect_to @job, notice: "Job updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @job.destroy
    redirect_to jobs_path, notice: "Job deleted."
  end

  private

  def set_job
    @job = current_user.jobs.find_by!(slug: params[:id])
  end

  def job_params
    params.require(:job).permit(
      :title,
      :company_name,
      :description,
      :requirements,
      :responsibilities,
      :benefits,
      :location,
      :employment_type,
      :experience_min,
      :salary_min,
      :salary_max,
      :currency,
      :status,
      :ai_generated,
      :skills_required,
      :expires_at
    )
  end

  def apply_skills!
    return unless params.dig(:job, :skills_required)

    skills = params[:job][:skills_required].to_s.split(",").map(&:strip).reject(&:blank?)
    @job.skills_required = skills
  end

  def apply_publish_timestamp!
    if @job.published?
      @job.published_at ||= Time.current
    else
      @job.published_at = nil
    end
  end

  def generate_ai_description!
    generator = Ai::JobDescriptionGenerator.new
    result = generator.call(
      title: @job.title,
      company_name: @job.company_name,
      location: @job.location,
      employment_type: @job.employment_type,
      experience_min: @job.experience_min
    )

    @job.description = result[:description_markdown]
    @job.responsibilities = format_bullets(result[:responsibilities])
    @job.requirements = format_bullets(result[:requirements])
    @job.benefits = format_bullets(result[:benefits])
    @job.skills_required = Array(result[:skills])
    @job.ai_generated = true
    @job.ai_metadata = result[:metadata] || {}

    flash.now[:notice] = "AI description generated. Review and publish when ready."
  rescue Ai::JobDescriptionGenerator::Error => e
    Rails.logger.error("[AI JD] #{e.message}")
    flash.now[:alert] = e.message
  end

  def format_bullets(items)
    return if items.blank?

    Array(items).map { |item| "- #{item}" }.join("\n")
  end
end
