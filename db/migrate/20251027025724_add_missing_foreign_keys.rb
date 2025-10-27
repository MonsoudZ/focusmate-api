class AddMissingForeignKeys < ActiveRecord::Migration[8.0]
  def change
    # Add foreign key for tasks.assigned_to_id -> users.id (without validation)
    add_foreign_key :tasks, :users, column: :assigned_to_id, on_delete: :nullify, validate: false
    
    # Add check constraints for NOT NULL (without validation)
    add_check_constraint :users, "email IS NOT NULL", name: "users_email_null", validate: false
    add_check_constraint :users, "encrypted_password IS NOT NULL", name: "users_encrypted_password_null", validate: false
    add_check_constraint :lists, "name IS NOT NULL", name: "lists_name_null", validate: false
    add_check_constraint :tasks, "title IS NOT NULL", name: "tasks_title_null", validate: false
    add_check_constraint :tasks, "due_at IS NOT NULL", name: "tasks_due_at_null", validate: false
    add_check_constraint :tasks, "list_id IS NOT NULL", name: "tasks_list_id_null", validate: false
    add_check_constraint :tasks, "creator_id IS NOT NULL", name: "tasks_creator_id_null", validate: false
  end
end
