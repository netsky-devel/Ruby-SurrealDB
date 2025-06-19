require_relative 'surrealdb/version'
require_relative 'surrealdb/client'
require_relative 'surrealdb/connection'
require_relative 'surrealdb/query_builder'
require_relative 'surrealdb/result'
require_relative 'surrealdb/error'

# SurrealDB Ruby API wrapper
module SurrealDB
  # Create a new SurrealDB client
  # @param url [String] The SurrealDB server URL
  # @param options [Hash] Connection options
  # @return [SurrealDB::Client] A new client instance
  def self.connect(url, **options)
    Client.new(url, **options)
  end
end 