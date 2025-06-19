# frozen_string_literal: true

require 'thread'
require_relative 'connection'
require_relative 'error'

module SurrealDB
  # Connection pool for high-performance applications
  # Manages multiple connections to reduce connection overhead
  class ConnectionPool
    attr_reader :size, :url, :options, :timeout

    def initialize(size: 10, url:, timeout: 5, **options)
      @size = size
      @url = url
      @timeout = timeout
      @options = options
      @pool = Queue.new
      @created = 0
      @mutex = Mutex.new
      @shutdown = false
      
      # Pre-fill pool with initial connections
      fill_pool
    end

    # Execute a block with a connection from the pool
    # @param block [Proc] Block to execute with connection
    # @return [Object] Result of the block
    def with_connection(&block)
      raise SurrealDB::ConnectionError, "Connection pool is shutdown" if @shutdown
      
      connection = checkout
      begin
        yield(connection)
      ensure
        checkin(connection) if connection
      end
    end

    # Get pool statistics
    # @return [Hash] Pool statistics
    def stats
      {
        size: @size,
        available: @pool.size,
        created: @created,
        busy: @created - @pool.size,
        shutdown: @shutdown
      }
    end

    # Shutdown the pool and close all connections
    def shutdown
      @shutdown = true
      
      # Close all connections in pool
      until @pool.empty?
        connection = @pool.pop(non_block: true) rescue nil
        connection&.close
      end
      
      @created = 0
    end

    # Check if pool is healthy
    # @return [Boolean] True if pool is healthy
    def healthy?
      !@shutdown && @created > 0
    end

    private

    def fill_pool
      @size.times do
        connection = create_connection
        @pool.push(connection) if connection
      end
    end

    def checkout
      # Try to get existing connection
      connection = @pool.pop(non_block: true) rescue nil
      
      # If no connection available and we can create more
      if connection.nil? && can_create_connection?
        connection = create_connection
      end
      
      # If still no connection, wait for one
      if connection.nil?
        Timeout.timeout(@timeout) do
          connection = @pool.pop
        end
      end
      
      # Validate connection
      if connection && !connection_valid?(connection)
        connection.close rescue nil
        @mutex.synchronize { @created -= 1 }
        connection = create_connection
      end
      
      connection
    rescue Timeout::Error
      raise SurrealDB::TimeoutError, "Could not get connection from pool within #{@timeout} seconds"
    end

    def checkin(connection)
      return if @shutdown
      
      if connection_valid?(connection)
        @pool.push(connection)
      else
        connection.close rescue nil
        @mutex.synchronize { @created -= 1 }
        
        # Replace with new connection if pool is not full
        if @created < @size
          new_connection = create_connection
          @pool.push(new_connection) if new_connection
        end
      end
    end

    def create_connection
      @mutex.synchronize do
        return nil if @created >= @size || @shutdown
        
        begin
          connection = Connection.new(url: @url, **@options)
          connection.connect
          @created += 1
          connection
        rescue => e
          # Log error but don't raise to avoid breaking pool
          warn "Failed to create connection: #{e.message}"
          nil
        end
      end
    end

    def can_create_connection?
      @mutex.synchronize { @created < @size }
    end

    def connection_valid?(connection)
      return false unless connection
      return false unless connection.connected?
      
      # Simple ping test
      begin
        # For HTTP connections, we can't easily test without making a request
        # For WebSocket, we can check the connection state
        if connection.websocket?
          connection.connected?
        else
          # For HTTP, assume valid if not explicitly closed
          true
        end
      rescue
        false
      end
    end
  end
end 