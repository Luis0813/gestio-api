# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create admin user
admin = User.find_or_create_by!(email: 'admin@gestio.com') do |user|
  user.password = 'admin123'
  user.password_confirmation = 'admin123'
  user.role = 'admin'
  user.active = true
end

puts "Admin user created: #{admin.email} (role: #{admin.role})"

# Create company user
company = User.find_or_create_by!(email: 'empresa@gestio.com') do |user|
  user.password = 'empresa123'
  user.password_confirmation = 'empresa123'
  user.role = 'company'
  user.company_name = 'Empresa Demo'
  user.active = true
end

puts "Company user created: #{company.email} (role: #{company.role}, company: #{company.company_name})"

puts "\nSeed data created successfully!"
puts "Login credentials:"
puts "  Admin: admin@gestio.com / admin123"
puts "  Company: empresa@gestio.com / empresa123"
