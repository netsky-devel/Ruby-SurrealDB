# frozen_string_literal: true

require_relative 'connection'
require_relative 'query_builder'
require_relative 'result'
require_relative 'error'

module SurrealDB
  # Main client class for interacting with SurrealDB
  # Provides high-level methods for CRUD operations, authentication, and database management
  class Client
    attr_reader :connection

    def initialize(url:, namespace: nil, database: nil, **options)
      @connection = Connection.new(url: url, **options)
      @namespace = namespace
      @database = database
      connect_and_setup
    end

    # Authentication methods
    def signin(user: nil, pass: nil, ns: nil, db: nil, ac: nil, **params)
      auth_params = { user: user, pass: pass, ns: ns, db: db, ac: ac }.merge(params).compact
      result = @connection.query('signin', auth_params)
      
      if result.success?
        @connection.authenticated = true
        @connection.auth_token = result.data['token'] if result.data.is_a?(Hash) && result.data['token']
      end
      
      result
    end

    def signup(ns:, db:, ac:, **params)
      auth_params = { ns: ns, db: db, ac: ac }.merge(params)
      result = @connection.query('signup', auth_params)
      
      if result.success?
        @connection.authenticated = true
        @connection.auth_token = result.data['token'] if result.data.is_a?(Hash) && result.data['token']
      end
      
      result
    end

    def authenticate(token)
      result = @connection.query('authenticate', token)
      
      if result.success?
        @connection.authenticated = true
        @connection.auth_token = token
      end
      
      result
    end

    def invalidate
      result = @connection.query('invalidate')
      
      if result.success?
        @connection.authenticated = false
        @connection.auth_token = nil
      end
      
      result
    end

    def info
      @connection.query('info')
    end

    # Connection management
    def ping
      @connection.query('ping')
    end

    def version
      @connection.query('version')
    end

    def use(namespace: nil, database: nil)
      @namespace = namespace if namespace
      @database = database if database
      @connection.query('use', @namespace, @database)
    end

    # Basic CRUD operations
    def create(table, data = nil, **options)
      if data.nil?
        @connection.query('create', table, nil, options)
      else
        @connection.query('create', table, data, options)
      end
    end

    def select(table_or_record, **options)
      @connection.query('select', table_or_record, options)
    end

    def update(table_or_record, data = nil, **options)
      @connection.query('update', table_or_record, data, options)
    end

    def upsert(table_or_record, data = nil, **options)
      @connection.query('upsert', table_or_record, data, options)
    end

    def delete(table_or_record, **options)
      @connection.query('delete', table_or_record, options)
    end

    def insert(table, data, **options)
      @connection.query('insert', table, data, options)
    end

    # Graph operations
    def relate(from_record, relation, to_record, data = nil, **options)
      if data.nil?
        @connection.query('relate', from_record, relation, to_record, options)
      else
        @connection.query('relate', from_record, relation, to_record, data, options)
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

      @connection.query('graphql', query_obj, options)
    end

    # Live queries (WebSocket only)
    def live(table, diff: false)
      raise SurrealDB::ConnectionError, "Live queries require WebSocket connection" unless @connection.websocket?
      
      @connection.query('live', table, diff)
    end

    def kill(query_uuid)
      raise SurrealDB::ConnectionError, "Kill requires WebSocket connection" unless @connection.websocket?
      
      @connection.query('kill', query_uuid)
    end

    # Session variables (WebSocket only)
    def let(name, value)
      raise SurrealDB::ConnectionError, "Session variables require WebSocket connection" unless @connection.websocket?
      
      @connection.query('let', name, value)
    end

    def unset(name)
      raise SurrealDB::ConnectionError, "Session variables require WebSocket connection" unless @connection.websocket?
      
      @connection.query('unset', name)
    end

    # Machine Learning (SurrealML)
    def run_function(func_name, version = nil, args = nil)
      params = [func_name]
      params << version if version
      params << args if args
      
      @connection.query('run', *params)
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

    # Advanced query methods
    def query(sql, vars = {})
      @connection.query('query', sql, vars)
    end

    alias_method :sql, :query

    # Convenience methods
    def find(table, id)
      select("#{table}:#{id}")
    end

    def count(table)
      result = query("SELECT count() FROM #{table} GROUP ALL")
      return 0 unless result.success? && result.data.any?
      
      result.data.first['count'] || 0
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

    # Query builder
    def from(table)
      QueryBuilder.new(self, table)
    end

    # Connection status
    def connected?
      @connection.connected?
    end

    def authenticated?
      @connection.authenticated?
    end

    def alive?
      ping.success?
    rescue
      false
    end

    def close
      @connection.close
    end

    # Reset connection state
    def reset
      result = @connection.query('reset')
      
      if result.success?
        @connection.authenticated = false
        @connection.auth_token = nil
      end
      
      result
    end

    private

    def connect_and_setup
      @connection.connect
      use(namespace: @namespace, database: @database) if @namespace && @database
    end
  end
end 