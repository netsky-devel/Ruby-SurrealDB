module SurrealDB
  # Query builder for constructing SurrealDB queries
  class QueryBuilder
    def initialize(client)
      @client = client
      @query_parts = []
      @variables = {}
    end

    # SELECT query
    # @param fields [String, Array] Fields to select
    # @return [QueryBuilder] Self for method chaining
    def select(*fields)
      fields_str = fields.empty? ? '*' : fields.join(', ')
      @query_parts << "SELECT #{fields_str}"
      self
    end

    # FROM clause
    # @param table [String] Table name
    # @return [QueryBuilder] Self for method chaining
    def from(table)
      @query_parts << "FROM #{table}"
      self
    end

    # WHERE clause
    # @param condition [String] WHERE condition
    # @param variables [Hash] Variables for the condition
    # @return [QueryBuilder] Self for method chaining
    def where(condition, variables = {})
      @query_parts << "WHERE #{condition}"
      @variables.merge!(variables)
      self
    end

    # ORDER BY clause
    # @param field [String] Field to order by
    # @param direction [String] Order direction (ASC/DESC)
    # @return [QueryBuilder] Self for method chaining
    def order_by(field, direction = 'ASC')
      @query_parts << "ORDER BY #{field} #{direction.upcase}"
      self
    end

    # LIMIT clause
    # @param count [Integer] Number of records to limit
    # @return [QueryBuilder] Self for method chaining
    def limit(count)
      @query_parts << "LIMIT #{count}"
      self
    end

    # GROUP BY clause
    # @param fields [String, Array] Fields to group by
    # @return [QueryBuilder] Self for method chaining
    def group_by(*fields)
      fields_str = fields.join(', ')
      @query_parts << "GROUP BY #{fields_str}"
      self
    end

    # HAVING clause
    # @param condition [String] HAVING condition
    # @return [QueryBuilder] Self for method chaining
    def having(condition)
      @query_parts << "HAVING #{condition}"
      self
    end

    # INSERT query
    # @param table [String] Table name
    # @param data [Hash, Array] Data to insert
    # @return [QueryBuilder] Self for method chaining
    def insert(table, data = nil)
      if data
        if data.is_a?(Hash)
          fields = data.keys.join(', ')
          values = data.keys.map { |k| "$#{k}" }.join(', ')
          @query_parts << "INSERT INTO #{table} (#{fields}) VALUES (#{values})"
          @variables.merge!(data)
        elsif data.is_a?(Array)
          @query_parts << "INSERT INTO #{table} #{data.to_json}"
        end
      else
        @query_parts << "INSERT INTO #{table}"
      end
      self
    end

    # UPDATE query
    # @param table [String] Table name
    # @param data [Hash] Data to update
    # @return [QueryBuilder] Self for method chaining
    def update(table, data = nil)
      if data
        set_clauses = data.map { |k, _v| "#{k} = $#{k}" }.join(', ')
        @query_parts << "UPDATE #{table} SET #{set_clauses}"
        @variables.merge!(data)
      else
        @query_parts << "UPDATE #{table}"
      end
      self
    end

    # SET clause (for UPDATE)
    # @param data [Hash] Data to set
    # @return [QueryBuilder] Self for method chaining
    def set(data)
      set_clauses = data.map { |k, _v| "#{k} = $#{k}" }.join(', ')
      @query_parts << "SET #{set_clauses}"
      @variables.merge!(data)
      self
    end

    # DELETE query
    # @param table [String] Table name
    # @return [QueryBuilder] Self for method chaining
    def delete(table = nil)
      if table
        @query_parts << "DELETE FROM #{table}"
      else
        @query_parts << "DELETE"
      end
      self
    end

    # CREATE query for tables
    # @param table [String] Table name
    # @param schema [Hash] Table schema
    # @return [QueryBuilder] Self for method chaining
    def create_table(table, schema = nil)
      if schema
        @query_parts << "CREATE TABLE #{table} #{schema.to_json}"
      else
        @query_parts << "CREATE TABLE #{table}"
      end
      self
    end

    # DROP query
    # @param table [String] Table name
    # @return [QueryBuilder] Self for method chaining
    def drop_table(table)
      @query_parts << "DROP TABLE #{table}"
      self
    end

    # Raw SQL
    # @param sql [String] Raw SQL query
    # @param variables [Hash] Variables for the query
    # @return [QueryBuilder] Self for method chaining
    def raw(sql, variables = {})
      @query_parts << sql
      @variables.merge!(variables)
      self
    end

    # Build the query string
    # @return [String] The constructed query
    def to_sql
      @query_parts.join(' ')
    end

    # Execute the query
    # @return [SurrealDB::Result] Query result
    def execute
      sql = to_sql
      raise QueryError, "Empty query" if sql.strip.empty?
      
      @client.query(sql, @variables)
    end

    # Execute and return first result
    # @return [Hash, nil] First result or nil
    def first
      execute.first
    end

    # Execute and return all results
    # @return [Array] All results
    def all
      execute.all
    end

    private

    def reset
      @query_parts.clear
      @variables.clear
    end
  end
end 