# frozen_string_literal: true

module SurrealDB
  # Handles live queries and real-time notifications from SurrealDB
  class LiveQuery
    attr_reader :id, :table, :diff, :client, :callbacks

    def initialize(client, id, table, diff: false)
      @client = client
      @id = id
      @table = table
      @diff = diff
      @callbacks = {}
      @active = true
    end

    # Register a callback for specific actions
    # @param action [String, Symbol] Action to listen for ('CREATE', 'UPDATE', 'DELETE', or :all)
    # @param block [Proc] Callback block
    def on(action = :all, &block)
      action = action.to_s.upcase if action.is_a?(Symbol) && action != :all
      @callbacks[action] = block
      self
    end

    # Handle incoming notifications
    def handle_notification(notification)
      return unless @active

      action = notification.dig('result', 'action')
      data = notification['result']

      # Call specific action callback
      if @callbacks[action]
        @callbacks[action].call(data)
      end

      # Call general callback
      if @callbacks[:all]
        @callbacks[:all].call(data)
      end
    end

    # Kill this live query
    def kill
      return false unless @active

      result = @client.kill(@id)
      @active = false if result.success?
      result.success?
    end

    # Check if the live query is still active
    def active?
      @active
    end

    # Get query information
    def info
      {
        id: @id,
        table: @table,
        diff: @diff,
        active: @active,
        callbacks: @callbacks.keys
      }
    end
  end
end 