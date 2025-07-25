# frozen_string_literal: true

module SurrealDB
  # ActiveRecord-like ORM for SurrealDB
  class Model
    class << self
      attr_accessor :table_name, :primary_key

      def inherited(subclass)
        super
        subclass.table_name = pluralize_class_name(subclass.name)
        subclass.primary_key = 'id'
      end

      # Set custom table name
      def table(name)
        self.table_name = name.to_s
      end

      # Find record by ID
      def find(id)
        result = database_client.select("#{table_name}:#{id}")
        return nil unless successful_result_with_data?(result)
        
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
        query = build_where_query(conditions)
        result = database_client.query(query)
        return [] unless result.success?
        
        map_results_to_models(result.data)
      end

      # Get all records
      def all
        result = database_client.select(table_name)
        return [] unless result.success?
        
        map_results_to_models(result.data)
      end

      # Count records
      def count
        result = database_client.query("SELECT count() FROM #{table_name} GROUP ALL")
        return 0 unless successful_result_with_data?(result)
        
        result.data.first['count'] || 0
      end

      private

      def pluralize_class_name(class_name)
        class_name.downcase + 's'
      end

      def successful_result_with_data?(result)
        result.success? && result.data.any?
      end

      def build_where_query(conditions)
        base_query = "SELECT * FROM #{table_name}"
        return base_query unless conditions
        
        where_clause = case conditions
                      when Hash
                        build_hash_conditions(conditions)
                      when String
                        conditions
                      else
                        return base_query
                      end
        
        "#{base_query} WHERE #{where_clause}"
      end

      def build_hash_conditions(conditions_hash)
        conditions_hash.map { |key, value| "#{key} = '#{value}'" }.join(' AND ')
      end

      def map_results_to_models(data)
        data.map { |record| new(record) }
      end

      def database_client
        @client ||= SurrealDB.connect(url: database_url)
      end

      def database_url
        ENV['SURREALDB_URL'] || 'http://localhost:8000'
      end
    end

    attr_reader :attributes, :id

    def initialize(attributes = {})
      @attributes = normalize_attributes(attributes)
      @id = @attributes['id']
      @persisted = !@id.nil?
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
      
      if setter_method?(method_str)
        handle_setter_method(method_str, args.first)
      elsif attribute_exists?(method_str)
        self[method_str]
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      method_str = method_name.to_s
      setter_method?(method_str) || attribute_exists?(method_str) || super
    end

    # Persistence methods
    def save
      persisted? ? update_record : create_record
    end

    def update(new_attributes)
      assign_attributes(new_attributes)
      save
    end

    def destroy
      return false unless persisted?
      
      result = database_client.delete(record_identifier)
      if result.success?
        mark_as_destroyed
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

    def normalize_attributes(attrs)
      attrs.is_a?(Hash) ? attrs : {}
    end

    def setter_method?(method_str)
      method_str.end_with?('=')
    end

    def attribute_exists?(method_str)
      @attributes.key?(method_str)
    end

    def handle_setter_method(method_str, value)
      attribute_name = method_str.chomp('=')
      self[attribute_name] = value
    end

    def assign_attributes(new_attributes)
      new_attributes.each { |key, value| self[key] = value }
    end

    def record_identifier
      "#{self.class.table_name}:#{@id}"
    end

    def mark_as_destroyed
      @persisted = false
    end

    def create_record
      result = database_client.create(self.class.table_name, @attributes)
      if result.success?
        update_from_database_result(result)
        @persisted = true
      end
      result.success?
    end

    def update_record
      result = database_client.update(record_identifier, @attributes)
      result.success?
    end

    def update_from_database_result(result)
      data = result.data.is_a?(Array) ? result.data.first : result.data
      @id = data['id']
      @attributes['id'] = @id
    end

    def database_client
      self.class.send(:database_client)
    end
  end
end