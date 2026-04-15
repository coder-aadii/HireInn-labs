class Job < ApplicationRecord
  belongs_to :user
  has_many :applications, dependent: :destroy
  has_many :job_resumes, dependent: :destroy

  enum :status, { draft: 0, published: 1, archived: 2 }

  validates :title, presence: true
  validates :slug, uniqueness: true
  validates :experience_min, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true

  before_validation :generate_slug, on: :create

  scope :published, -> { where(status: :published) }
  scope :search, ->(query) { where("title ILIKE ?", "%#{query}%") if query.present? }

  def to_param
    slug
  end

  def minimum_experience_label
    value = experience_min
    return "Not specified" if value.blank?

    decimal_value = value.to_d
    return "Fresher / 0 years" if decimal_value.zero?

    if decimal_value < 1
      months = (decimal_value * 12).round
      return "#{months} months" if months.positive?
    end

    normalized = decimal_value.frac.zero? ? decimal_value.to_i.to_s : format("%<value>.1f", value: decimal_value.to_f)
    "#{normalized}+ years"
  end

  private

    def generate_slug
      return if slug.present?

      base = title.to_s.parameterize.split("-").first(2).join("-")
      base = "job" if base.blank?

      loop do
        random = SecureRandom.alphanumeric(8).downcase
        candidate = "#{base}-#{random}"

        unless self.class.exists?(slug: candidate)
          self.slug = candidate
          break
        end
      end
    end
end
