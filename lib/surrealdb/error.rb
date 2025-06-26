module SurrealDB
  # Base error class for all SurrealDB-related exceptions
  # Provides common error handling functionality and context
  class Error < StandardError
    attr_reader :error_code, :context

    def initialize(message = nil, error_code: nil, context: {})
      super(message)
      @error_code = error_code
      @context = context
    end

    # Returns formatted error message with context
    def detailed_message
      base_message = message || self.class.default_message
      return base_message if context.empty?
      
      "#{base_message} (Context: #{context.inspect})"
    end

    # Override in subclasses to provide default error messages
    def self.default_message
      'An error occurred in SurrealDB'
    end
  end

  # Raised when database connection fails or is lost
  class ConnectionError < Error
    def self.default_message
      'Failed to establish or maintain database connection'
    end
  end

  # Raised when authentication or authorization fails
  class AuthenticationError < Error
    def self.default_message
      'Authentication failed - invalid credentials or insufficient permissions'
    end
  end

  # Raised when query execution fails due to syntax or logical errors
  class QueryError < Error
    attr_reader :query, :line_number

    def initialize(message = nil, query: nil, line_number: nil, **options)
      super(message, **options)
      @query = query
      @line_number = line_number
    end

    def detailed_message
      base_message = super
      query_info = build_query_info
      query_info.empty? ? base_message : "#{base_message}#{query_info}"
    end

    def self.default_message
      'Query execution failed'
    end

    private

    def build_query_info
      parts = []
      parts << " Query: #{query}" if query
      parts << " Line: #{line_number}" if line_number
      parts.join
    end
  end

  # Raised when operations exceed configured timeout limits
  class TimeoutError < Error
    attr_reader :timeout_duration, :operation_type

    def initialize(message = nil, timeout_duration: nil, operation_type: nil, **options)
      super(message, **options)
      @timeout_duration = timeout_duration
      @operation_type = operation_type
    end

    def detailed_message
      base_message = super
      timeout_info = build_timeout_info
      timeout_info.empty? ? base_message : "#{base_message}#{timeout_info}"
    end

    def self.default_message
      'Operation timed out'
    end

    private

    def build_timeout_info
      parts = []
      parts << " Operation: #{operation_type}" if operation_type
      parts << " Timeout: #{timeout_duration}s" if timeout_duration
      parts.join
    end
  end

  # Raised when invalid configuration is detected
  class ConfigurationError < Error
    attr_reader :config_key, :config_value

    def initialize(message = nil, config_key: nil, config_value: nil, **options)
      super(message, **options)
      @config_key = config_key
      @config_value = config_value
    end

    def detailed_message
      base_message = super
      config_info = build_config_info
      config_info.empty? ? base_message : "#{base_message}#{config_info}"
    end

    def self.default_message
      'Invalid configuration detected'
    end

    private

    def build_config_info
      return '' unless config_key
      
      config_value ? " Key: #{config_key}, Value: #{config_value}" : " Key: #{config_key}"
    end
  end
end