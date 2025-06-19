# frozen_string_literal: true

require_relative 'connection_pool'
require_relative 'client'
require_relative 'error'

module SurrealDB
  # High-performance client with connection pooling and caching
  class PerformanceClient
    attr_reader :pool, :cache_enabled, :cache_ttl

    def initialize(url:, pool_size: 10, cache_enabled: true, cache_ttl: 300, **options)
      @pool = ConnectionPool.new(size: pool_size, url: url, **options)
      @cache_enabled = cache_enabled
      @cache_ttl = cache_ttl
      @cache = {}
      @cache_mutex = Mutex.new
      @namespace = options[:namespace]
      @database = options[:database]
      @auth_params = nil
      
      # Setup authentication if provided
      setup_auth(options) if options[:user] && options[:pass]
    end

    # Execute query with connection pooling
    def query(sql, vars = {}, cache_key: nil)
      # Check cache first
      if @cache_enabled && cache_key
        cached_result = get_from_cache(cache_key)
        return cached_result if cached_result
      end

      result = @pool.with_connection do |connection|
        # Ensure connection is authenticated
        authenticate_connection(connection) if @auth_params
        
        # Execute query
        connection.query('query', sql, vars)
      end

      # Cache successful results
      if @cache_enabled && cache_key && result.success?
        set_cache(cache_key, result)
      end

      result
    end

    # Batch execute multiple queries for better performance
    def batch_query(queries)
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

    # High-performance bulk insert
    def bulk_insert(table, records, chunk_size: 1000)
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

    def close
      @pool.shutdown
      clear_cache
    end

    private

    def setup_auth(options)
      @auth_params = {
        user: options[:user],
        pass: options[:pass]
      }
    end

    def authenticate_connection(connection)
      return if connection.authenticated
      
      result = connection.query('signin', @auth_params)
      if result.success?
        connection.authenticated = true
      else
        raise SurrealDB::AuthenticationError, "Failed to authenticate connection"
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

    def clear_cache
      @cache_mutex.synchronize { @cache.clear }
    end
  end
end 