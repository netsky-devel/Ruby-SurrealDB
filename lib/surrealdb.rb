# frozen_string_literal: true

require_relative 'surrealdb/version'
require_relative 'surrealdb/error'
require_relative 'surrealdb/result'
require_relative 'surrealdb/connection'
require_relative 'surrealdb/connection_pool'
require_relative 'surrealdb/query_builder'
require_relative 'surrealdb/client'
require_relative 'surrealdb/live_query'
require_relative 'surrealdb/model'
require_relative 'surrealdb/rails'
require_relative 'surrealdb/connection_factory'
require_relative 'surrealdb/url_validator'

# SurrealDB Ruby SDK
# 
# A modern Ruby client for SurrealDB that supports:
# - HTTP and WebSocket connections
# - CRUD operations with fluent query builder
# - Real-time Live Queries
# - GraphQL support (SurrealDB 2.0+)
# - Machine Learning functions (SurrealML)
# - Graph relations and RELATE operations
# - Authentication and session management
# - Full SurrealQL support
# - Connection pooling and caching for high performance
module SurrealDB
  class << self
    # Connect to SurrealDB with various options
    # 
    # @param url [String] Connection URL (http://, https://, ws://, wss://)
    # @param namespace [String, nil] Default namespace
    # @param database [String, nil] Default database
    # @param timeout [Integer] Connection timeout in seconds
    # @param websocket [Boolean] Force WebSocket connection for HTTP URLs
    # @param pool_size [Integer, nil] Enable connection pooling with specified size
    # @param cache_enabled [Boolean] Enable query result caching
    # @param cache_ttl [Integer] Cache TTL in seconds
    # @return [SurrealDB::Client] Client instance
    # 
    # @example HTTP connection
    #   db = SurrealDB.connect(
    #     url: 'http://localhost:8000',
    #     namespace: 'test',
    #     database: 'test'
    #   )
    # 
    # @example WebSocket connection with authentication
    #   db = SurrealDB.connect(
    #     url: 'ws://localhost:8000/rpc',
    #     namespace: 'production',
    #     database: 'main'
    #   )
    #   db.signin(user: 'root', pass: 'root')
    # 
    # @example High-performance connection with pooling
    #   db = SurrealDB.connect(
    #     url: 'http://localhost:8000',
    #     pool_size: 10,
    #     cache_enabled: true,
    #     cache_ttl: 300
    #   )
    # 
    # @example With Live Query callback
    #   db = SurrealDB.connect(
    #     url: 'ws://localhost:8000/rpc',
    #     on_live_notification: ->(notification) { 
    #       puts "Live update: #{notification}" 
    #     }
    #   )
    def connect(url:, namespace: nil, database: nil, **options)
      ConnectionFactory.create_client(
        url: url,
        namespace: namespace,
        database: database,
        **options
      )
    end

    # Quick connection method for HTTP
    # @param host [String] Host address
    # @param port [Integer] Port number
    # @param namespace [String, nil] Namespace
    # @param database [String, nil] Database
    # @param ssl [Boolean] Use HTTPS
    # @return [SurrealDB::Client] Client instance
    def http_connect(host: 'localhost', port: 8000, namespace: nil, database: nil, ssl: false, **options)
      url = ConnectionFactory.build_http_url(host: host, port: port, ssl: ssl)
      connect(url: url, namespace: namespace, database: database, **options)
    end

    # Quick connection method for WebSocket
    # @param host [String] Host address
    # @param port [Integer] Port number
    # @param namespace [String, nil] Namespace
    # @param database [String, nil] Database
    # @param ssl [Boolean] Use WSS
    # @return [SurrealDB::Client] Client instance
    def websocket_connect(host: 'localhost', port: 8000, namespace: nil, database: nil, ssl: false, **options)
      url = ConnectionFactory.build_websocket_url(host: host, port: port, ssl: ssl)
      connect(url: url, namespace: namespace, database: database, **options)
    end

    # High-performance connection with connection pooling
    # @param url [String] Connection URL
    # @param pool_size [Integer] Connection pool size
    # @param cache_enabled [Boolean] Enable query caching
    # @param cache_ttl [Integer] Cache TTL in seconds
    # @return [SurrealDB::Client] Client instance with performance optimizations
    def performance_connect(url:, pool_size: 10, cache_enabled: true, cache_ttl: 300, **options)
      connect(
        url: url,
        pool_size: pool_size,
        cache_enabled: cache_enabled,
        cache_ttl: cache_ttl,
        **options
      )
    end

    # Create connection pool
    # @param url [String] Connection URL
    # @param size [Integer] Pool size
    # @param timeout [Integer] Connection timeout
    # @return [SurrealDB::ConnectionPool] Connection pool instance
    def connection_pool(url:, size: 10, timeout: 5, **options)
      ConnectionPool.new(
        url: url,
        size: size,
        timeout: timeout,
        **options
      )
    end

    # Get version information
    def version
      VERSION
    end

    # Check if a URL is valid for SurrealDB
    # @param url [String] URL to validate
    # @return [Boolean] True if valid
    def valid_url?(url)
      UrlValidator.valid?(url)
    end
  end
end