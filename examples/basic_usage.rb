#!/usr/bin/env ruby
require 'bundler/setup'
require 'surrealdb'

# Demonstrates basic usage of the SurrealDB Ruby gem
# Requires SurrealDB running on localhost:8000
class SurrealDBExample
  DEFAULT_CONNECTION_URL = 'http://localhost:8000'
  DEFAULT_NAMESPACE = 'test'
  DEFAULT_DATABASE = 'test'
  MIN_AGE_THRESHOLD = 25
  QUERY_AGE_THRESHOLD = 20

  def initialize(connection_url = DEFAULT_CONNECTION_URL)
    @connection_url = connection_url
    @client = nil
  end

  def run
    establish_connection
    demonstrate_crud_operations
    demonstrate_queries
    cleanup_test_data
    display_success_message
  rescue SurrealDB::ConnectionError => e
    handle_connection_error(e)
  rescue SurrealDB::QueryError => e
    handle_query_error(e)
  rescue SurrealDB::AuthenticationError => e
    handle_authentication_error(e)
  rescue => e
    handle_unexpected_error(e)
  ensure
    close_connection
  end

  private

  def establish_connection
    puts "Connecting to SurrealDB..."
    @client = SurrealDB.connect(@connection_url)
    @client.use(DEFAULT_NAMESPACE, DEFAULT_DATABASE)
    puts "Connected and using #{DEFAULT_NAMESPACE} namespace and #{DEFAULT_DATABASE} database"
    
    verify_connection
  end

  def verify_connection
    if @client.alive?
      puts "✓ Connection is alive"
    else
      puts "✗ Connection failed"
      exit 1
    end
  end

  def demonstrate_crud_operations
    create_sample_users
    display_all_users
    display_active_users
    update_user_status
    display_user_statistics
  end

  def create_sample_users
    puts "\nCreating sample users..."
    
    sample_users_data.each do |user_data|
      user = @client.create('users', user_data)
      puts "Created user: #{user.first['id']}"
    end
  end

  def sample_users_data
    [
      {
        name: 'John Doe',
        age: 30,
        email: 'john@example.com',
        active: true
      },
      {
        name: 'Jane Smith',
        age: 25,
        email: 'jane@example.com',
        active: true
      },
      {
        name: 'Bob Johnson',
        age: 35,
        email: 'bob@example.com',
        active: false
      }
    ]
  end

  def display_all_users
    puts "\nAll users:"
    all_users = @client.select('users')
    all_users.each { |user| display_user_with_status(user) }
  end

  def display_active_users
    puts "\nActive users only:"
    active_users = @client.select('users', { active: true })
    active_users.each { |user| display_user_with_email(user) }
  end

  def display_user_with_status(user)
    status = user['active'] ? 'Active' : 'Inactive'
    puts "- #{user['name']} (#{user['age']}) - #{status}"
  end

  def display_user_with_email(user)
    puts "- #{user['name']} (#{user['email']})"
  end

  def update_user_status
    puts "\nUpdating Bob's status to active..."
    @client.update('users', { active: true }, { name: 'Bob Johnson' })
  end

  def display_user_statistics
    total_users = @client.count('users')
    active_count = @client.count('users', { active: true })
    puts "\nTotal users: #{total_users}"
    puts "Active users: #{active_count}"
  end

  def demonstrate_queries
    demonstrate_query_builder
    demonstrate_user_lookup
    demonstrate_raw_sql_query
  end

  def demonstrate_query_builder
    puts "\nUsers over #{MIN_AGE_THRESHOLD} (using query builder):"
    older_users = @client.query_builder
      .select('name', 'age', 'email')
      .from('users')
      .where('age > $min_age', { min_age: MIN_AGE_THRESHOLD })
      .order_by('age', 'DESC')
      .all
    
    older_users.each { |user| display_user_with_age(user) }
  end

  def display_user_with_age(user)
    puts "- #{user['name']} is #{user['age']} years old"
  end

  def demonstrate_user_lookup
    first_user = @client.first('users')
    return unless first_user
    
    puts "\nFirst user found: #{first_user['name']}"
    
    user_id = extract_user_id(first_user['id'])
    found_user = @client.find('users', user_id)
    
    if found_user.first
      puts "Found user by ID: #{found_user.first['name']}"
    end
  end

  def extract_user_id(full_id)
    full_id.split(':').last
  end

  def demonstrate_raw_sql_query
    puts "\nExecuting raw SQL query..."
    result = @client.query(
      'SELECT name, age FROM users WHERE age > $age ORDER BY age',
      { age: QUERY_AGE_THRESHOLD }
    )
    result.each { |user| display_user_with_age(user) }
  end

  def cleanup_test_data
    puts "\nCleaning up test data..."
    deleted = @client.delete('users')
    puts "Deleted #{deleted.count} users"
  end

  def display_success_message
    puts "\n✓ Example completed successfully!"
  end

  def handle_connection_error(error)
    puts "Connection error: #{error.message}"
    puts "Make sure SurrealDB is running on localhost:8000"
  end

  def handle_query_error(error)
    puts "Query error: #{error.message}"
  end

  def handle_authentication_error(error)
    puts "Authentication error: #{error.message}"
  end

  def handle_unexpected_error(error)
    puts "Unexpected error: #{error.message}"
    puts error.backtrace.join("\n")
  end

  def close_connection
    @client&.close
    puts "Connection closed"
  end
end

# Execute the example
if __FILE__ == $0
  example = SurrealDBExample.new
  example.run
end