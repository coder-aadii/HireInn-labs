class Job < ApplicationRecord
  belongs_to :user
  has_many :applications, dependent: :destroy
  has_many :job_resumes, dependent: :destroy

  enum :status, { draft: 0, published: 1, archived: 2 }

  validates :title, presence: true
  validates :slug, uniqueness: true

  before_validation :generate_slug, on: :create

  scope :published, -> { where(status: :published) }
  scope :search, ->(query) { where("title ILIKE ?", "%#{query}%") if query.present? }

  def to_param
    slug
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
