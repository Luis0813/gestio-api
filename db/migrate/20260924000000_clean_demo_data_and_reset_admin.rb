class CleanDemoDataAndResetAdmin < ActiveRecord::Migration[8.0]
  def up
    # Remove demo accounts (keep only admin@gestio.com)
    User.where.not(email: 'admin@gestio.com').destroy_all

    # Ensure admin user exists with password admin123
    admin = User.find_or_initialize_by(email: 'admin@gestio.com')
    admin.password = 'admin123'
    admin.password_confirmation = 'admin123'
    admin.role = 'admin'
    admin.active = true
    admin.save!
  end

  def down
  end
end
