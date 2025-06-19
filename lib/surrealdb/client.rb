# frozen_string_literal: true

require_relative 'connection'
require_relative 'connection_pool'
require_relative 'query_builder'
require_relative 'result'
require_relative 'error'

module SurrealDB
  # Main client class for interacting with SurrealDB
  # Provides high-level methods for CRUD operations, authentication, and database management
  # Includes optional performance optimizations like connection pooling and caching
  class Client
    attr_reader :connection, :pool, :cache_enabled, :cache_ttl

    def initialize(url:, namespace: nil, database: nil, pool_size: nil, cache_enabled: false, cache_ttl: 300, **options)
      @namespace = namespace
      @database = database
      @cache_enabled = cache_enabled
      @cache_ttl = cache_ttl
      @cache = {}
      @cache_mutex = Mutex.new
      @auth_params = nil
      
      # Initialize connection or connection pool based on pool_size
      if pool_size && pool_size > 1
        @pool = ConnectionPool.new(size: pool_size, url: url, namespace: namespace, database: database, **options)
        @connection = nil # We'll use pool instead
        @use_pool = true
      else
        @connection = Connection.new(url: url, **options)
        @pool = nil
        @use_pool = false
        connect_and_setup
      end
      
      # Setup authentication if provided
      setup_auth(options) if options[:user] && options[:pass]
    end

    # Authentication methods
    def signin(user: nil, pass: nil, ns: nil, db: nil, ac: nil, **params)
      auth_params = { user: user, pass: pass, ns: ns, db: db, ac: ac }.merge(params).compact
      
      if @use_pool
        @auth_params = auth_params
        result = @pool.with_connection { |conn| conn.query('signin', auth_params) }
      else
        result = @connection.query('signin', auth_params)
        
        if result.success?
          @connection.authenticated = true
          @connection.auth_token = result.data['token'] if result.data.is_a?(Hash) && result.data['token']
        end
      end
      
      result
    end

    def signup(ns:, db:, ac:, **params)
      auth_params = { ns: ns, db: db, ac: ac }.merge(params)
      
      if @use_pool
        @auth_params = auth_params
        result = @pool.with_connection { |conn| conn.query('signup', auth_params) }
      else
        result = @connection.query('signup', auth_params)
        
        if result.success?
          @connection.authenticated = true
          @connection.auth_token = result.data['token'] if result.data.is_a?(Hash) && result.data['token']
        end
      end
      
      result
    end

    def authenticate(token)
      if @use_pool
        @auth_params = { token: token }
        result = @pool.with_connection { |conn| conn.query('authenticate', token) }
      else
        result = @connection.query('authenticate', token)
        
        if result.success?
          @connection.authenticated = true
          @connection.auth_token = token
        end
      end
      
      result
    end

    def invalidate
      if @use_pool
        @auth_params = nil
        result = @pool.with_connection { |conn| conn.query('invalidate') }
      else
        result = @connection.query('invalidate')
        
        if result.success?
          @connection.authenticated = false
          @connection.auth_token = nil
        end
      end
      
      result
    end

    def info
      execute_query('info')
    end

    # Connection management
    def ping
      execute_query('ping')
    end

    def version
      execute_query('version')
    end

    def use(namespace: nil, database: nil)
      @namespace = namespace if namespace
      @database = database if database
      execute_query('use', @namespace, @database)
    end

    # Basic CRUD operations
    def create(table, data = nil, **options)
      if data.nil?
        execute_query('create', table, nil, options)
      else
        execute_query('create', table, data, options)
      end
    end

    def select(table_or_record, **options)
      execute_query('select', table_or_record, options)
    end

    def update(table_or_record, data = nil, **options)
      execute_query('update', table_or_record, data, options)
    end

    def upsert(table_or_record, data = nil, **options)
      execute_query('upsert', table_or_record, data, options)
    end

    def delete(table_or_record, **options)
      execute_query('delete', table_or_record, options)
    end

    def insert(table, data, **options)
      execute_query('insert', table, data, options)
    end

    # Graph operations
    def relate(from_record, relation, to_record, data = nil, **options)
      if data.nil?
        execute_query('relate', from_record, relation, to_record, options)
      else
        execute_query('relate', from_record, relation, to_record, data, options)
      end
    end

    # GraphQL support (SurrealDB 2.0+)
    def graphql(query, variables: nil, operation_name: nil, **options)
      query_obj = if query.is_a?(String)
        { query: query }
      else
        query
      end

      query_obj[:variables] = variables if variables
      query_obj[:operationName] = operation_name if operation_name

      execute_query('graphql', query_obj, options)
    end

    # Live queries (WebSocket only)
    def live(table, diff: false)
      raise SurrealDB::ConnectionError, "Live queries require WebSocket connection" unless websocket_available?
      
      execute_query('live', table, diff)
    end

    def kill(query_uuid)
      raise SurrealDB::ConnectionError, "Kill requires WebSocket connection" unless websocket_available?
      
      execute_query('kill', query_uuid)
    end

    # Session variables (WebSocket only)
    def let(name, value)
      raise SurrealDB::ConnectionError, "Session variables require WebSocket connection" unless websocket_available?
      
      execute_query('let', name, value)
    end

    def unset(name)
      raise SurrealDB::ConnectionError, "Session variables require WebSocket connection" unless websocket_available?
      
      execute_query('unset', name)
    end

    # Machine Learning (SurrealML)
    def run_function(func_name, version = nil, args = nil)
      params = [func_name]
      params << version if version
      params << args if args
      
      execute_query('run', *params)
    end

    def ml_import(file_path, **options)
      raise NotImplementedError, "ML import requires file upload support"
    end

    def ml_export(name, version, **options)
      raise NotImplementedError, "ML export requires file download support"
    end

    # Data import/export
    def import(file_path, **options)
      raise NotImplementedError, "Import requires file upload support"
    end

    def export(file_path = nil, **options)
      raise NotImplementedError, "Export requires file download support"
    end

    # Advanced query methods with optional caching
    def query(sql, vars = {}, cache_key: nil)
      # Check cache first
      if @cache_enabled && cache_key
        cached_result = get_from_cache(cache_key)
        return cached_result if cached_result
      end

      result = execute_query('query', sql, vars)

      # Cache successful results
      if @cache_enabled && cache_key && result.success?
        set_cache(cache_key, result)
      end

      result
    end

    alias_method :sql, :query

    # Performance methods (available when using connection pool)
    def batch_query(queries)
      raise SurrealDB::ConfigurationError, "Batch queries require connection pooling (pool_size > 1)" unless @use_pool
      
      results = []
      
      @pool.with_connection do |connection|
        authenticate_connection(connection) if @auth_params
        
        queries.each do |query_info|
          sql = query_info[:sql]
          vars = query_info[:vars] || {}
          
          result = connection.query('query', sql, vars)
          results << result
        end
      end
      
      results
    end

    def bulk_insert(table, records, chunk_size: 1000)
      raise SurrealDB::ConfigurationError, "Bulk insert requires connection pooling (pool_size > 1)" unless @use_pool
      return [] if records.empty?
      
      results = []
      records.each_slice(chunk_size) do |chunk|
        result = @pool.with_connection do |connection|
          authenticate_connection(connection) if @auth_params
          connection.query('insert', table, chunk)
        end
        results << result
      end
      
      results
    end

    # Convenience methods
    def find(table, id)
      select("#{table}:#{id}")
    end

    def all(table)
      select(table)
    end

    def count(table)
      result = query("SELECT count() FROM #{table} GROUP ALL")
      result.success? ? result.first['count'] : 0
    end

    # Transaction support
    def transaction(&block)
      begin_result = query('BEGIN TRANSACTION')
      raise SurrealDB::QueryError, "Failed to begin transaction" unless begin_result.success?

      begin
        result = yield(self)
        commit_result = query('COMMIT TRANSACTION')
        raise SurrealDB::QueryError, "Failed to commit transaction" unless commit_result.success?
        result
      rescue => e
        cancel_result = query('CANCEL TRANSACTION')
        raise e
      end
    end

    # Query builder integration
    def from(table)
      QueryBuilder.new(self, table)
    end

    # Connection status methods
    def connected?
      if @use_pool
        @pool.available_connections > 0
      else
        @connection.connected?
      end
    end

    def authenticated?
      if @use_pool
        @auth_params != nil
      else
        @connection.authenticated?
      end
    end

    def alive?
      ping.success?
    rescue
      false
    end

    # Cleanup methods
    def close
      if @use_pool
        @pool.shutdown
      else
        @connection.close
      end
      clear_cache
    end

    def reset
      result = execute_query('reset')
      clear_cache if @cache_enabled
      result
    end

    # Cache management
    def clear_cache
      @cache_mutex.synchronize { @cache.clear }
    end

    def cache_stats
      @cache_mutex.synchronize do
        {
          enabled: @cache_enabled,
          size: @cache.size,
          ttl: @cache_ttl
        }
      end
    end

    private

    def connect_and_setup
      @connection.connect
      use(namespace: @namespace, database: @database) if @namespace || @database
    end

    def setup_auth(options)
      @auth_params = {
        user: options[:user],
        pass: options[:pass]
      }
    end

    def execute_query(method, *args)
      if @use_pool
        @pool.with_connection do |connection|
          authenticate_connection(connection) if @auth_params
          connection.query(method, *args)
        end
      else
        @connection.query(method, *args)
      end
    end

    def authenticate_connection(connection)
      return if connection.authenticated
      
      if @auth_params[:token]
        result = connection.query('authenticate', @auth_params[:token])
      else
        result = connection.query('signin', @auth_params)
      end
      
      if result.success?
        connection.authenticated = true
      else
        raise SurrealDB::AuthenticationError, "Failed to authenticate connection"
      end
    end

    def websocket_available?
      if @use_pool
        # For pooled connections, we need to check if any connection supports WebSocket
        # This is a simplified check - in a real implementation, you might want to 
        # ensure all connections in the pool support WebSocket
        true # Assume WebSocket support for now
      else
        @connection.websocket?
      end
    end

    def get_from_cache(key)
      @cache_mutex.synchronize do
        entry = @cache[key]
        return nil unless entry
        
        # Check if expired
        if Time.now - entry[:timestamp] > @cache_ttl
          @cache.delete(key)
          return nil
        end
        
        entry[:result]
      end
    end

    def set_cache(key, result)
      return unless key && result
      
      @cache_mutex.synchronize do
        @cache[key] = {
          result: result,
          timestamp: Time.now
        }
      end
    end
  end
end 