# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2024-01-01

### Added
- Initial release of SurrealDB Ruby gem
- HTTP and WebSocket connection support
- Clean architectural structure with separate classes for:
  - `SurrealDB::Client` - Main client interface
  - `SurrealDB::Connection` - Low-level connection handling
  - `SurrealDB::QueryBuilder` - Fluent query building interface
  - `SurrealDB::Result` - Result wrapper with convenient methods
  - `SurrealDB::Error` - Custom error classes
- Comprehensive test suite with RSpec
- Query builder with method chaining for complex queries
- Support for basic CRUD operations:
  - `create` - Create records
  - `select` - Select records with conditions
  - `update` - Update records with conditions
  - `delete` - Delete records with conditions
  - `find` - Find records by ID
  - `count` - Count records
- Authentication support with `signin` method
- Namespace and database selection with `use` method
- Raw SQL query execution
- Transaction support
- Connection management (ping, alive?, close)
- Error handling with custom exception classes
- Comprehensive documentation and examples
- MIT License

### Features
- **Connection Types**: HTTP and WebSocket support
- **Query Builder**: Fluent interface for building complex queries
- **CRUD Operations**: Full Create, Read, Update, Delete support
- **Authentication**: Built-in authentication support
- **Error Handling**: Comprehensive error handling with custom exceptions
- **Result Handling**: Rich result objects with helper methods
- **Documentation**: Extensive documentation and usage examples

### Dependencies
- `http` (~> 5.0) - HTTP client library
- `websocket-client-simple` (~> 0.6) - WebSocket client
- `json` (~> 2.0) - JSON parsing

### Development Dependencies
- `rspec` (~> 3.12) - Testing framework
- `webmock` (~> 3.18) - HTTP request mocking
- `rake` (~> 13.0) - Build tool
- `rubocop` (~> 1.50) - Code style checker
- `yard` (~> 0.9) - Documentation generator 