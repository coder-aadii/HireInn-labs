class Profile < ApplicationRecord
  belongs_to :user
  has_one_attached :avatar

  validates :first_name, presence: true
  validates :phone, uniqueness: true, allow_nil: true
  validate :avatar_is_valid

  def name
    [first_name, last_name].compact_blank.join(" ")
  end

  def initials
    [first_name, last_name].compact_blank.map { |part| part.first.to_s.upcase }.join.presence || user.email.to_s.first.to_s.upcase
  end

  private

  def avatar_is_valid
    return unless avatar.attached?

    unless avatar.blob.content_type.in?(%w[image/png image/jpeg image/jpg image/webp image/gif])
      errors.add(:avatar, "must be a PNG, JPG, WEBP, or GIF image")
    end

    return unless avatar.blob.byte_size > 5.megabytes

    errors.add(:avatar, "must be smaller than 5MB")
  end
end
