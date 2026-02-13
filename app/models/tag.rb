# frozen_string_literal: true

class Tag < ApplicationRecord
  include Colorable

  belongs_to :user
  has_many :task_tags, dependent: :destroy
  has_many :tasks, through: :task_tags

  validates :name, presence: true, length: { maximum: 50 }
  validates :name, uniqueness: { scope: :user_id, case_sensitive: false }

  scope :alphabetical, -> { order(name: :asc) }
end
