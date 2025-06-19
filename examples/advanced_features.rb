#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/surrealdb'

# Advanced SurrealDB Features Demo
# This example demonstrates the extended functionality for SurrealDB 2.0+

def main
  puts "🚀 SurrealDB Advanced Features Demo"
  puts "==================================="
  
  # 1. Connection Examples
  demo_connections
  
  # 2. Advanced Authentication
  demo_authentication
  
  # 3. Live Queries (WebSocket only)
  demo_live_queries
  
  # 4. GraphQL Support
  demo_graphql
  
  # 5. Graph Relations (RELATE)
  demo_graph_relations
  
  # 6. Machine Learning Functions
  demo_surrealml
  
  # 7. Session Variables
  demo_session_variables
  
  # 8. Advanced Transactions
  demo_advanced_transactions
  
  puts "\n✅ Demo completed successfully!"
end

def demo_connections
  puts "\n📡 1. Connection Examples"
  puts "-" * 30
  
  # HTTP Connection
  http_db = SurrealDB.http_connect(
    host: 'localhost',
    port: 8000,
    namespace: 'test',
    database: 'test'
  )
  puts "✓ HTTP connection established"
  
  # WebSocket Connection
  ws_db = SurrealDB.websocket_connect(
    host: 'localhost',
    port: 8000,
    namespace: 'test',
    database: 'test'
  )
  puts "✓ WebSocket connection established"
  
  # Check connection types
  puts "HTTP connection: #{http_db.connection.http?}"
  puts "WebSocket connection: #{ws_db.connection.websocket?}"
  
  http_db.close
  ws_db.close
end

def demo_authentication
  puts "\n🔐 2. Advanced Authentication"
  puts "-" * 30
  
  db = SurrealDB.connect(url: 'http://localhost:8000')
  
  begin
    # Root authentication
    result = db.signin(user: 'root', pass: 'root')
    puts "✓ Root authentication: #{result.success?}"
    
    # Check authentication status
    puts "✓ Authenticated: #{db.authenticated?}"
    
    # Get server info
    info = db.info
    puts "✓ Server info retrieved: #{info.success?}"
    
    # Get version
    version = db.version
    puts "✓ Server version: #{version.data if version.success?}"
    
    # Scope-based signup example (commented - requires setup)
    # signup_result = db.signup(
    #   ns: 'test',
    #   db: 'test',
    #   ac: 'users',
    #   email: 'newuser@example.com',
    #   password: 'password123'
    # )
    
    # Token authentication example
    # db.authenticate('your-jwt-token-here')
    
    # Invalidate session
    # db.invalidate
    
  rescue SurrealDB::Error => e
    puts "⚠️  Authentication error: #{e.message}"
  ensure
    db.close
  end
end

def demo_live_queries
  puts "\n📺 3. Live Queries (WebSocket Required)"
  puts "-" * 40
  
  begin
    db = SurrealDB.websocket_connect(
      host: 'localhost',
      port: 8000,
      namespace: 'test',
      database: 'test'
    )
    
    db.signin(user: 'root', pass: 'root')
    
    # Create live query
    live_query = db.live('users', diff: true)
    puts "✓ Live query created: #{live_query.id}"
    
    # Set up event handlers
    live_query.on(:all) do |notification|
      puts "📢 Live update: #{notification['action']} - #{notification['data']}"
    end
    
    live_query.on('CREATE') do |data|
      puts "✨ New user created: #{data['name']}"
    end
    
    live_query.on('UPDATE') do |data|
      puts "📝 User updated: #{data['id']}"
    end
    
    live_query.on('DELETE') do |data|
      puts "🗑️  User deleted: #{data['id']}"
    end
    
    puts "✓ Live query handlers set up"
    puts "💡 Live query is now monitoring 'users' table for changes"
    
    # Simulate some data changes in another thread
    Thread.new do
      sleep(1)
      
      # Create a test user
      db.create('users', { name: 'Live User', email: 'live@example.com' })
      sleep(1)
      
      # Update the user
      db.update('users:live_user', { status: 'active' })
      sleep(1)
      
      # Delete the user
      db.delete('users:live_user')
    end
    
    # Let live query run for a few seconds
    sleep(5)
    
    # Kill the live query
    live_query.kill
    puts "✓ Live query terminated"
    
  rescue SurrealDB::ConnectionError => e
    puts "⚠️  WebSocket connection required for live queries: #{e.message}"
  ensure
    db&.close
  end
end

def demo_graphql
  puts "\n🎯 4. GraphQL Support (SurrealDB 2.0+)"
  puts "-" * 40
  
  db = SurrealDB.connect(url: 'http://localhost:8000')
  
  begin
    db.signin(user: 'root', pass: 'root')
    db.use(namespace: 'test', database: 'test')
    
    # GraphQL query example
    graphql_query = '
      query GetUsers($minAge: Int!) {
        users(where: { age: { gte: $minAge } }) {
          id
          name
          email
          age
        }
      }
    '
    
    result = db.graphql(
      query: graphql_query,
      variables: { minAge: 18 },
      operation_name: 'GetUsers'
    )
    
    if result.success?
      puts "✓ GraphQL query executed successfully"
      puts "Users found: #{result.data['users']?.length || 0}" if result.data.is_a?(Hash)
    else
      puts "⚠️  GraphQL query failed: #{result.error_message}"
    end
    
  rescue SurrealDB::Error => e
    puts "⚠️  GraphQL error: #{e.message}"
  ensure
    db.close
  end
end

def demo_graph_relations
  puts "\n🕸️  5. Graph Relations (RELATE)"
  puts "-" * 30
  
  db = SurrealDB.connect(url: 'http://localhost:8000')
  
  begin
    db.signin(user: 'root', pass: 'root')
    db.use(namespace: 'test', database: 'test')
    
    # Create some users
    alice = db.create('users', { name: 'Alice', email: 'alice@example.com' })
    bob = db.create('users', { name: 'Bob', email: 'bob@example.com' })
    
    if alice.success? && bob.success?
      alice_id = alice.data.is_a?(Array) ? alice.data.first['id'] : alice.data['id']
      bob_id = bob.data.is_a?(Array) ? bob.data.first['id'] : bob.data['id']
      
      # Create relationship
      relation = db.relate(
        alice_id,
        'follows',
        bob_id,
        { since: '2024-01-01', strength: 0.8 }
      )
      
      if relation.success?
        puts "✓ Relationship created: Alice follows Bob"
        
        # Query graph relationships
        followers_query = "
          SELECT ->follows->users.* AS following,
                 <-follows<-users.* AS followers
          FROM #{alice_id}
        "
        
        graph_result = db.query(followers_query)
        
        if graph_result.success?
          puts "✓ Graph traversal successful"
          puts "Graph data: #{graph_result.data}"
        end
      end
    end
    
  rescue SurrealDB::Error => e
    puts "⚠️  Graph relations error: #{e.message}"
  ensure
    db.close
  end
end

def demo_surrealml
  puts "\n🤖 6. Machine Learning (SurrealML)"
  puts "-" * 35
  
  db = SurrealDB.connect(url: 'http://localhost:8000')
  
  begin
    db.signin(user: 'root', pass: 'root')
    db.use(namespace: 'test', database: 'test')
    
    # Execute ML function (requires SurrealML setup)
    result = db.run_function(
      'sentiment_analysis',
      '1.0.0',
      { text: 'I absolutely love using SurrealDB!' }
    )
    
    if result.success?
      puts "✓ ML function executed successfully"
      puts "Sentiment result: #{result.data}"
    else
      puts "⚠️  ML function not available (requires SurrealML setup)"
    end
    
  rescue SurrealDB::Error => e
    puts "⚠️  SurrealML error: #{e.message}"
  rescue NotImplementedError => e
    puts "⚠️  #{e.message}"
  ensure
    db.close
  end
end

def demo_session_variables
  puts "\n💾 7. Session Variables (WebSocket Only)"
  puts "-" * 40
  
  begin
    db = SurrealDB.websocket_connect(
      host: 'localhost',
      port: 8000,
      namespace: 'test',
      database: 'test'
    )
    
    db.signin(user: 'root', pass: 'root')
    
    # Set session variables
    db.let('current_user', 'users:admin')
    db.let('user_role', 'administrator')
    db.let('permissions', ['read', 'write', 'delete'])
    
    puts "✓ Session variables set"
    
    # Use variables in queries
    result = db.query("
      SELECT * FROM users 
      WHERE id = $current_user
      AND role = $user_role
    ")
    
    if result.success?
      puts "✓ Query with session variables executed"
    end
    
    # Clear variables
    db.unset('current_user')
    db.unset('user_role')
    puts "✓ Session variables cleared"
    
  rescue SurrealDB::ConnectionError => e
    puts "⚠️  WebSocket connection required for session variables: #{e.message}"
  ensure
    db&.close
  end
end

def demo_advanced_transactions
  puts "\n🔄 8. Advanced Transactions"
  puts "-" * 30
  
  db = SurrealDB.connect(url: 'http://localhost:8000')
  
  begin
    db.signin(user: 'root', pass: 'root')
    db.use(namespace: 'test', database: 'test')
    
    # Complex transaction with rollback on error
    result = db.transaction do |tx|
      # Create user
      user = tx.create('users', {
        name: 'Transaction User',
        email: 'transaction@example.com',
        balance: 1000
      })
      
      # Create account
      account = tx.create('accounts', {
        user: user.data['id'],
        type: 'checking',
        balance: 1000
      })
      
      # Create initial transaction record
      tx.create('transactions', {
        account: account.data['id'],
        type: 'deposit',
        amount: 1000,
        timestamp: 'time::now()'
      })
      
      puts "✓ Transaction completed successfully"
      { user: user.data, account: account.data }
    end
    
    puts "Transaction result: #{result.class}"
    
  rescue SurrealDB::QueryError => e
    puts "⚠️  Transaction failed and rolled back: #{e.message}"
  rescue SurrealDB::Error => e
    puts "⚠️  Transaction error: #{e.message}"
  ensure
    db.close
  end
end

# Run the demo
if __FILE__ == $0
  main
end 