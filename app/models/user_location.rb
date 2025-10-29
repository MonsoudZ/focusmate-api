# frozen_string_literal: true

class UserLocation < ApplicationRecord
  # ----- Constants -----
  SOURCES = %w[gps network passive].freeze

  # ----- Associations -----
  belongs_to :user

  # ----- Soft delete -----
  default_scope { where(deleted_at: nil) }
  scope :with_deleted, -> { unscope(where: :deleted_at) }

  def soft_delete! = update!(deleted_at: Time.current)
  def restore!     = update!(deleted_at: nil)
  def deleted?     = deleted_at.present?

  # ----- Validations -----
  validates :latitude, presence: true,
                      numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :longitude, presence: true,
                       numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }
  validates :recorded_at, presence: true

  validates :accuracy,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1000 },
            allow_nil: true

  validates :source,
            inclusion: { in: SOURCES },
            allow_nil: true

  # ----- Callbacks -----
  before_validation :ensure_recorded_at_and_source

  # ----- Scopes -----
  scope :for_user, ->(u) { where(user_id: u.is_a?(User) ? u.id : u) }
  scope :recent, -> { where("recorded_at >= ?", 1.hour.ago) }
  scope :by_source, ->(s) { where(source: s) }

  # ----- Simple data accessors -----
  def coordinates = [ latitude, longitude ]

  def recent? = recorded_at.present? && recorded_at >= 1.hour.ago

  private

  def ensure_recorded_at_and_source
    self.recorded_at ||= Time.current
    self.source ||= "gps"
  end
end
