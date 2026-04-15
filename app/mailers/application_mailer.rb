class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "notifications@hireinnlabs.local")
  layout "mailer"
end
