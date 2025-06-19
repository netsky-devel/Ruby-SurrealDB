# frozen_string_literal: true

require_relative 'performance_client'

module SurrealDB
  module Rails
    # Rails configuration for SurrealDB
    class Configuration
      attr_accessor :url, :namespace, :database, :pool_size, :cache_enabled, :cache_ttl,
                    :user, :pass, :timeout, :logger

      def initialize
        @url = ENV['SURREALDB_URL'] || 'http://localhost:8000'
        @namespace = ENV['SURREALDB_NAMESPACE'] || 'development'
        @database = ENV['SURREALDB_DATABASE'] || 'main'
        @pool_size = (ENV['SURREALDB_POOL_SIZE'] || 10).to_i
        @cache_enabled = ENV['SURREALDB_CACHE_ENABLED'] != 'false'
        @cache_ttl = (ENV['SURREALDB_CACHE_TTL'] || 300).to_i
        @user = ENV['SURREALDB_USER']
        @pass = ENV['SURREALDB_PASS']
        @timeout = (ENV['SURREALDB_TIMEOUT'] || 30).to_i
        @logger = nil
      end

      def to_h
        {
          url: @url,
          namespace: @namespace,
          database: @database,
          pool_size: @pool_size,
          cache_enabled: @cache_enabled,
          cache_ttl: @cache_ttl,
          user: @user,
          pass: @pass,
          timeout: @timeout
        }.compact
      end
    end

    # Rails integration module
    module Integration
      extend self

      attr_reader :configuration, :client

      def configure
        @configuration = Configuration.new
        yield(@configuration) if block_given?
        
        # Initialize client with configuration
        @client = PerformanceClient.new(**@configuration.to_h)
        
        # Setup Rails logging if available
        setup_logging if defined?(::Rails)
        
        @client
      end

      def client
        @client || configure
      end

      def reset!
        @client&.close
        @client = nil
        @configuration = nil
      end

      private

      def setup_logging
        return unless @configuration.logger || defined?(::Rails.logger)
        
        logger = @configuration.logger || ::Rails.logger
        
        # Add logging to client operations (simplified)
        @client.define_singleton_method(:query_with_logging) do |*args, **kwargs|
          start_time = Time.now
          result = query(*args, **kwargs)
          duration = ((Time.now - start_time) * 1000).round(2)
          
          logger.debug "SurrealDB Query (#{duration}ms): #{args.first}"
          result
        end
        
        @client.alias_method :query_without_logging, :query
        @client.alias_method :query, :query_with_logging
      end
    end

    # Rails controller helpers
    module ControllerHelpers
      def surrealdb
        SurrealDB::Rails::Integration.client
      end

      def with_surrealdb_transaction(&block)
        surrealdb.pool.with_connection do |connection|
          connection.query('BEGIN TRANSACTION')
          begin
            result = yield(surrealdb)
            connection.query('COMMIT TRANSACTION')
            result
          rescue => e
            connection.query('CANCEL TRANSACTION')
            raise e
          end
        end
      end
    end

    # ActiveRecord-like query methods
    module QueryMethods
      def where(conditions)
        @where_conditions ||= []
        @where_conditions << conditions
        self
      end

      def limit(count)
        @limit_count = count
        self
      end

      def order(field)
        @order_field = field
        self
      end

      def build_query
        query = "SELECT * FROM #{@table}"
        
        if @where_conditions && @where_conditions.any?
          where_clause = @where_conditions.map do |condition|
            if condition.is_a?(Hash)
              condition.map { |k, v| "#{k} = '#{v}'" }.join(' AND ')
            else
              condition
            end
          end.join(' AND ')
          query += " WHERE #{where_clause}"
        end
        
        query += " ORDER BY #{@order_field}" if @order_field
        query += " LIMIT #{@limit_count}" if @limit_count
        
        query
      end

      def execute
        surrealdb.query(build_query)
      end

      private

      def surrealdb
        SurrealDB::Rails::Integration.client
      end
    end
  end
end

# Auto-setup Rails integration if Rails is detected
if defined?(Rails)
  require_relative 'rails/railtie'
end 