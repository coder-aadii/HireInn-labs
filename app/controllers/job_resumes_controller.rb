class JobResumesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_job

  def create
    files = Array(params.dig(:job_resume, :files))
      .select { |file| file.respond_to?(:original_filename) && file.original_filename.present? }

    if files.blank?
      return redirect_to job_path(@job, tab: "resume"), alert: "Please attach at least one resume."
    end

    if files.size > 5
      return redirect_to job_path(@job, tab: "resume"), alert: "You can upload up to 5 resumes at once."
    end

    created = 0
    failures = []

    files.each do |file|
      resume = @job.job_resumes.new(user: current_user)
      resume.resume.attach(file)

      unless resume.save
        failures << file.original_filename
        next
      end

      parsed = ResumeParser.new(resume.resume).call.transform_keys(&:to_s)
      resume.update(
        parsed_data: parsed,
        parsed_at: parsed["error"].blank? ? Time.current : resume.parsed_at,
        name: parsed["name"],
        email: parsed["email"],
        phone: parsed["phone"],
        skills: Array(parsed["skills"]),
        education: Array(parsed["education"])
      )

      created += 1
    end

    if failures.any?
      redirect_to job_path(@job, tab: "resume"),
        alert: "Uploaded #{created} resume(s). Failed: #{failures.join(', ')}."
    else
      redirect_to job_path(@job, tab: "resume"),
        notice: "Uploaded #{created} resume(s) and parsed successfully."
    end
  end

  def match
    scope = @job.job_resumes.where(user: current_user)
    ids = Array(params[:resume_ids]).map(&:to_i)
    scope = scope.where(id: ids) if ids.any? && params[:match_all].blank?

    if scope.none?
      return redirect_to job_path(@job, tab: "resume"), alert: "Select resumes to match."
    end

    analyzer = Ai::ResumeAnalyzer.new
    matched = 0
    skipped = []

    scope.find_each do |resume|
      if resume.match_score.present? && resume.analysis_json.present? && resume.analysis_json["error"].blank?
        skipped << (resume.name.presence || "Candidate #{resume.id}")
        next
      end

      if resume.parsed_data.blank? || resume.parsed_data["error"].present?
        parsed = ResumeParser.new(resume.resume).call.transform_keys(&:to_s)
        resume.update(
          parsed_data: parsed,
          parsed_at: parsed["error"].blank? ? Time.current : resume.parsed_at,
          name: parsed["name"],
          email: parsed["email"],
          phone: parsed["phone"],
          skills: Array(parsed["skills"]),
          education: Array(parsed["education"])
        )
      end

      result = analyzer.call(job: @job, resume: resume)
      resume.update(
        match_score: result[:match_score],
        analysis_json: result[:analysis],
        matched_at: Time.current
      )
      matched += 1
    rescue Ai::ResumeAnalyzer::Error => e
      resume.update(
        analysis_json: { error: e.message },
        matched_at: Time.current
      )
    end

    message = []
    message << "Matched #{matched} resume(s)." if matched.positive?
    if skipped.any?
      message << "Already matched: #{skipped.join(', ')}. See their details."
    end
    notice_text = message.join(" ")

    if notice_text.present?
      redirect_to job_path(@job, tab: "resume"), notice: notice_text
    else
      redirect_to job_path(@job, tab: "resume"), alert: "No resumes selected to match."
    end
  end

  private

  def set_job
    @job = current_user.jobs.find_by!(slug: params[:job_id])
  end
end
