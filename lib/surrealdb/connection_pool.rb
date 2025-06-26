# frozen_string_literal: true

require 'thread'
require 'timeout'
require_relative 'connection'
require_relative 'error'

module SurrealDB
  # Connection pool for high-performance applications
  # Manages multiple connections to reduce connection overhead
  class ConnectionPool
    DEFAULT_POOL_SIZE = 10
    DEFAULT_TIMEOUT = 5
    
    attr_reader :size, :url, :options, :timeout

    def initialize(size: DEFAULT_POOL_SIZE, url:, timeout: DEFAULT_TIMEOUT, **options)
      validate_initialization_params(size, url, timeout)
      
      @size = size
      @url = url
      @timeout = timeout
      @options = options
      @pool = Queue.new
      @created_connections_count = 0
      @mutex = Mutex.new
      @is_shutdown = false
      
      initialize_pool
    end

    # Execute a block with a connection from the pool
    # @param block [Proc] Block to execute with connection
    # @return [Object] Result of the block
    # @raise [SurrealDB::ConnectionError] if pool is shutdown
    def with_connection(&block)
      ensure_pool_is_active
      
      connection = acquire_connection
      begin
        yield(connection)
      ensure
        release_connection(connection) if connection
      end
    end

    # Get pool statistics
    # @return [Hash] Pool statistics
    def stats
      {
        size: @size,
        available: available_connections_count,
        created: @created_connections_count,
        busy: busy_connections_count,
        shutdown: @is_shutdown
      }
    end

    # Shutdown the pool and close all connections
    def shutdown
      @is_shutdown = true
      close_all_connections
      reset_connection_counter
    end

    # Check if pool is healthy
    # @return [Boolean] True if pool is healthy
    def healthy?
      !@is_shutdown && @created_connections_count > 0
    end

    private

    def validate_initialization_params(size, url, timeout)
      raise ArgumentError, 'Pool size must be positive' if size <= 0
      raise ArgumentError, 'URL cannot be nil or empty' if url.nil? || url.empty?
      raise ArgumentError, 'Timeout must be positive' if timeout <= 0
    end

    def initialize_pool
      @size.times { add_connection_to_pool }
    end

    def ensure_pool_is_active
      raise SurrealDB::ConnectionError, 'Connection pool is shutdown' if @is_shutdown
    end

    def available_connections_count
      @pool.size
    end

    def busy_connections_count
      @created_connections_count - available_connections_count
    end

    def close_all_connections
      until @pool.empty?
        connection = extract_connection_from_pool
        close_connection_safely(connection)
      end
    end

    def reset_connection_counter
      @created_connections_count = 0
    end

    def add_connection_to_pool
      connection = create_new_connection
      @pool.push(connection) if connection
    end

    def extract_connection_from_pool
      @pool.pop(non_block: true)
    rescue ThreadError
      nil
    end

    def acquire_connection
      connection = try_get_existing_connection || try_create_new_connection || wait_for_available_connection
      ensure_connection_is_valid(connection)
    rescue Timeout::Error
      raise SurrealDB::TimeoutError, "Could not get connection from pool within #{@timeout} seconds"
    end

    def try_get_existing_connection
      extract_connection_from_pool
    end

    def try_create_new_connection
      return nil unless can_create_more_connections?
      create_new_connection
    end

    def wait_for_available_connection
      Timeout.timeout(@timeout) { @pool.pop }
    end

    def ensure_connection_is_valid(connection)
      return connection if connection && connection_is_valid?(connection)
      
      handle_invalid_connection(connection)
      create_new_connection
    end

    def handle_invalid_connection(connection)
      close_connection_safely(connection)
      decrement_connection_counter
    end

    def release_connection(connection)
      return if @is_shutdown
      
      if connection_is_valid?(connection)
        @pool.push(connection)
      else
        replace_invalid_connection(connection)
      end
    end

    def replace_invalid_connection(connection)
      close_connection_safely(connection)
      decrement_connection_counter
      add_replacement_connection_if_needed
    end

    def add_replacement_connection_if_needed
      return unless @created_connections_count < @size
      add_connection_to_pool
    end

    def create_new_connection
      @mutex.synchronize do
        return nil if cannot_create_connection?
        
        attempt_connection_creation
      end
    end

    def cannot_create_connection?
      @created_connections_count >= @size || @is_shutdown
    end

    def attempt_connection_creation
      connection = build_connection
      connection.connect
      increment_connection_counter
      connection
    rescue => error
      log_connection_creation_error(error)
      nil
    end

    def build_connection
      Connection.new(url: @url, **@options)
    end

    def increment_connection_counter
      @created_connections_count += 1
    end

    def decrement_connection_counter
      @mutex.synchronize { @created_connections_count -= 1 }
    end

    def log_connection_creation_error(error)
      warn "Failed to create connection: #{error.message}"
    end

    def can_create_more_connections?
      @mutex.synchronize { @created_connections_count < @size }
    end

    def connection_is_valid?(connection)
      return false unless connection&.connected?
      
      perform_connection_health_check(connection)
    end

    def perform_connection_health_check(connection)
      if connection.websocket?
        connection.connected?
      else
        # For HTTP connections, assume valid if not explicitly closed
        true
      end
    rescue
      false
    end

    def close_connection_safely(connection)
      connection&.close
    rescue
      # Ignore errors when closing connections
    end
  end
end