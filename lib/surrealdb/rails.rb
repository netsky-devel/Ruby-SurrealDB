# frozen_string_literal: true

require_relative 'performance_client'

module SurrealDB
  module Rails
    # Configuration class responsible for managing SurrealDB connection settings
    class Configuration
      DEFAULT_VALUES = {
        url: 'http://localhost:8000',
        namespace: 'development',
        database: 'main',
        pool_size: 10,
        cache_ttl: 300,
        timeout: 30
      }.freeze

      ENV_MAPPING = {
        url: 'SURREALDB_URL',
        namespace: 'SURREALDB_NAMESPACE',
        database: 'SURREALDB_DATABASE',
        pool_size: 'SURREALDB_POOL_SIZE',
        cache_enabled: 'SURREALDB_CACHE_ENABLED',
        cache_ttl: 'SURREALDB_CACHE_TTL',
        user: 'SURREALDB_USER',
        pass: 'SURREALDB_PASS',
        timeout: 'SURREALDB_TIMEOUT'
      }.freeze

      attr_accessor :url, :namespace, :database, :pool_size, :cache_enabled, :cache_ttl,
                    :user, :pass, :timeout, :logger

      def initialize
        load_default_configuration
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

      private

      def load_default_configuration
        @url = fetch_env_value(:url)
        @namespace = fetch_env_value(:namespace)
        @database = fetch_env_value(:database)
        @pool_size = fetch_env_integer(:pool_size)
        @cache_enabled = fetch_env_boolean(:cache_enabled)
        @cache_ttl = fetch_env_integer(:cache_ttl)
        @user = fetch_env_value(:user)
        @pass = fetch_env_value(:pass)
        @timeout = fetch_env_integer(:timeout)
        @logger = nil
      end

      def fetch_env_value(key)
        ENV[ENV_MAPPING[key]] || DEFAULT_VALUES[key]
      end

      def fetch_env_integer(key)
        (ENV[ENV_MAPPING[key]] || DEFAULT_VALUES[key]).to_i
      end

      def fetch_env_boolean(key)
        ENV[ENV_MAPPING[key]] != 'false'
      end
    end

    # Service responsible for setting up logging functionality
    class LoggingService
      def self.setup_for_client(client, configuration)
        return unless should_setup_logging?(configuration)

        logger = determine_logger(configuration)
        enhance_client_with_logging(client, logger)
      end

      private_class_method

      def self.should_setup_logging?(configuration)
        configuration.logger || defined?(::Rails.logger)
      end

      def self.determine_logger(configuration)
        configuration.logger || ::Rails.logger
      end

      def self.enhance_client_with_logging(client, logger)
        client.define_singleton_method(:query_with_logging) do |*args, **kwargs|
          start_time = Time.now
          result = query_without_logging(*args, **kwargs)
          duration = calculate_duration_ms(start_time)
          
          logger.debug "SurrealDB Query (#{duration}ms): #{args.first}"
          result
        end
        
        client.alias_method :query_without_logging, :query
        client.alias_method :query, :query_with_logging
      end

      def self.calculate_duration_ms(start_time)
        ((Time.now - start_time) * 1000).round(2)
      end
    end

    # Main integration service for Rails framework
    class IntegrationService
      attr_reader :configuration, :client

      def initialize
        @configuration = nil
        @client = nil
      end

      def configure
        @configuration = Configuration.new
        yield(@configuration) if block_given?
        
        initialize_client
        setup_logging_if_available
        
        @client
      end

      def client
        @client || configure
      end

      def reset!
        cleanup_existing_client
        reset_configuration
      end

      private

      def initialize_client
        @client = PerformanceClient.new(**@configuration.to_h)
      end

      def setup_logging_if_available
        return unless rails_environment?
        
        LoggingService.setup_for_client(@client, @configuration)
      end

      def rails_environment?
        defined?(::Rails)
      end

      def cleanup_existing_client
        @client&.close
        @client = nil
      end

      def reset_configuration
        @configuration = nil
      end
    end

    # Singleton access to integration service
    module Integration
      extend self

      def configure(&block)
        integration_service.configure(&block)
      end

      def client
        integration_service.client
      end

      def reset!
        integration_service.reset!
        @integration_service = nil
      end

      private

      def integration_service
        @integration_service ||= IntegrationService.new
      end
    end

    # Transaction management service
    class TransactionService
      def self.execute_with_transaction(client, &block)
        client.pool.with_connection do |connection|
          TransactionManager.new(connection, client).execute(&block)
        end
      end

      # Handles individual transaction lifecycle
      class TransactionManager
        def initialize(connection, client)
          @connection = connection
          @client = client
        end

        def execute(&block)
          begin_transaction
          result = yield(@client)
          commit_transaction
          result
        rescue => error
          rollback_transaction
          raise error
        end

        private

        def begin_transaction
          @connection.query('BEGIN TRANSACTION')
        end

        def commit_transaction
          @connection.query('COMMIT TRANSACTION')
        end

        def rollback_transaction
          @connection.query('CANCEL TRANSACTION')
        end
      end
    end

    # Rails controller helper methods
    module ControllerHelpers
      def surrealdb
        SurrealDB::Rails::Integration.client
      end

      def with_surrealdb_transaction(&block)
        TransactionService.execute_with_transaction(surrealdb, &block)
      end
    end

    # Query builder for SurrealDB queries
    class QueryBuilder
      def initialize(table_name)
        @table_name = table_name
        @where_conditions = []
        @limit_count = nil
        @order_field = nil
      end

      def where(conditions)
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
        QueryStringBuilder.new(@table_name, query_options).build
      end

      def execute
        client.query(build_query)
      end

      private

      def query_options
        {
          where_conditions: @where_conditions,
          limit_count: @limit_count,
          order_field: @order_field
        }
      end

      def client
        SurrealDB::Rails::Integration.client
      end
    end

    # Builds SQL query strings from components
    class QueryStringBuilder
      def initialize(table_name, options)
        @table_name = table_name
        @where_conditions = options[:where_conditions] || []
        @limit_count = options[:limit_count]
        @order_field = options[:order_field]
      end

      def build
        query_parts = [base_select_clause]
        query_parts << where_clause if has_where_conditions?
        query_parts << order_clause if has_order_field?
        query_parts << limit_clause if has_limit?
        
        query_parts.join(' ')
      end

      private

      def base_select_clause
        "SELECT * FROM #{@table_name}"
      end

      def where_clause
        "WHERE #{build_where_conditions}"
      end

      def order_clause
        "ORDER BY #{@order_field}"
      end

      def limit_clause
        "LIMIT #{@limit_count}"
      end

      def build_where_conditions
        @where_conditions.map { |condition| format_condition(condition) }.join(' AND ')
      end

      def format_condition(condition)
        return condition unless condition.is_a?(Hash)
        
        condition.map { |key, value| "#{key} = '#{value}'" }.join(' AND ')
      end

      def has_where_conditions?
        @where_conditions.any?
      end

      def has_order_field?
        !@order_field.nil?
      end

      def has_limit?
        !@limit_count.nil?
      end
    end

    # ActiveRecord-like query interface
    module QueryMethods
      def where(conditions)
        query_builder.where(conditions)
      end

      def limit(count)
        query_builder.limit(count)
      end

      def order(field)
        query_builder.order(field)
      end

      def execute
        query_builder.execute
      end

      private

      def query_builder
        @query_builder ||= QueryBuilder.new(@table)
      end
    end
  end
end

# Auto-setup Rails integration if Rails is detected
if defined?(Rails)
  require_relative 'rails/railtie'
end