# This file should ensure the existence of records required to run the application in every environment.
# The code here is idempotent so that it can be executed at any point.

# Create admin user
admin = User.find_or_create_by!(email: 'admin@gestio.com') do |user|
  user.password = 'admin123'
  user.password_confirmation = 'admin123'
  user.role = 'admin'
  user.active = true
end

puts "Admin user created: #{admin.email} (role: #{admin.role})"
puts "\nSeed data created successfully!"
puts "Login credentials:"
puts "  Admin: admin@gestio.com / admin123"
