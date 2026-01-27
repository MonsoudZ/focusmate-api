# frozen_string_literal: true

class AddTasksCountToTags < ActiveRecord::Migration[7.0]
  def up
    add_column :tags, :tasks_count, :integer, default: 0, null: false

    # Reset counters for existing records
    Tag.find_each do |tag|
      Tag.reset_counters(tag.id, :task_tags)
    end
  end

  def down
    remove_column :tags, :tasks_count
  end
end
