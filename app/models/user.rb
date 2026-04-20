class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum :role, { hr: 0, admin: 1 }
  validates :role, presence: true

  has_many :jobs, dependent: :destroy
  has_many :job_resumes
  has_one :profile, dependent: :destroy
end
