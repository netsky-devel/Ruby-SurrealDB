# frozen_string_literal: true

require 'rails/railtie'

module SurrealDB
  module Rails
    class Railtie < ::Rails::Railtie
      config.surrealdb = ActiveSupport::OrderedOptions.new

      initializer 'surrealdb.configure' do |app|
        SurrealDB::Rails::Integration.configure do |config|
          configure_environment_defaults(config, app)
          apply_application_config_overrides(config, app)
        end
      end

      initializer 'surrealdb.controller_helpers' do
        ActiveSupport.on_load(:action_controller) do
          include SurrealDB::Rails::ControllerHelpers
        end
      end

      private

      # Configures database namespace and name based on Rails environment
      def self.configure_environment_defaults(config, app)
        environment_config = build_environment_config(app)
        config.namespace = environment_config[:namespace]
        config.database = environment_config[:database]
      end

      # Applies configuration overrides from application config
      def self.apply_application_config_overrides(config, app)
        app.config.surrealdb.each do |key, value|
          config.send("#{key}=", value)
        end
      end

      # Builds environment-specific configuration hash
      def self.build_environment_config(app)
        base_database_name = app.class.name.underscore
        
        case ::Rails.env
        when 'development'
          { namespace: 'development', database: base_database_name }
        when 'test'
          { namespace: 'test', database: "#{base_database_name}_test" }
        when 'production'
          { namespace: 'production', database: base_database_name }
        else
          { namespace: ::Rails.env, database: base_database_name }
        end
      end
    end
  end
end