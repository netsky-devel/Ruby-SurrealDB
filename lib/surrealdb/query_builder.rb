module SurrealDB
  # Query builder for constructing SurrealDB queries using fluent interface
  class QueryBuilder
    VALID_ORDER_DIRECTIONS = %w[ASC DESC].freeze
    EMPTY_QUERY_ERROR = "Empty query".freeze

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
      add_query_part("SELECT #{fields_str}")
    end

    # FROM clause
    # @param table [String] Table name
    # @return [QueryBuilder] Self for method chaining
    def from(table)
      add_query_part("FROM #{table}")
    end

    # WHERE clause
    # @param condition [String] WHERE condition
    # @param variables [Hash] Variables for the condition
    # @return [QueryBuilder] Self for method chaining
    def where(condition, variables = {})
      add_query_part("WHERE #{condition}")
      merge_variables(variables)
    end

    # ORDER BY clause
    # @param field [String] Field to order by
    # @param direction [String] Order direction (ASC/DESC)
    # @return [QueryBuilder] Self for method chaining
    def order_by(field, direction = 'ASC')
      normalized_direction = normalize_order_direction(direction)
      add_query_part("ORDER BY #{field} #{normalized_direction}")
    end

    # LIMIT clause
    # @param count [Integer] Number of records to limit
    # @return [QueryBuilder] Self for method chaining
    def limit(count)
      add_query_part("LIMIT #{count}")
    end

    # GROUP BY clause
    # @param fields [String, Array] Fields to group by
    # @return [QueryBuilder] Self for method chaining
    def group_by(*fields)
      fields_str = fields.join(', ')
      add_query_part("GROUP BY #{fields_str}")
    end

    # HAVING clause
    # @param condition [String] HAVING condition
    # @return [QueryBuilder] Self for method chaining
    def having(condition)
      add_query_part("HAVING #{condition}")
    end

    # INSERT query
    # @param table [String] Table name
    # @param data [Hash, Array] Data to insert
    # @return [QueryBuilder] Self for method chaining
    def insert(table, data = nil)
      query_part = build_insert_query(table, data)
      add_query_part(query_part)
    end

    # UPDATE query
    # @param table [String] Table name
    # @param data [Hash] Data to update
    # @return [QueryBuilder] Self for method chaining
    def update(table, data = nil)
      query_part = build_update_query(table, data)
      add_query_part(query_part)
    end

    # SET clause (for UPDATE)
    # @param data [Hash] Data to set
    # @return [QueryBuilder] Self for method chaining
    def set(data)
      set_clauses = build_set_clauses(data)
      add_query_part("SET #{set_clauses}")
      merge_variables(data)
    end

    # DELETE query
    # @param table [String] Table name
    # @return [QueryBuilder] Self for method chaining
    def delete(table = nil)
      query_part = table ? "DELETE FROM #{table}" : "DELETE"
      add_query_part(query_part)
    end

    # CREATE query for tables
    # @param table [String] Table name
    # @param schema [Hash] Table schema
    # @return [QueryBuilder] Self for method chaining
    def create_table(table, schema = nil)
      query_part = build_create_table_query(table, schema)
      add_query_part(query_part)
    end

    # DROP query
    # @param table [String] Table name
    # @return [QueryBuilder] Self for method chaining
    def drop_table(table)
      add_query_part("DROP TABLE #{table}")
    end

    # Raw SQL
    # @param sql [String] Raw SQL query
    # @param variables [Hash] Variables for the query
    # @return [QueryBuilder] Self for method chaining
    def raw(sql, variables = {})
      add_query_part(sql)
      merge_variables(variables)
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
      validate_query_not_empty(sql)
      
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

    # Add query part and return self for chaining
    # @param part [String] Query part to add
    # @return [QueryBuilder] Self for method chaining
    def add_query_part(part)
      @query_parts << part
      self
    end

    # Merge variables and return self for chaining
    # @param variables [Hash] Variables to merge
    # @return [QueryBuilder] Self for method chaining
    def merge_variables(variables)
      @variables.merge!(variables)
      self
    end

    # Normalize order direction to uppercase
    # @param direction [String] Order direction
    # @return [String] Normalized direction
    def normalize_order_direction(direction)
      normalized = direction.upcase
      VALID_ORDER_DIRECTIONS.include?(normalized) ? normalized : 'ASC'
    end

    # Build INSERT query part
    # @param table [String] Table name
    # @param data [Hash, Array, nil] Data to insert
    # @return [String] INSERT query part
    def build_insert_query(table, data)
      return "INSERT INTO #{table}" unless data

      case data
      when Hash
        build_insert_with_hash(table, data)
      when Array
        "INSERT INTO #{table} #{data.to_json}"
      else
        "INSERT INTO #{table}"
      end
    end

    # Build INSERT query with hash data
    # @param table [String] Table name
    # @param data [Hash] Data to insert
    # @return [String] INSERT query part
    def build_insert_with_hash(table, data)
      fields = data.keys.join(', ')
      values = data.keys.map { |k| "$#{k}" }.join(', ')
      merge_variables(data)
      "INSERT INTO #{table} (#{fields}) VALUES (#{values})"
    end

    # Build UPDATE query part
    # @param table [String] Table name
    # @param data [Hash, nil] Data to update
    # @return [String] UPDATE query part
    def build_update_query(table, data)
      return "UPDATE #{table}" unless data

      set_clauses = build_set_clauses(data)
      merge_variables(data)
      "UPDATE #{table} SET #{set_clauses}"
    end

    # Build SET clauses for UPDATE
    # @param data [Hash] Data for SET clause
    # @return [String] SET clauses
    def build_set_clauses(data)
      data.map { |k, _v| "#{k} = $#{k}" }.join(', ')
    end

    # Build CREATE TABLE query part
    # @param table [String] Table name
    # @param schema [Hash, nil] Table schema
    # @return [String] CREATE TABLE query part
    def build_create_table_query(table, schema)
      return "CREATE TABLE #{table}" unless schema
      
      "CREATE TABLE #{table} #{schema.to_json}"
    end

    # Validate that query is not empty
    # @param sql [String] SQL query to validate
    # @raise [QueryError] If query is empty
    def validate_query_not_empty(sql)
      raise QueryError, EMPTY_QUERY_ERROR if sql.strip.empty?
    end

    # Reset query builder state
    def reset
      @query_parts.clear
      @variables.clear
    end
  end
end