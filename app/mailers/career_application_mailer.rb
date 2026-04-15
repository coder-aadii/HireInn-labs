class CareerApplicationMailer < ApplicationMailer
  helper ActionView::Helpers::NumberHelper

  def new_application(application)
    @application = application
    @job = application.job
    @candidate = application.candidate

    logo_path = Rails.root.join("app/assets/images/hireinn_logo.png")
    if File.exist?(logo_path)
      attachments.inline["hireinn_logo.png"] = {
        mime_type: "image/png",
        content: File.binread(logo_path)
      }
    end

    mail(
      to: @candidate.email,
      subject: "Application received for #{@job.title}"
    )
  end
end
