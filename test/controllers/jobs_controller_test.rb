require "test_helper"

class JobsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "jobs-owner@example.com",
      password: "password123",
      role: :hr
    )

    @job = Job.create!(
      user: @user,
      title: "Operations Manager",
      status: :draft,
      company_name: "HireInn Labs",
      location: "Indore",
      employment_type: "Full-time",
      description: "Lead the hiring workflow and coordinate operations."
    )

    sign_in @user
  end

  test "should get index" do
    get jobs_path
    assert_response :success
  end

  test "should get new" do
    get new_job_path
    assert_response :success
  end

  test "should get show" do
    get job_path(@job)
    assert_response :success
  end

  test "should get edit" do
    get edit_job_path(@job)
    assert_response :success
  end
end
