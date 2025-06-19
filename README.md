# SurrealDB Ruby SDK

A modern, comprehensive Ruby client for [SurrealDB](https://surrealdb.com) - the ultimate multi-model database for tomorrow's applications.

[![Gem Version](https://badge.fury.io/rb/surrealdb.svg)](https://badge.fury.io/rb/surrealdb)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.txt)
[![Production Ready](https://img.shields.io/badge/Status-Production%20Ready-brightgreen.svg)](https://github.com/netsky-devel/Ruby-SurrealDB)
[![SurrealDB 2.0+](https://img.shields.io/badge/SurrealDB-2.0%2B%20Compatible-blue.svg)](https://surrealdb.com)

> **🎉 PRODUCTION READY**: This library provides complete feature parity with SurrealDB 2.0+ and is ready for production use!

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
- `SurrealDB.performance_connect(**options)` - High-performance connection with pooling
- `SurrealDB.connection_pool(**options)` - Create connection pool

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

## ✅ Feature Completeness

**🎉 This library is PRODUCTION READY and provides complete SurrealDB 2.0+ support!**

### ✅ **Fully Implemented (Ready to Use)**
- ✅ **HTTP & WebSocket Connections** - Both protocols fully supported
- ✅ **Authentication** - signin, signup, token auth, scope auth
- ✅ **CRUD Operations** - create, select, update, upsert, delete, insert
- ✅ **Live Queries** - Real-time data synchronization via WebSocket
- ✅ **GraphQL Support** - Complete GraphQL query execution
- ✅ **Graph Relations** - RELATE operations for connected data
- ✅ **SurrealML Integration** - Machine learning function execution
- ✅ **Session Variables** - let/unset for WebSocket sessions
- ✅ **Advanced Transactions** - BEGIN/COMMIT/CANCEL with rollback
- ✅ **Fluent Query Builder** - Intuitive query construction
- ✅ **Comprehensive Error Handling** - Production-ready error management
- ✅ **Connection Management** - ping, health checks, auto-reconnect ready
- ✅ **Connection Pooling** - High-performance connection management
- ✅ **Query Caching** - Advanced caching with TTL support
- ✅ **Rails Integration** - Complete Ruby on Rails framework support
- ✅ **ActiveRecord-like ORM** - Familiar Ruby model interface

### 📊 **Compatibility Matrix**

| Feature | SurrealDB 2.0+ | Our Ruby SDK | Status |
|---------|----------------|--------------|--------|
| HTTP Protocol | ✅ | ✅ | **READY** |
| WebSocket Protocol | ✅ | ✅ | **READY** |
| Authentication | ✅ | ✅ | **READY** |
| CRUD Operations | ✅ | ✅ | **READY** |
| Live Queries | ✅ | ✅ | **READY** |
| GraphQL | ✅ | ✅ | **READY** |
| SurrealML | ✅ | ✅ | **READY** |
| Transactions | ✅ | ✅ | **READY** |
| Graph Relations | ✅ | ✅ | **READY** |
| Session Variables | ✅ | ✅ | **READY** |
| Connection Pooling | ✅ | ✅ | **READY** |
| Query Caching | ✅ | ✅ | **READY** |
| Rails Integration | ✅ | ✅ | **READY** |
| ActiveRecord ORM | ✅ | ✅ | **READY** |

**🚀 This Ruby SDK provides feature parity with official JavaScript and Python SDKs!**

### 🚀 **Production Enhancements (NEW!)**
- ✅ **Connection Pooling** - High-performance connection management
- ✅ **Advanced Caching** - Query result caching with TTL
- ✅ **Performance Client** - Optimized client with batch operations
- ✅ **Ruby on Rails Integration** - Complete Rails framework support
- ✅ **ActiveRecord-like ORM** - Familiar Ruby model interface

## 🔥 **New Production Features**

### Connection Pooling & Performance
```ruby
# High-performance client with connection pooling
client = SurrealDB.performance_connect(
  url: 'http://localhost:8000',
  pool_size: 20,
  cache_enabled: true,
  cache_ttl: 300
)

# Batch operations for better performance
queries = [
  { sql: "SELECT * FROM users WHERE active = true" },
  { sql: "SELECT COUNT(*) FROM posts" }
]
results = client.batch_query(queries)

# Bulk insert with chunking
records = 1000.times.map { |i| { name: "User #{i}" } }
client.bulk_insert('users', records, chunk_size: 100)
```

### Ruby on Rails Integration
```ruby
# config/initializers/surrealdb.rb
SurrealDB::Rails::Integration.configure do |config|
  config.url = ENV['SURREALDB_URL']
  config.namespace = Rails.env
  config.database = Rails.application.class.name.underscore
  config.pool_size = Rails.env.production? ? 20 : 5
  config.cache_enabled = Rails.env.production?
end

# In your controllers
class UsersController < ApplicationController
  def index
    @users = surrealdb.select('users')
  end
  
  def create
    with_surrealdb_transaction do
      surrealdb.create('users', user_params)
    end
  end
end
```

### ActiveRecord-like ORM
```ruby
# Define models
class User < SurrealDB::Model
  table 'users'  # Custom table name
end

class Post < SurrealDB::Model
  # Uses default table name 'posts'
end

# Use like ActiveRecord
user = User.create(name: 'John', email: 'john@example.com')
user.age = 30
user.save

# Query with familiar syntax
User.where(active: true)
User.find('user123')
User.all
User.count

# Dynamic attributes
user.name = 'Jane'
user.custom_field = 'value'
```

## 📈 Future Enhancements (Optional)

- [ ] Vector search support (when available in SurrealDB 2.1+)
- [ ] Streaming query results for large datasets
- [ ] Enhanced GraphQL schema introspection
- [ ] Advanced model validations and callbacks
- [ ] Database migrations system
- [ ] Query optimization hints 