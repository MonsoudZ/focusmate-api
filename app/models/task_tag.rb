# frozen_string_literal: true

class TaskTag < ApplicationRecord
  belongs_to :task
  belongs_to :tag, counter_cache: :tasks_count

  validates :tag_id, uniqueness: { scope: :task_id }
end
