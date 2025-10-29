class ValidateMissingForeignKeys < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    # Validate foreign key
    validate_foreign_key :tasks, :users

    # Validate check constraints and convert to NOT NULL
    validate_check_constraint :users, name: "users_email_null"
    change_column_null :users, :email, false
    remove_check_constraint :users, name: "users_email_null"

    validate_check_constraint :users, name: "users_encrypted_password_null"
    change_column_null :users, :encrypted_password, false
    remove_check_constraint :users, name: "users_encrypted_password_null"

    validate_check_constraint :lists, name: "lists_name_null"
    change_column_null :lists, :name, false
    remove_check_constraint :lists, name: "lists_name_null"

    validate_check_constraint :tasks, name: "tasks_title_null"
    change_column_null :tasks, :title, false
    remove_check_constraint :tasks, name: "tasks_title_null"

    validate_check_constraint :tasks, name: "tasks_due_at_null"
    change_column_null :tasks, :due_at, false
    remove_check_constraint :tasks, name: "tasks_due_at_null"

    validate_check_constraint :tasks, name: "tasks_list_id_null"
    change_column_null :tasks, :list_id, false
    remove_check_constraint :tasks, name: "tasks_list_id_null"

    validate_check_constraint :tasks, name: "tasks_creator_id_null"
    change_column_null :tasks, :creator_id, false
    remove_check_constraint :tasks, name: "tasks_creator_id_null"
  end

  def down
    # Revert NOT NULL constraints
    change_column_null :tasks, :creator_id, true
    change_column_null :tasks, :list_id, true
    change_column_null :tasks, :due_at, true
    change_column_null :tasks, :title, true
    change_column_null :lists, :name, true
    change_column_null :users, :encrypted_password, true
    change_column_null :users, :email, true

    # Remove foreign key
    remove_foreign_key :tasks, :users
  end
end
