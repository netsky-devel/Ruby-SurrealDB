# frozen_string_literal: true

module SurrealDB
  # ActiveRecord-like ORM for SurrealDB
  class Model
    class << self
      attr_accessor :table_name, :primary_key

      def inherited(subclass)
        super
        subclass.table_name = subclass.name.downcase + 's'
        subclass.primary_key = 'id'
      end

      # Set custom table name
      def table(name)
        self.table_name = name.to_s
      end

      # Find record by ID
      def find(id)
        result = surrealdb.select("#{table_name}:#{id}")
        return nil unless result.success? && result.data.any?
        
        new(result.data.first)
      end

      # Create new record
      def create(attributes = {})
        record = new(attributes)
        record.save
        record
      end

      # Find all records with conditions
      def where(conditions)
        query = "SELECT * FROM #{table_name}"
        
        if conditions.is_a?(Hash)
          where_clause = conditions.map { |k, v| "#{k} = '#{v}'" }.join(' AND ')
          query += " WHERE #{where_clause}"
        elsif conditions.is_a?(String)
          query += " WHERE #{conditions}"
        end
        
        result = surrealdb.query(query)
        return [] unless result.success?
        
        result.data.map { |record| new(record) }
      end

      # Get all records
      def all
        result = surrealdb.select(table_name)
        return [] unless result.success?
        
        result.data.map { |record| new(record) }
      end

      # Count records
      def count
        result = surrealdb.query("SELECT count() FROM #{table_name} GROUP ALL")
        return 0 unless result.success? && result.data.any?
        
        result.data.first['count'] || 0
      end

      private

      def surrealdb
        @client ||= SurrealDB.connect(url: ENV['SURREALDB_URL'] || 'http://localhost:8000')
      end
    end

    attr_accessor :attributes, :id

    def initialize(attributes = {})
      @attributes = attributes.is_a?(Hash) ? attributes : {}
      @id = @attributes['id']
      @persisted = !!@id
    end

    # Attribute accessors
    def [](key)
      @attributes[key.to_s]
    end

    def []=(key, value)
      @attributes[key.to_s] = value
    end

    # Dynamic attribute methods
    def method_missing(method_name, *args, &block)
      method_str = method_name.to_s
      
      if method_str.end_with?('=')
        attribute_name = method_str.chomp('=')
        self[attribute_name] = args.first
      elsif @attributes.key?(method_str)
        self[method_str]
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      method_str = method_name.to_s
      method_str.end_with?('=') || @attributes.key?(method_str) || super
    end

    # Persistence methods
    def save
      if persisted?
        update_record
      else
        create_record
      end
    end

    def update(attributes)
      attributes.each { |key, value| self[key] = value }
      save
    end

    def destroy
      return false unless persisted?
      
      result = surrealdb.delete("#{self.class.table_name}:#{@id}")
      if result.success?
        @persisted = false
        true
      else
        false
      end
    end

    def persisted?
      @persisted
    end

    def new_record?
      !persisted?
    end

    def to_h
      @attributes.dup
    end

    private

    def create_record
      result = surrealdb.create(self.class.table_name, @attributes)
      if result.success?
        data = result.data.is_a?(Array) ? result.data.first : result.data
        @id = data['id']
        @attributes['id'] = @id
        @persisted = true
      end
      result.success?
    end

    def update_record
      result = surrealdb.update("#{self.class.table_name}:#{@id}", @attributes)
      result.success?
    end

    def surrealdb
      self.class.send(:surrealdb)
    end
  end
end
