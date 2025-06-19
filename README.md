# SurrealDB Ruby SDK

A modern, comprehensive Ruby client for [SurrealDB](https://surrealdb.com) - the ultimate multi-model database for tomorrow's applications.

[![Gem Version](https://badge.fury.io/rb/surrealdb.svg)](https://badge.fury.io/rb/surrealdb)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.txt)

## 🚀 Features

### Core Database Operations
- **CRUD Operations**: Create, Read, Update, Delete with fluent API
- **Advanced Queries**: Full SurrealQL support with query builder
- **Transactions**: Atomic operations with rollback support
- **Graph Relations**: RELATE operations for graph data

### Modern SurrealDB 2.0+ Support
- **Live Queries**: Real-time data synchronization via WebSocket
- **GraphQL Support**: Query your database with GraphQL
- **SurrealML Integration**: Machine learning model execution
- **Vector Search**: Semantic search capabilities (coming soon)

### Multiple Connection Types
- **HTTP/HTTPS**: Traditional REST-like operations
- **WebSocket/WSS**: Real-time bidirectional communication
- **Auto-detection**: Smart connection type selection

### Authentication & Security
- **Multiple Auth Methods**: signin, signup, token-based authentication
- **Scope Authentication**: Database-level and namespace-level access
- **Session Management**: Persistent authentication state

### Developer Experience
- **Fluent Query Builder**: Intuitive, chainable query construction
- **Rich Result Objects**: Convenient data access methods
- **Comprehensive Error Handling**: Detailed error messages
- **Type Safety**: Ruby-friendly API design

## 📦 Installation

Add this line to your application's Gemfile:

```ruby
gem 'surrealdb'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install surrealdb
```

## 🎯 Quick Start

### Basic Connection and Operations

```ruby
require 'surrealdb'

# Connect to SurrealDB
db = SurrealDB.connect(
  url: 'http://localhost:8000',
  namespace: 'test',
  database: 'test'
)

# Authenticate
db.signin(user: 'root', pass: 'root')

# Create a record
user = db.create('users', {
  name: 'John Doe',
  email: 'john@example.com',
  age: 30
})

# Query with the fluent builder
adults = db.from('users')
          .where('age >= 18')
          .order_by('name')
          .limit(10)
          .execute

# Raw SQL queries
result = db.query(
  "SELECT * FROM users WHERE age > $age",
  { age: 25 }
)

puts result.data
```

### WebSocket Connection with Live Queries

```ruby
# Connect via WebSocket for real-time features
db = SurrealDB.websocket_connect(
  host: 'localhost',
  port: 8000,
  namespace: 'test',
  database: 'test'
)

# Set up authentication
db.signin(user: 'root', pass: 'root')

# Create a live query
live_query = db.live('users')

# Handle real-time updates
live_query.on(:all) do |notification|
  action = notification['action'] # CREATE, UPDATE, DELETE
  data = notification['result']
  
  puts "User #{action}: #{data}"
end

live_query.on('CREATE') do |data|
  puts "New user created: #{data['name']}"
end

# The live query will now receive updates in real-time
```

## 🔧 Advanced Usage

### GraphQL Support (SurrealDB 2.0+)

```ruby
# GraphQL query
result = db.graphql(
  query: '
    query GetUsers($minAge: Int!) {
      users(where: { age: { gte: $minAge } }) {
        id
        name
        email
        posts {
          title
          content
        }
      }
    }
  ',
  variables: { minAge: 18 }
)
```

### Graph Relations

```ruby
# Create relation between records
db.relate(
  'users:john',      # from
  'follows',         # relation
  'users:jane',      # to
  { since: '2024-01-01' }  # relation data
)

# Query graph relationships
followers = db.query("
  SELECT ->follows->users.* AS followers 
  FROM users:john
")
```

### Machine Learning (SurrealML)

```ruby
# Execute ML function
prediction = db.run_function(
  'sentiment_analysis',  # function name
  '1.0.0',              # version
  { text: 'I love SurrealDB!' }  # arguments
)

puts prediction.data
```

### Session Variables (WebSocket only)

```ruby
# Set session variables
db.let('current_user', 'users:john')
db.let('permissions', ['read', 'write'])

# Use in queries
result = db.query("
  SELECT * FROM posts 
  WHERE author = $current_user
")

# Clear variables
db.unset('current_user')
```

### Transaction Support

```ruby
db.transaction do |tx|
  # Create user
  user = tx.create('users', { name: 'Alice', email: 'alice@example.com' })
  
  # Create profile
  profile = tx.create('profiles', { 
    user: user.data['id'],
    bio: 'Software Engineer'
  })
  
  # If any operation fails, the entire transaction is rolled back
end
```

## 🔍 Query Builder

The fluent query builder provides an intuitive way to construct complex queries:

```ruby
# SELECT with conditions
users = db.from('users')
          .select('name', 'email', 'age')
          .where('age >= 18')
          .where('status = "active"')
          .order_by('created_at DESC')
          .limit(50)
          .execute

# JOIN operations
posts_with_authors = db.from('posts')
                       .select('title', 'content', 'author.name AS author_name')
                       .where('published = true')
                       .order_by('created_at DESC')
                       .execute

# Aggregations
stats = db.from('users')
          .select('COUNT(*) AS total_users')
          .select('AVG(age) AS average_age')
          .where('status = "active"')
          .group_by('country')
          .having('COUNT(*) > 10')
          .execute

# Complex updates
db.from('users')
  .update({ last_login: 'time::now()' })
  .where('status = "active"')
  .execute
```

## 🔐 Authentication

### Basic Authentication

```ruby
# Sign in with username/password
result = db.signin(user: 'john', pass: 'secret123')

# Sign up new user
result = db.signup(
  ns: 'test',
  db: 'test', 
  ac: 'users',  # access method
  email: 'new@example.com',
  password: 'newpass123'
)

# Use token authentication
db.authenticate('your-jwt-token-here')

# Check authentication status
puts "Authenticated: #{db.authenticated?}"

# Invalidate session
db.invalidate
```

### Scope-based Authentication

```ruby
# Authenticate with specific scope
db.signin(
  ns: 'production',
  db: 'main',
  ac: 'admin_users',
  user: 'admin',
  pass: 'admin_password'
)
```

## 📊 Data Access and Results

```ruby
result = db.select('users')

# Check if query was successful
if result.success?
  puts "Query successful!"
else
  puts "Error: #{result.error_message}"
end

# Access data
puts result.data        # Raw data array
puts result.first       # First record
puts result.count       # Number of records
puts result.empty?      # Boolean

# Iterate through results
result.each do |user|
  puts "User: #{user['name']}"
end

# Convert to different formats
hash_result = result.to_h    # Hash representation
array_result = result.to_a   # Array representation
```

## 🔧 Connection Management

```ruby
# Check connection status
puts "Connected: #{db.connected?}"
puts "Alive: #{db.alive?}"

# Get server info
info = db.info
version = db.version
ping_result = db.ping

# Graceful shutdown
db.close
```

## ⚠️ Error Handling

```ruby
begin
  result = db.create('users', invalid_data)
rescue SurrealDB::ConnectionError => e
  puts "Connection failed: #{e.message}"
rescue SurrealDB::AuthenticationError => e
  puts "Authentication failed: #{e.message}"
rescue SurrealDB::QueryError => e
  puts "Query error: #{e.message}"
rescue SurrealDB::TimeoutError => e
  puts "Request timed out: #{e.message}"
end
```

## 🧪 Testing

Run the test suite:

```bash
bundle exec rspec
```

Run with coverage:

```bash
bundle exec rspec --format documentation
```

## 📚 API Reference

### Connection Methods
- `SurrealDB.connect(url:, **options)` - Generic connection
- `SurrealDB.http_connect(**options)` - HTTP connection
- `SurrealDB.websocket_connect(**options)` - WebSocket connection

### Authentication Methods
- `signin(user:, pass:, **options)` - User authentication
- `signup(ns:, db:, ac:, **params)` - User registration
- `authenticate(token)` - Token authentication
- `invalidate()` - Clear authentication

### CRUD Operations
- `create(table, data, **options)` - Create records
- `select(table_or_record, **options)` - Read records
- `update(table_or_record, data, **options)` - Update records
- `upsert(table_or_record, data, **options)` - Insert or update
- `delete(table_or_record, **options)` - Delete records
- `insert(table, data, **options)` - Insert records

### Advanced Features
- `live(table, diff: false)` - Create live query
- `kill(query_uuid)` - Kill live query
- `relate(from, relation, to, data)` - Create graph relation
- `graphql(query, **options)` - Execute GraphQL
- `run_function(name, version, args)` - Execute ML function

### Query Methods
- `query(sql, vars = {})` - Execute raw SQL
- `from(table)` - Start query builder
- `transaction(&block)` - Execute transaction

### Utility Methods
- `info()` - Get database info
- `version()` - Get server version
- `ping()` - Health check
- `use(namespace:, database:)` - Change namespace/database

## 🤝 Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## 📄 License

This gem is available as open source under the terms of the [MIT License](LICENSE.txt).

## 🔗 Links

- [SurrealDB Official Website](https://surrealdb.com)
- [SurrealDB Documentation](https://surrealdb.com/docs)
- [SurrealQL Language Guide](https://surrealdb.com/docs/surrealql)
- [Ruby Gem Documentation](https://rubydoc.info/gems/surrealdb)

## 📈 Roadmap

- [ ] Connection pooling
- [ ] Advanced caching mechanisms  
- [ ] Vector search support
- [ ] Streaming query results
- [ ] Enhanced GraphQL schema introspection
- [ ] Performance optimizations
- [ ] Ruby on Rails integration helpers 