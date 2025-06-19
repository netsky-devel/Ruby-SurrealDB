# frozen_string_literal: true

require_relative 'surrealdb/version'
require_relative 'surrealdb/error'
require_relative 'surrealdb/result'
require_relative 'surrealdb/connection'
require_relative 'surrealdb/query_builder'
require_relative 'surrealdb/client'
require_relative 'surrealdb/live_query'

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
module SurrealDB
  class << self
    # Connect to SurrealDB with various options
    # 
    # @param url [String] Connection URL (http://, https://, ws://, wss://)
    # @param namespace [String, nil] Default namespace
    # @param database [String, nil] Default database
    # @param timeout [Integer] Connection timeout in seconds
    # @param websocket [Boolean] Force WebSocket connection for HTTP URLs
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
    # @example With Live Query callback
    #   db = SurrealDB.connect(
    #     url: 'ws://localhost:8000/rpc',
    #     on_live_notification: ->(notification) { 
    #       puts "Live update: #{notification}" 
    #     }
    #   )
    def connect(url:, namespace: nil, database: nil, **options)
      Client.new(
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
      protocol = ssl ? 'https' : 'http'
      url = "#{protocol}://#{host}:#{port}"
      
      connect(
        url: url,
        namespace: namespace,
        database: database,
        **options
      )
    end

    # Quick connection method for WebSocket
    # @param host [String] Host address
    # @param port [Integer] Port number
    # @param namespace [String, nil] Namespace
    # @param database [String, nil] Database
    # @param ssl [Boolean] Use WSS
    # @return [SurrealDB::Client] Client instance
    def websocket_connect(host: 'localhost', port: 8000, namespace: nil, database: nil, ssl: false, **options)
      protocol = ssl ? 'wss' : 'ws'
      url = "#{protocol}://#{host}:#{port}/rpc"
      
      connect(
        url: url,
        namespace: namespace,
        database: database,
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
      uri = URI.parse(url)
      %w[http https ws wss].include?(uri.scheme)
    rescue URI::InvalidURIError
      false
    end
  end
end 