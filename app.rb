# frozen_string_literal: true

require 'mongoid'
require 'rufus-scheduler'

# Load Mongoid config
env = ENV['RACK_ENV'] || ENV['HIPNOTICUS_ENV'] || 'development'
Mongoid.load!(File.join(__dir__, 'config', 'mongoid.yml'), env)

# Load models
require_relative 'app/models/country'
require_relative 'app/models/state'
require_relative 'app/models/city'

# Load services
require_relative 'app/services/data_sync_service'
require_relative 'app/services/eureka_client'

# Load controller
require_relative 'app/controllers/localization_controller'

# Create indexes
Country.create_indexes
State.create_indexes
City.create_indexes

# Register with Eureka (Spring Cloud service discovery)
Thread.new do
  sleep 5 # Wait for Puma to start
  EurekaClient.register
end

# Schedule periodic tasks
scheduler = Rufus::Scheduler.new

# Data sync every 24 hours
scheduler.every '24h', first_in: '10s' do
  DataSyncService.sync_all
rescue StandardError => e
  puts "[Scheduler] Sync error: #{e.message}"
end

# Eureka heartbeat every 30 seconds
scheduler.every '30s', first_in: '15s' do
  EurekaClient.heartbeat
rescue StandardError => e
  puts "[Scheduler] Eureka heartbeat error: #{e.message}"
end

# Graceful shutdown — deregister from Eureka
at_exit do
  EurekaClient.deregister
end

# Main app
class LocalizationApp < LocalizationController
end
