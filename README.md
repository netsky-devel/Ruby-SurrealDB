# SurrealDB Ruby

A clean and comprehensive Ruby client library for [SurrealDB](https://surrealdb.com/) with support for HTTP and WebSocket connections.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'surrealdb'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install surrealdb

## Usage

### Basic Connection

```ruby
require 'surrealdb'

# Connect using HTTP
client = SurrealDB.connect('http://localhost:8000')

# Connect using WebSocket
client = SurrealDB.connect('ws://localhost:8000/rpc')

# Connect with authentication
client = SurrealDB.connect('http://localhost:8000', 
  username: 'root', 
  password: 'root',
  namespace: 'test',
  database: 'test'
)
```

### Basic Operations

```ruby
# Use namespace and database
client.use('test', 'test')

# Create a record
result = client.create('users', { name: 'John Doe', age: 30 })
puts result.first # => {"id" => "users:xyz", "name" => "John Doe", "age" => 30}

# Select records
users = client.select('users')
users.each do |user|
  puts "#{user['name']} is #{user['age']} years old"
end

# Select with conditions
adults = client.select('users', { age: 30 })

# Update records
client.update('users', { status: 'active' }, { name: 'John Doe' })

# Delete records
client.delete('users', { age: 30 })

# Find by ID
user = client.find('users', 'xyz')
```

### Query Builder

The gem provides a fluent query builder for constructing complex queries:

```ruby
# Using the query builder
result = client.query_builder
  .select('name', 'age')
  .from('users')
  .where('age > $min_age', { min_age: 18 })
  .order_by('name')
  .limit(10)
  .execute

# Get first result
first_user = client.query_builder
  .select
  .from('users')
  .where('name = $name', { name: 'John' })
  .first

# Complex queries
result = client.query_builder
  .select('department', 'count(*) as total')
  .from('users')
  .where('active = true')
  .group_by('department')
  .having('count(*) > 5')
  .order_by('total', 'DESC')
  .all
```

### Raw SQL Queries

```ruby
# Execute raw SQL
result = client.query('SELECT * FROM users WHERE age > $age', { age: 25 })

# Transaction example
client.transaction([
  'CREATE users SET name = "Alice", age = 25',
  'CREATE users SET name = "Bob", age = 30',
  'UPDATE users SET status = "active" WHERE age > 25'
])
```

### Working with Results

```ruby
result = client.select('users')

# Check if successful
puts "Success!" if result.success?

# Access data
puts result.first    # First record
puts result.all      # All records
puts result.count    # Number of records
puts result.empty?   # Check if empty

# Iterate over results
result.each do |user|
  puts user['name']
end

# Convert to array or hash
array_data = result.to_a
hash_data = result.to_h  # First record as hash
```

### Connection Management

```ruby
# Check connection
puts "Connected!" if client.alive?

# Ping server
puts "Server responding!" if client.ping

# Get server info
info = client.info
puts "Database: #{info}"

# Close connection
client.close
```

### Error Handling

```ruby
begin
  client.query('INVALID SQL')
rescue SurrealDB::QueryError => e
  puts "Query error: #{e.message}"
rescue SurrealDB::ConnectionError => e
  puts "Connection error: #{e.message}"
rescue SurrealDB::AuthenticationError => e
  puts "Auth error: #{e.message}"
end
```

## Configuration Options

```ruby
client = SurrealDB.connect('http://localhost:8000', {
  timeout: 30,          # Request timeout in seconds
  namespace: 'test',    # Default namespace
  database: 'test',     # Default database
  username: 'root',     # Username for authentication
  password: 'root'      # Password for authentication
})
```

## Connection Types

### HTTP Connection
- Uses standard HTTP requests
- Good for simple operations
- Stateless

### WebSocket Connection
- Real-time bidirectional communication
- Better for live queries and subscriptions
- Persistent connection

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/netsky-devel/Ruby-SurrealDB.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Changelog

### 0.1.0
- Initial release
- HTTP and WebSocket connection support
- Query builder with fluent interface
- Comprehensive test suite
- Error handling and custom exceptions
- Result wrapper with convenient methods 