# Remove all demo users except for admin
User.where.not(email: 'admin@gestio.com').destroy_all

# Ensure admin user exists and reset password to admin123
admin = User.find_or_initialize_by(email: 'admin@gestio.com')
admin.password = 'admin123'
admin.password_confirmation = 'admin123'
admin.role = 'admin'
admin.active = true
admin.save!

puts "Admin user initialized: #{admin.email} (role: #{admin.role})"
puts "\nSeed data cleaned and initialized successfully!"
