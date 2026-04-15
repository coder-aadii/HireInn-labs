class Application < ApplicationRecord
  belongs_to :job
  belongs_to :candidate
  has_one_attached :resume

  validates :status, presence: true
  validate :resume_attached

  private

  def resume_attached
    return if resume.attached?

    errors.add(:resume, "must be attached")
  end
end
