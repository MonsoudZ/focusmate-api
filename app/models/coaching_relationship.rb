class CoachingRelationship < ApplicationRecord
  enum :status, { pending: "pending", active: "active", inactive: "inactive", declined: "declined" }

  belongs_to :coach, class_name: "User"
  belongs_to :client, class_name: "User"
  has_many :memberships, dependent: :destroy
  has_many :lists, through: :memberships
  has_many :daily_summaries, dependent: :destroy
  has_many :item_visibility_restrictions, dependent: :destroy

  validates :coach_id, :client_id, presence: true
  validates :status, presence: true
  validates :client_id, uniqueness: { scope: :coach_id }
  validate :coach_and_client_different

  scope :between, ->(coach_id:, client_id:) { where(coach_id:, client_id:) }

  private

  def coach_and_client_different
    errors.add(:client_id, "cannot be the same as coach") if coach_id == client_id
  end
end
