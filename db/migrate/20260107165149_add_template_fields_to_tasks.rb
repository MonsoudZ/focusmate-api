class AddTemplateFieldsToTasks < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      # Template type (new)
      add_column :tasks, :template_type, :string unless column_exists?(:tasks, :template_type)

      # Rename recurring_template_id to template_id for generic use
      if column_exists?(:tasks, :recurring_template_id) && !column_exists?(:tasks, :template_id)
        rename_column :tasks, :recurring_template_id, :template_id
      end

      # Instance tracking (new)
      add_column :tasks, :instance_date, :date unless column_exists?(:tasks, :instance_date)
      add_column :tasks, :instance_number, :integer unless column_exists?(:tasks, :instance_number)

      # Recurrence count (new - for "stop after X occurrences")
      add_column :tasks, :recurrence_count, :integer unless column_exists?(:tasks, :recurrence_count)

      # Indexes
      add_index :tasks, :is_template unless index_exists?(:tasks, :is_template)
      add_index :tasks, :template_type unless index_exists?(:tasks, :template_type)
      add_index :tasks, :instance_date unless index_exists?(:tasks, :instance_date)
    end
  end
end
