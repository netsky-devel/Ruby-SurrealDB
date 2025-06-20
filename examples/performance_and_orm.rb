#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/surrealdb'

# SurrealDB Ruby SDK - Performance and ORM Examples
puts "=== SurrealDB Ruby SDK - Performance and ORM Examples ==="

# 1. High-Performance Client with Connection Pooling
puts "\n1. High-Performance Client Setup"

# Create high-performance client with connection pooling and caching
perf_client = SurrealDB.performance_connect(
  url: 'http://localhost:8000',
  pool_size: 10,           # Connection pool with 10 connections
  cache_enabled: true,     # Enable query result caching
  cache_ttl: 300,         # Cache TTL: 5 minutes
  namespace: 'test',
  database: 'test'
)

puts "✓ Performance client created with connection pooling"
puts "  - Pool size: 10 connections"
puts "  - Caching: enabled (TTL: 5 minutes)"

# 2. Connection Pool Operations
puts "\n2. Connection Pool Status"
puts "Connected: #{perf_client.connected?}"
puts "Cache stats: #{perf_client.cache_stats}"

# 3. Cached Queries
puts "\n3. Query Caching Demo"

# First query - will be cached
puts "\nExecuting query (will be cached)..."
result1 = perf_client.query(
  "SELECT * FROM users WHERE age > $age",
  { age: 18 },
  cache_key: "users_over_18"
)
puts "First query executed: #{result1.success?}"

# Second query with same cache key - will use cache
puts "\nExecuting same query (will use cache)..."
result2 = perf_client.query(
  "SELECT * FROM users WHERE age > $age",
  { age: 18 },
  cache_key: "users_over_18"
)
puts "Second query executed: #{result2.success?}"
puts "Cache stats after queries: #{perf_client.cache_stats}"

# 4. Batch Queries (requires connection pool)
puts "\n4. Batch Query Operations"

begin
  batch_results = perf_client.batch_query([
    { sql: "SELECT * FROM users LIMIT 5" },
    { sql: "SELECT * FROM posts WHERE published = $published", vars: { published: true } },
    { sql: "SELECT count() FROM comments GROUP ALL" }
  ])
  
  puts "✓ Batch queries executed successfully"
  puts "  - Number of results: #{batch_results.length}"
  batch_results.each_with_index do |result, i|
    puts "  - Query #{i + 1}: #{result.success? ? 'Success' : 'Failed'}"
  end
rescue SurrealDB::ConfigurationError => e
  puts "⚠ Batch queries require connection pooling: #{e.message}"
end

# 5. Bulk Insert Operations
puts "\n5. Bulk Insert Demo"

# Generate sample data
sample_users = (1..100).map do |i|
  {
    name: "User #{i}",
    email: "user#{i}@example.com",
    age: rand(18..65),
    created_at: Time.now.iso8601
  }
end

begin
  bulk_results = perf_client.bulk_insert('users', sample_users, chunk_size: 25)
  puts "✓ Bulk insert completed"
  puts "  - Records inserted: #{sample_users.length}"
  puts "  - Chunks processed: #{bulk_results.length}"
  puts "  - Success rate: #{bulk_results.count(&:success?)} / #{bulk_results.length}"
rescue SurrealDB::ConfigurationError => e
  puts "⚠ Bulk insert requires connection pooling: #{e.message}"
end

# 6. Regular Client vs Performance Client
puts "\n6. Client Comparison"

# Regular client (single connection)
regular_client = SurrealDB.connect(
  url: 'http://localhost:8000',
  namespace: 'test',
  database: 'test'
)

puts "Regular Client:"
puts "  - Connection pooling: disabled"
puts "  - Caching: disabled"
puts "  - Best for: simple applications, development"

puts "\nPerformance Client:"
puts "  - Connection pooling: enabled (#{perf_client.pool.size} connections)"
puts "  - Caching: #{perf_client.cache_enabled ? 'enabled' : 'disabled'}"
puts "  - Best for: high-traffic applications, production"

# 7. ORM-Style Model Usage
puts "\n7. ActiveRecord-style ORM"

# Define User model
class User < SurrealDB::Model
  table 'users'
  
  def full_info
    "#{name} (#{email}) - Age: #{age}"
  end
end

# Configure the model with our performance client
User.client = perf_client

puts "\nORM Operations:"

# Create new user
new_user = User.new(
  name: 'John Doe',
  email: 'john@example.com',
  age: 30
)

if new_user.save
  puts "✓ User created: #{new_user.id}"
  puts "  #{new_user.full_info}"
else
  puts "✗ Failed to create user"
end

# Find users
users = User.where('age > 25').limit(5)
puts "\n✓ Found #{users.length} users over 25:"
users.each do |user|
  puts "  - #{user.full_info}"
end

# Count records
total_users = User.count
puts "\n✓ Total users in database: #{total_users}"

# 8. Rails Integration Example
puts "\n8. Rails Integration"

puts "Rails integration provides:"
puts "  - Automatic configuration from database.yml"
puts "  - Controller helpers (surrealdb_client)"
puts "  - Transaction support (surrealdb_transaction)"
puts "  - Environment-specific settings"

puts "\nExample Rails controller usage:"
puts <<~RUBY
  class UsersController < ApplicationController
    def index
      @users = surrealdb_client.select('users')
    end
    
    def create
      surrealdb_transaction do
        user = surrealdb_client.create('users', user_params)
        redirect_to user_path(user.id) if user.success?
      end
    end
  end
RUBY

# 9. Performance Monitoring
puts "\n9. Performance Monitoring"

puts "Connection Pool Stats:"
if perf_client.pool
  puts "  - Available connections: #{perf_client.pool.available_connections}"
  puts "  - Total connections: #{perf_client.pool.size}"
end

puts "Cache Performance:"
cache_stats = perf_client.cache_stats
puts "  - Cache enabled: #{cache_stats[:enabled]}"
puts "  - Cached entries: #{cache_stats[:size]}"
puts "  - Cache TTL: #{cache_stats[:ttl]} seconds"

# 10. Cleanup
puts "\n10. Cleanup"

# Clear cache
perf_client.clear_cache
puts "✓ Cache cleared"

# Close connections
regular_client.close
perf_client.close
puts "✓ Connections closed"

puts "\n=== Performance and ORM Demo Complete ==="
puts "\nKey Benefits of Unified Client:"
puts "• Single class handles both simple and high-performance scenarios"
puts "• Optional connection pooling (set pool_size > 1)"
puts "• Optional query caching (set cache_enabled: true)"
puts "• Familiar ActiveRecord-style ORM"
puts "• Seamless Rails integration"
puts "• Production-ready performance optimizations"
