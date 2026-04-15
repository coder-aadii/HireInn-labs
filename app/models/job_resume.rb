class JobResume < ApplicationRecord
  belongs_to :job
  belongs_to :user
  has_one_attached :resume

  validate :resume_attached
  validate :resume_content_type

  private

  def resume_attached
    return if resume.attached?

    errors.add(:resume, "must be attached")
  end

  def resume_content_type
    return unless resume.attached?

    allowed = %w[application/pdf application/msword application/vnd.openxmlformats-officedocument.wordprocessingml.document]
    return if allowed.include?(resume.blob.content_type)

    errors.add(:resume, "must be a PDF, DOC, or DOCX file")
  end
end
