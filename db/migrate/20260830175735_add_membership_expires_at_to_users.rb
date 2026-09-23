class AddMembershipExpiresAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :membership_expires_at, :datetime
  end
end
