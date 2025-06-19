#!/usr/bin/env ruby
require 'bundler/setup'
require 'surrealdb'

# This example demonstrates basic usage of the SurrealDB Ruby gem
# Make sure you have SurrealDB running on localhost:8000

begin
  # Connect to SurrealDB
  puts "Connecting to SurrealDB..."
  client = SurrealDB.connect('http://localhost:8000')
  
  # Sign in (if authentication is required)
  # client.signin('root', 'root')
  
  # Use namespace and database
  client.use('test', 'test')
  puts "Connected and using test namespace and database"
  
  # Check if connection is alive
  if client.alive?
    puts "✓ Connection is alive"
  else
    puts "✗ Connection failed"
    exit 1
  end
  
  # Create some sample users
  puts "\nCreating sample users..."
  
  user1 = client.create('users', {
    name: 'John Doe',
    age: 30,
    email: 'john@example.com',
    active: true
  })
  puts "Created user: #{user1.first['id']}"
  
  user2 = client.create('users', {
    name: 'Jane Smith',
    age: 25,
    email: 'jane@example.com',
    active: true
  })
  puts "Created user: #{user2.first['id']}"
  
  user3 = client.create('users', {
    name: 'Bob Johnson',
    age: 35,
    email: 'bob@example.com',
    active: false
  })
  puts "Created user: #{user3.first['id']}"
  
  # Select all users
  puts "\nAll users:"
  all_users = client.select('users')
  all_users.each do |user|
    status = user['active'] ? 'Active' : 'Inactive'
    puts "- #{user['name']} (#{user['age']}) - #{status}"
  end
  
  # Select with conditions
  puts "\nActive users only:"
  active_users = client.select('users', { active: true })
  active_users.each do |user|
    puts "- #{user['name']} (#{user['email']})"
  end
  
  # Using query builder
  puts "\nUsers over 25 (using query builder):"
  older_users = client.query_builder
    .select('name', 'age', 'email')
    .from('users')
    .where('age > $min_age', { min_age: 25 })
    .order_by('age', 'DESC')
    .all
  
  older_users.each do |user|
    puts "- #{user['name']} is #{user['age']} years old"
  end
  
  # Update a user
  puts "\nUpdating Bob's status to active..."
  client.update('users', { active: true }, { name: 'Bob Johnson' })
  
  # Count users
  total_users = client.count('users')
  active_count = client.count('users', { active: true })
  puts "\nTotal users: #{total_users}"
  puts "Active users: #{active_count}"
  
  # Find a specific user by ID (you'd need the actual ID)
  first_user = client.first('users')
  if first_user
    puts "\nFirst user found: #{first_user['name']}"
    
    # Find by ID
    found_user = client.find('users', first_user['id'].split(':').last)
    puts "Found user by ID: #{found_user.first['name']}" if found_user.first
  end
  
  # Raw SQL query
  puts "\nExecuting raw SQL query..."
  result = client.query('SELECT name, age FROM users WHERE age > $age ORDER BY age', { age: 20 })
  result.each do |user|
    puts "- #{user['name']} is #{user['age']} years old"
  end
  
  # Clean up - delete all test users
  puts "\nCleaning up test data..."
  deleted = client.delete('users')
  puts "Deleted #{deleted.count} users"
  
  puts "\n✓ Example completed successfully!"
  
rescue SurrealDB::ConnectionError => e
  puts "Connection error: #{e.message}"
  puts "Make sure SurrealDB is running on localhost:8000"
rescue SurrealDB::QueryError => e
  puts "Query error: #{e.message}"
rescue SurrealDB::AuthenticationError => e
  puts "Authentication error: #{e.message}"
rescue => e
  puts "Unexpected error: #{e.message}"
  puts e.backtrace.join("\n")
ensure
  # Close the connection
  client&.close
  puts "Connection closed"
end 