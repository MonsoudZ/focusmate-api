class ListInvite < ApplicationRecord
  belongs_to :list
  belongs_to :inviter, class_name: "User"

  ROLES = %w[viewer editor].freeze
  CODE_LENGTH = 8

  validates :code, presence: true, uniqueness: true
  validates :role, presence: true, inclusion: { in: ROLES }
  validates :max_uses, numericality: { greater_than: 0 }, allow_nil: true

  before_validation :generate_code, on: :create

  scope :active, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :available, -> { active.where("max_uses IS NULL OR uses_count < max_uses") }

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def exhausted?
    max_uses.present? && uses_count >= max_uses
  end

  def usable?
    !expired? && !exhausted?
  end

  def invite_url
    "#{base_url}/invite/#{code}"
  end

  private

  def generate_code
    self.code ||= loop do
      random_code = SecureRandom.alphanumeric(CODE_LENGTH).upcase
      break random_code unless ListInvite.exists?(code: random_code)
    end
  end

  def base_url
    ENV.fetch("APP_URL", "https://focusmate.app")
  end
end
