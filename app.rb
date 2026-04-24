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

# Load controller
require_relative 'app/controllers/localization_controller'

# Create indexes
Country.create_indexes
State.create_indexes
City.create_indexes

# Schedule periodic sync (every 24 hours)
scheduler = Rufus::Scheduler.new
scheduler.every '24h', first_in: '10s' do
  DataSyncService.sync_all
rescue StandardError => e
  puts "[Scheduler] Sync error: #{e.message}"
end

# Main app
class LocalizationApp < LocalizationController
end
