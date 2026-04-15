require "test_helper"

class ApplicationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailer::Base.deliveries.clear

    @user = User.create!(
      email: "owner@example.com",
      password: "password123",
      role: :hr
    )

    @job = Job.create!(
      user: @user,
      title: "Senior Product Designer",
      slug: "senior-product-designer",
      status: :published,
      company_name: "HireInn Labs",
      location: "Remote",
      employment_type: "Full-time",
      description: "Lead premium product experiences."
    )
  end

  test "creates an application and emails the applicant" do
    assert_difference -> { Candidate.count }, 1 do
      assert_difference -> { Application.count }, 1 do
        post career_applications_path(@job), params: {
          application: {
            name: "Jane Candidate",
            email: "jane@example.com",
            phone: "+1 555 0199",
            cover_letter: "I would love to contribute to HireInn Labs.",
            resume: fixture_file_upload("files/resume.txt", "text/plain")
          }
        }
      end
    end

    assert_redirected_to career_path(@job)
    assert_equal "Application submitted successfully.", flash[:notice]

    email = ActionMailer::Base.deliveries.last
    assert_not_nil email
    assert_equal ["jane@example.com"], email.to
    assert_match "Application received for Senior Product Designer", email.subject
    assert_match "Jane Candidate", email.html_part.body.to_s
    assert_match "Your application has been received", email.html_part.body.to_s
    assert_match "We have received your application successfully", email.text_part.body.to_s
  end
end
