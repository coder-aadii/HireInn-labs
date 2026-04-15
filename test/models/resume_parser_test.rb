require "test_helper"

class ResumeParserTest < ActiveSupport::TestCase
  test "extracts explicit labeled name" do
    parser = ResumeParser.new(fake_attachment)
    text = <<~TEXT
      Name: Aditya Aerpule
      Email: aditya@example.com
    TEXT

    assert_equal "Aditya Aerpule", parser.send(:extract_name, text)
  end

  test "extracts name from first meaningful header line" do
    parser = ResumeParser.new(fake_attachment)
    text = <<~TEXT

      Aditya Aerpule
      aditya@example.com
      +91 9074703157
      LinkedIn: linkedin.com/in/aditya
    TEXT

    assert_equal "Aditya Aerpule", parser.send(:extract_name, text)
  end

  test "ignores role titles and contact lines when searching for a name" do
    parser = ResumeParser.new(fake_attachment)
    text = <<~TEXT
      Assistant RoR Developer
      adityaaerpule@gmail.com
      +91 9074703157
      Aditya Aerpule
      Indore, India
    TEXT

    assert_equal "Aditya Aerpule", parser.send(:extract_name, text)
  end

  test "returns nil when no plausible name is present" do
    parser = ResumeParser.new(fake_attachment)
    text = <<~TEXT
      Resume
      email@example.com
      +91 9999999999
      github.com/example
    TEXT

    assert_nil parser.send(:extract_name, text)
  end

  private

  def fake_attachment
    Struct.new(:attached?).new(true)
  end
end
