# frozen_string_literal: true

class AddTrigramSearchToTasks < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    # Enable pg_trgm extension for trigram similarity search
    enable_extension "pg_trgm"

    # Add trigram GIN indexes on title and note
    # These indexes accelerate ILIKE queries with leading wildcards
    add_index :tasks, :title, using: :gin, opclass: :gin_trgm_ops,
              algorithm: :concurrently, name: "index_tasks_on_title_trgm"
    add_index :tasks, :note, using: :gin, opclass: :gin_trgm_ops,
              algorithm: :concurrently, name: "index_tasks_on_note_trgm"
  end

  def down
    remove_index :tasks, name: "index_tasks_on_title_trgm", if_exists: true
    remove_index :tasks, name: "index_tasks_on_note_trgm", if_exists: true

    disable_extension "pg_trgm"
  end
end
