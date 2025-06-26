module SurrealDB
  # Represents the result of a SurrealDB query operation
  # Provides convenient methods to access and manipulate query results
  class Result
    include Enumerable

    attr_reader :data, :execution_time, :status

    # Initialize result with response data
    # @param response [Hash, Array, Object] Raw response from SurrealDB
    def initialize(response)
      @response_parser = ResponseParser.new
      parsed_data = @response_parser.parse(response)
      
      @data = parsed_data[:data]
      @execution_time = parsed_data[:time]
      @status = parsed_data[:status]
    end

    # Check if the query was successful
    # @return [Boolean] true if successful, false otherwise
    def successful?
      @status == 'OK'
    end

    # Check if the query failed
    # @return [Boolean] true if failed, false otherwise
    def failed?
      !successful?
    end

    # Get the first result
    # @return [Hash, nil] the first result or nil if empty
    def first_result
      return nil if results_empty?
      normalized_data.first
    end

    # Get all results as array
    # @return [Array] array of results
    def all_results
      normalized_data
    end

    # Check if results are empty
    # @return [Boolean] true if empty, false otherwise
    def empty?
      results_empty?
    end

    # Get the number of results
    # @return [Integer] number of results
    def results_count
      normalized_data.length
    end

    alias_method :size, :results_count
    alias_method :length, :results_count
    alias_method :count, :results_count

    # Convert to array
    # @return [Array] array representation of results
    def to_a
      all_results
    end

    # Convert to hash (for single results)
    # @return [Hash] hash representation of the first result
    def to_h
      first_result || {}
    end

    # Iterate over results (Enumerable interface)
    # @yield [Object] each result
    # @return [Enumerator] if no block given
    def each(&block)
      return enum_for(:each) unless block_given?
      all_results.each(&block)
    end

    private

    # Check if data is nil or empty
    # @return [Boolean]
    def results_empty?
      @data.nil? || (@data.respond_to?(:empty?) && @data.empty?)
    end

    # Normalize data to always return an array
    # @return [Array]
    def normalized_data
      return [] if @data.nil?
      @data.is_a?(Array) ? @data : [@data]
    end

    # Internal class responsible for parsing different response formats
    class ResponseParser
      DEFAULT_STATUS = 'OK'.freeze

      # Parse response into standardized format
      # @param response [Hash, Array, Object] Raw response
      # @return [Hash] Parsed data with :data, :time, :status keys
      def parse(response)
        case response
        when Hash
          parse_hash_response(response)
        when Array
          parse_array_response(response)
        else
          parse_generic_response(response)
        end
      end

      private

      # Parse hash-formatted response (standard SurrealDB format)
      # @param response [Hash]
      # @return [Hash]
      def parse_hash_response(response)
        {
          data: response['result'],
          time: response['time'],
          status: response['status']
        }
      end

      # Parse array-formatted response
      # @param response [Array]
      # @return [Hash]
      def parse_array_response(response)
        {
          data: response,
          time: nil,
          status: DEFAULT_STATUS
        }
      end

      # Parse generic response format
      # @param response [Object]
      # @return [Hash]
      def parse_generic_response(response)
        {
          data: response,
          time: nil,
          status: DEFAULT_STATUS
        }
      end
    end
  end
end