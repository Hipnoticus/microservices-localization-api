# frozen_string_literal: true

require 'httparty'
require 'json'

# Fetches configuration from Spring Cloud Config Server.
# Follows the same pattern as other non-Java services in the ecosystem.
class ConfigClient
  APP_NAME = 'localization-service'
  PROFILE = 'default'

  def self.load
    config_uri = ENV.fetch('HIPNOTICUS_CONFIG_CLIENT_SERVER_CONFIG_URI_AUTHENTICATED', nil)

    unless config_uri
      puts '[ConfigClient] No Config Server URI configured — using environment defaults'
      return default_config
    end

    # Parse credentials from URL: http://user:pass@host:port
    username = 'configUser'
    password = 'configPassword'
    base_url = config_uri

    if config_uri.include?('@')
      match = config_uri.match(%r{(https?)://([^:]+):([^@]+)@(.+)})
      if match
        username = match[2]
        password = match[3]
        base_url = "#{match[1]}://#{match[4]}"
      end
    end

    url = "#{base_url}/#{APP_NAME}/#{PROFILE}"
    puts "[ConfigClient] Fetching config from #{url}"

    response = HTTParty.get(
      url,
      basic_auth: { username: username, password: password },
      headers: { 'Accept' => 'application/json' },
      timeout: 10
    )

    if response.code == 200
      config = parse_config(response.parsed_response)
      puts "[ConfigClient] Config loaded — port: #{config[:server_port]}, app: #{config[:application_name]}"
      config
    else
      puts "[ConfigClient] Config Server returned #{response.code} — using defaults"
      default_config
    end
  rescue StandardError => e
    puts "[ConfigClient] Failed to load config: #{e.message} — using defaults"
    default_config
  end

  def self.parse_config(response)
    # Spring Cloud Config returns: { name, profiles, propertySources: [{ source: { ... } }] }
    sources = response.dig('propertySources') || []
    source = sources.first&.dig('source') || {}

    {
      application_name: source['spring.application.name'] || APP_NAME,
      server_port: (source['server.port'] || ENV.fetch('PORT', '4001')).to_i,
      eureka_region: source.dig('eureka.client.region') || 'default',
      eureka_fetch_interval: (source.dig('eureka.client.registryFetchIntervalSeconds') || 5).to_i,
      raw: source
    }
  end

  def self.default_config
    {
      application_name: APP_NAME,
      server_port: ENV.fetch('PORT', '4001').to_i,
      eureka_region: 'default',
      eureka_fetch_interval: 5,
      raw: {}
    }
  end
end
