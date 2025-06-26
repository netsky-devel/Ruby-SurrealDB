require 'bundler/setup'
require 'rspec'
require 'webmock/rspec'
require 'surrealdb'

# Test environment configuration module
module TestEnvironmentConfig
  # Configure WebMock to disable external HTTP connections
  # Allow localhost connections for local testing
  def self.setup_webmock
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  # Configure RSpec with best practices for test reliability
  def self.setup_rspec
    RSpec.configure do |config|
      configure_test_persistence(config)
      configure_rspec_behavior(config)
      configure_test_execution(config)
      configure_cleanup_hooks(config)
    end
  end

  private

  # Configure test status persistence for failure tracking
  def self.configure_test_persistence(config)
    config.example_status_persistence_file_path = '.rspec_status'
  end

  # Configure RSpec behavior and syntax preferences
  def self.configure_rspec_behavior(config)
    # Disable RSpec exposing methods globally on Module and main
    config.disable_monkey_patching!
    
    config.expect_with :rspec do |expectation_config|
      expectation_config.syntax = :expect
    end
  end

  # Configure test execution order and randomization
  def self.configure_test_execution(config)
    # Run specs in random order to surface order dependencies
    config.order = :random
    # Seed global randomization using the --seed CLI option
    Kernel.srand config.seed
  end

  # Configure cleanup hooks to run after each test
  def self.configure_cleanup_hooks(config)
    config.after(:each) do
      WebMock.reset!
    end
  end
end

# Initialize test environment
TestEnvironmentConfig.setup_webmock
TestEnvironmentConfig.setup_rspec