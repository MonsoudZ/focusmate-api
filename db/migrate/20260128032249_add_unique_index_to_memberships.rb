class AddUniqueIndexToMemberships < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    remove_index :memberships, name: :index_memberships_on_list_user, if_exists: true
    remove_index :memberships, name: :index_memberships_on_user_list, if_exists: true

    add_index :memberships, [ :user_id, :list_id ], unique: true,
              name: :index_memberships_on_user_id_and_list_id,
              algorithm: :concurrently
  end
end
