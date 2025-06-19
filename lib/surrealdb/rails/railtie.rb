# frozen_string_literal: true

require 'rails/railtie'

module SurrealDB
  module Rails
    class Railtie < ::Rails::Railtie
      config.surrealdb = ActiveSupport::OrderedOptions.new

      initializer 'surrealdb.configure' do |app|
        SurrealDB::Rails::Integration.configure do |config|
          # Set environment-specific defaults
          case ::Rails.env
          when 'development'
            config.namespace = 'development'
            config.database = app.class.name.underscore
          when 'test'
            config.namespace = 'test'
            config.database = "#{app.class.name.underscore}_test"
          when 'production'
            config.namespace = 'production'
            config.database = app.class.name.underscore
          end

          # Override with app config
          app.config.surrealdb.each do |key, value|
            config.send("#{key}=", value)
          end
        end
      end

      initializer 'surrealdb.controller_helpers' do
        ActiveSupport.on_load(:action_controller) do
          include SurrealDB::Rails::ControllerHelpers
        end
      end
    end
  end
end 