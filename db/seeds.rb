# Remove all demo users except for admin
User.where.not(email: 'admin@gestio.com').destroy_all

# Create or find admin user
admin = User.find_or_create_by!(email: 'admin@gestio.com') do |user|
  user.password = 'admin123'
  user.password_confirmation = 'admin123'
  user.role = 'admin'
  user.active = true
end

puts "Admin user initialized: #{admin.email} (role: #{admin.role})"
puts "\nSeed data cleaned and initialized successfully!"
