module SurrealDB
  # Base error class for all SurrealDB errors
  class Error < StandardError; end

  # Connection related errors
  class ConnectionError < Error; end

  # Authentication errors
  class AuthenticationError < Error; end

  # Query related errors
  class QueryError < Error; end

  # Timeout errors
  class TimeoutError < Error; end

  # Invalid configuration errors
  class ConfigurationError < Error; end
end 