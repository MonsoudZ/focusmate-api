class AddInvitationFieldsToListShares < ActiveRecord::Migration[8.0]
  def change
    add_column :list_shares, :email, :string
    add_column :list_shares, :role, :integer, default: 0
    add_column :list_shares, :status, :string, default: 'pending'
    add_column :list_shares, :invitation_token, :string
    add_column :list_shares, :invited_at, :datetime
    add_column :list_shares, :accepted_at, :datetime
    
    # Make user_id optional for pending invitations
    change_column_null :list_shares, :user_id, true
    
    # Add indexes
    add_index :list_shares, :invitation_token, unique: true
    add_index :list_shares, :status
    add_index :list_shares, :role
    add_index :list_shares, :email
  end
end
