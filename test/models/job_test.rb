require "test_helper"

class JobTest < ActiveSupport::TestCase
  test "minimum_experience_label handles fresher roles" do
    job = Job.new(experience_min: 0)

    assert_equal "Fresher / 0 years", job.minimum_experience_label
  end

  test "minimum_experience_label handles sub-year experience" do
    job = Job.new(experience_min: 0.5)

    assert_equal "6 months", job.minimum_experience_label
  end

  test "minimum_experience_label handles whole years" do
    job = Job.new(experience_min: 2)

    assert_equal "2+ years", job.minimum_experience_label
  end
end
