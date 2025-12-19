# frozen_string_literal: true

class Membership < ApplicationRecord
  belongs_to :list
  belongs_to :user

  validates :role, presence: true, inclusion: { in: %w[editor viewer] }
  validates :user_id, uniqueness: { scope: :list_id, message: "is already a member of this list" }

  scope :editors, -> { where(role: "editor") }
  scope :viewers, -> { where(role: "viewer") }

  def can_edit?
    role == "editor"
  end
end
