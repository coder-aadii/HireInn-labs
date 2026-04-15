class Candidate < ApplicationRecord
  has_many :applications, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true

  before_validation :normalize_email

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end
end
