class AllowNullDueAtForSubtasks < ActiveRecord::Migration[8.0]
  def change
    change_column_null :tasks, :due_at, true
  end
end
