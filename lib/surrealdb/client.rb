# frozen_string_literal: true

require_relative 'connection'
require_relative 'connection_pool'
require_relative 'query_builder'
require_relative 'result'
require_relative 'error'
require_relative 'authentication_manager'
require_relative 'cache_manager'
require_relative 'query_executor'

module SurrealDB
  # Main client class for interacting with SurrealDB
  # Provides high-level methods for CRUD operations, authentication, and database management
  class Client
    attr_reader :connection, :pool, :namespace, :database

    def initialize(url:, namespace: nil, database: nil, pool_size: nil, cache_enabled: false, cache_ttl: 300, **options)
      @namespace = namespace
      @database = database
      @connection_manager = create_connection_manager(url, pool_size, options)
      @authentication_manager = AuthenticationManager.new(@connection_manager)
      @cache_manager = CacheManager.new(cache_enabled, cache_ttl)
      @query_executor = QueryExecutor.new(@connection_manager, @authentication_manager, @cache_manager)
      
      setup_initial_connection(options)
    end

    # Authentication methods
    def signin(user: nil, pass: nil, ns: nil, db: nil, ac: nil, **params)
      auth_params = build_auth_params(user: user, pass: pass, ns: ns, db: db, ac: ac, **params)
      @authentication_manager.signin(auth_params)
    end

    def signup(ns:, db:, ac:, **params)
      auth_params = build_auth_params(ns: ns, db: db, ac: ac, **params)
      @authentication_manager.signup(auth_params)
    end

    def authenticate(token)
      @authentication_manager.authenticate(token)
    end

    def invalidate
      @authentication_manager.invalidate
    end

    def info
      @query_executor.execute('info')
    end

    # Connection management
    def ping
      @query_executor.execute('ping')
    end

    def version
      @query_executor.execute('version')
    end

    def use(namespace: nil, database: nil)
      update_namespace_and_database(namespace, database)
      @query_executor.execute('use', @namespace, @database)
    end

    # Basic CRUD operations
    def create(table, data = nil, **options)
      @query_executor.execute('create', table, data, options)
    end

    def select(table_or_record, **options)
      @query_executor.execute('select', table_or_record, options)
    end

    def update(table_or_record, data = nil, **options)
      @query_executor.execute('update', table_or_record, data, options)
    end

    def upsert(table_or_record, data = nil, **options)
      @query_executor.execute('upsert', table_or_record, data, options)
    end

    def delete(table_or_record, **options)
      @query_executor.execute('delete', table_or_record, options)
    end

    def insert(table, data, **options)
      @query_executor.execute('insert', table, data, options)
    end

    # Graph operations
    def relate(from_record, relation, to_record, data = nil, **options)
      @query_executor.execute('relate', from_record, relation, to_record, data, options)
    end

    # GraphQL support (SurrealDB 2.0+)
    def graphql(query, variables: nil, operation_name: nil, **options)
      query_obj = build_graphql_query(query, variables, operation_name)
      @query_executor.execute('graphql', query_obj, options)
    end

    # Live queries (WebSocket only)
    def live(table, diff: false)
      validate_websocket_support('Live queries')
      @query_executor.execute('live', table, diff)
    end

    def kill(query_uuid)
      validate_websocket_support('Kill')
      @query_executor.execute('kill', query_uuid)
    end

    # Session variables (WebSocket only)
    def let(name, value)
      validate_websocket_support('Session variables')
      @query_executor.execute('let', name, value)
    end

    def unset(name)
      validate_websocket_support('Session variables')
      @query_executor.execute('unset', name)
    end

    # Machine Learning (SurrealML)
    def run_function(func_name, version = nil, args = nil)
      params = build_function_params(func_name, version, args)
      @query_executor.execute('run', *params)
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
      @query_executor.execute_with_cache('query', cache_key, sql, vars)
    end

    alias_method :sql, :query

    # Performance methods (available when using connection pool)
    def batch_query(queries)
      validate_connection_pool('Batch queries')
      @query_executor.execute_batch(queries)
    end

    def bulk_insert(table, records, chunk_size: 1000)
      validate_connection_pool('Bulk insert')
      return [] if records.empty?
      @query_executor.execute_bulk_insert(table, records, chunk_size)
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
      extract_count_from_result(result)
    end

    # Transaction support
    def transaction(&block)
      execute_transaction(&block)
    end

    # Query builder integration
    def from(table)
      QueryBuilder.new(self, table)
    end

    # Connection status methods
    def connected?
      @connection_manager.connected?
    end

    def authenticated?
      @authentication_manager.authenticated?
    end

    def alive?
      ping.success?
    rescue
      false
    end

    # Cleanup methods
    def close
      @connection_manager.close
      @cache_manager.clear
    end

    def reset
      result = @query_executor.execute('reset')
      @cache_manager.clear
      result
    end

    # Cache management
    def clear_cache
      @cache_manager.clear
    end

    def cache_stats
      @cache_manager.stats
    end

    private

    def create_connection_manager(url, pool_size, options)
      if pool_size && pool_size > 1
        @pool = ConnectionPool.new(size: pool_size, url: url, namespace: @namespace, database: @database, **options)
        @connection = nil
        PoolConnectionManager.new(@pool)
      else
        @connection = Connection.new(url: url, **options)
        @pool = nil
        SingleConnectionManager.new(@connection)
      end
    end

    def setup_initial_connection(options)
      @connection_manager.setup(@namespace, @database)
      setup_initial_auth(options) if options[:user] && options[:pass]
    end

    def setup_initial_auth(options)
      auth_params = { user: options[:user], pass: options[:pass] }
      @authentication_manager.setup_initial_auth(auth_params)
    end

    def build_auth_params(**params)
      params.compact
    end

    def update_namespace_and_database(namespace, database)
      @namespace = namespace if namespace
      @database = database if database
    end

    def build_graphql_query(query, variables, operation_name)
      query_obj = query.is_a?(String) ? { query: query } : query
      query_obj[:variables] = variables if variables
      query_obj[:operationName] = operation_name if operation_name
      query_obj
    end

    def build_function_params(func_name, version, args)
      params = [func_name]
      params << version if version
      params << args if args
      params
    end

    def validate_websocket_support(operation_name)
      unless @connection_manager.websocket_available?
        raise SurrealDB::ConnectionError, "#{operation_name} require WebSocket connection"
      end
    end

    def validate_connection_pool(operation_name)
      unless @connection_manager.pool_available?
        raise SurrealDB::ConfigurationError, "#{operation_name} require connection pooling (pool_size > 1)"
      end
    end

    def extract_count_from_result(result)
      result.success? ? result.first['count'] : 0
    end

    def execute_transaction(&block)
      begin_result = query('BEGIN TRANSACTION')
      raise SurrealDB::QueryError, "Failed to begin transaction" unless begin_result.success?

      begin
        result = yield(self)
        commit_result = query('COMMIT TRANSACTION')
        raise SurrealDB::QueryError, "Failed to commit transaction" unless commit_result.success?
        result
      rescue => e
        query('CANCEL TRANSACTION')
        raise e
      end
    end
  end

  # Connection manager abstraction
  class ConnectionManager
    def connected?
      raise NotImplementedError
    end

    def websocket_available?
      raise NotImplementedError
    end

    def pool_available?
      raise NotImplementedError
    end

    def setup(namespace, database)
      raise NotImplementedError
    end

    def close
      raise NotImplementedError
    end
  end

  class SingleConnectionManager < ConnectionManager
    def initialize(connection)
      @connection = connection
    end

    def connected?
      @connection.connected?
    end

    def websocket_available?
      @connection.websocket?
    end

    def pool_available?
      false
    end

    def setup(namespace, database)
      @connection.connect
      use_namespace_and_database(namespace, database) if namespace || database
    end

    def close
      @connection.close
    end

    def execute_query(method, *args)
      @connection.query(method, *args)
    end

    private

    def use_namespace_and_database(namespace, database)
      @connection.query('use', namespace, database)
    end
  end

  class PoolConnectionManager < ConnectionManager
    def initialize(pool)
      @pool = pool
    end

    def connected?
      @pool.available_connections > 0
    end

    def websocket_available?
      true # Assume WebSocket support for pooled connections
    end

    def pool_available?
      true
    end

    def setup(namespace, database)
      # Pool setup is handled during initialization
    end

    def close
      @pool.shutdown
    end

    def with_connection(&block)
      @pool.with_connection(&block)
    end
  end
end