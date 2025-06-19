module SurrealDB
  # Main client class for SurrealDB operations
  class Client
    attr_reader :connection

    def initialize(url, **options)
      @connection = Connection.new(url, **options)
      
      # Auto-authenticate if credentials are provided
      if options[:username] && options[:password]
        signin(options[:username], options[:password])
      end
      
      # Auto-use namespace and database if provided
      if options[:namespace] && options[:database]
        use(options[:namespace], options[:database])
      end
    end

    # Execute a raw SQL query
    # @param query [String] SQL query to execute
    # @param variables [Hash] Query variables
    # @return [SurrealDB::Result] Query result
    def query(query, variables = {})
      response = @connection.query(query, variables)
      Result.new(response)
    end

    # Create a new query builder
    # @return [SurrealDB::QueryBuilder] New query builder instance
    def query_builder
      QueryBuilder.new(self)
    end

    # Sign in with credentials
    # @param username [String] Username
    # @param password [String] Password
    # @return [Boolean] Success status
    def signin(username, password)
      @connection.signin(username, password)
    end

    # Use namespace and database
    # @param namespace [String] Namespace name
    # @param database [String] Database name
    # @return [Boolean] Success status
    def use(namespace, database)
      @connection.use(namespace, database)
      true
    end

    # Create a new record
    # @param table [String] Table name
    # @param data [Hash] Record data
    # @return [SurrealDB::Result] Created record
    def create(table, data = {})
      if data.empty?
        query("CREATE #{table}")
      else
        variables = data.transform_keys(&:to_s)
        placeholders = variables.keys.map { |k| "#{k}: $#{k}" }.join(', ')
        query("CREATE #{table} SET #{placeholders}", variables)
      end
    end

    # Select records from a table
    # @param table [String] Table name
    # @param conditions [Hash] WHERE conditions
    # @return [SurrealDB::Result] Selected records
    def select(table, conditions = {})
      if conditions.empty?
        query("SELECT * FROM #{table}")
      else
        where_clause = conditions.map { |k, _v| "#{k} = $#{k}" }.join(' AND ')
        query("SELECT * FROM #{table} WHERE #{where_clause}", conditions.transform_keys(&:to_s))
      end
    end

    # Update records in a table
    # @param table [String] Table name
    # @param data [Hash] Data to update
    # @param conditions [Hash] WHERE conditions
    # @return [SurrealDB::Result] Updated records
    def update(table, data, conditions = {})
      set_clause = data.map { |k, _v| "#{k} = $#{k}" }.join(', ')
      variables = data.transform_keys(&:to_s)
      
      if conditions.empty?
        query("UPDATE #{table} SET #{set_clause}", variables)
      else
        where_clause = conditions.map { |k, _v| "#{k} = $where_#{k}" }.join(' AND ')
        where_variables = conditions.transform_keys { |k| "where_#{k}" }.transform_values(&:to_s)
        all_variables = variables.merge(where_variables)
        query("UPDATE #{table} SET #{set_clause} WHERE #{where_clause}", all_variables)
      end
    end

    # Delete records from a table
    # @param table [String] Table name
    # @param conditions [Hash] WHERE conditions
    # @return [SurrealDB::Result] Deletion result
    def delete(table, conditions = {})
      if conditions.empty?
        query("DELETE FROM #{table}")
      else
        where_clause = conditions.map { |k, _v| "#{k} = $#{k}" }.join(' AND ')
        query("DELETE FROM #{table} WHERE #{where_clause}", conditions.transform_keys(&:to_s))
      end
    end

    # Insert records into a table
    # @param table [String] Table name
    # @param data [Hash, Array] Data to insert
    # @return [SurrealDB::Result] Inserted records
    def insert(table, data)
      if data.is_a?(Hash)
        create(table, data)
      elsif data.is_a?(Array)
        query("INSERT INTO #{table} #{data.to_json}")
      else
        raise ArgumentError, "Data must be a Hash or Array"
      end
    end

    # Get a specific record by ID
    # @param table [String] Table name
    # @param id [String] Record ID
    # @return [SurrealDB::Result] Record result
    def find(table, id)
      query("SELECT * FROM #{table}:#{id}")
    end

    # Get the first record from a table
    # @param table [String] Table name
    # @param conditions [Hash] WHERE conditions
    # @return [Hash, nil] First record or nil
    def first(table, conditions = {})
      result = select(table, conditions)
      result.first
    end

    # Get all records from a table
    # @param table [String] Table name
    # @param conditions [Hash] WHERE conditions
    # @return [Array] All matching records
    def all(table, conditions = {})
      result = select(table, conditions)
      result.all
    end

    # Count records in a table
    # @param table [String] Table name
    # @param conditions [Hash] WHERE conditions
    # @return [Integer] Number of records
    def count(table, conditions = {})
      if conditions.empty?
        result = query("SELECT count() FROM #{table} GROUP ALL")
      else
        where_clause = conditions.map { |k, _v| "#{k} = $#{k}" }.join(' AND ')
        result = query("SELECT count() FROM #{table} WHERE #{where_clause} GROUP ALL", conditions.transform_keys(&:to_s))
      end
      
      first_result = result.first
      first_result && first_result['count'] || 0
    end

    # Check if table exists
    # @param table [String] Table name
    # @return [Boolean] True if table exists
    def table_exists?(table)
      result = query("INFO FOR DB")
      tables = result.first
      return false unless tables && tables['tb']
      
      tables['tb'].key?(table)
    end

    # Create a table with schema
    # @param table [String] Table name
    # @param schema [Hash] Table schema
    # @return [SurrealDB::Result] Creation result
    def create_table(table, schema = {})
      if schema.empty?
        query("DEFINE TABLE #{table}")
      else
        query("DEFINE TABLE #{table} #{schema.to_json}")
      end
    end

    # Drop a table
    # @param table [String] Table name
    # @return [SurrealDB::Result] Deletion result
    def drop_table(table)
      query("REMOVE TABLE #{table}")
    end

    # Execute a transaction
    # @param queries [Array] Array of SQL queries
    # @return [SurrealDB::Result] Transaction result
    def transaction(queries)
      transaction_query = "BEGIN TRANSACTION;\n" + queries.join(";\n") + ";\nCOMMIT TRANSACTION;"
      query(transaction_query)
    end

    # Get database info
    # @return [Hash] Database information
    def info
      result = query("INFO FOR DB")
      result.first || {}
    end

    # Get server version
    # @return [String] Server version
    def version
      result = query("VERSION")
      result.first&.dig('version') || 'unknown'
    end

    # Close the connection
    def close
      @connection.close
    end

    # Check if connection is alive
    # @return [Boolean] Connection status
    def alive?
      @connection.alive?
    end

    # Ping the server
    # @return [Boolean] True if server responds
    def ping
      begin
        query("SELECT 1")
        true
      rescue
        false
      end
    end

    private

    # Helper method to handle different result types
    def handle_result(response)
      if response.is_a?(Array) && response.length == 1
        Result.new(response.first)
      else
        Result.new(response)
      end
    end
  end
end 