# frozen_string_literal: true

require 'httparty'
require 'json'

# Syncs country/state/city data from public APIs
# Sources:
#   - Countries: REST Countries API (https://restcountries.com)
#   - Brazilian states/cities: IBGE API (https://servicodados.ibge.gov.br)
#   - International states/cities: CountriesNow API
class DataSyncService
  RESTCOUNTRIES_URL = 'https://restcountries.com/v3.1/all?fields=name,cca2,cca3,idd,currencies,region,subregion,flag'
  IBGE_STATES_URL = 'https://servicodados.ibge.gov.br/api/v1/localidades/estados?orderBy=nome'
  IBGE_CITIES_URL = 'https://servicodados.ibge.gov.br/api/v1/localidades/estados/%s/municipios?orderBy=nome'
  COUNTRIESNOW_STATES_URL = 'https://countriesnow.space/api/v0.1/countries/states'

  def self.sync_all
    sync_countries
    sync_brazilian_states_and_cities
    sync_international_states
    puts "[DataSync] Sync complete at #{Time.now}"
  end

  def self.sync_countries
    puts '[DataSync] Syncing countries from REST Countries API...'
    response = HTTParty.get(RESTCOUNTRIES_URL, timeout: 30)
    return puts '[DataSync] Failed to fetch countries' unless response.success?

    data = JSON.parse(response.body)
    count = 0

    data.each do |c|
      code = c['cca2']
      next unless code && code.length == 2

      phone_code = c.dig('idd', 'root').to_s + (c.dig('idd', 'suffixes')&.first || '')
      currency = c['currencies']&.keys&.first || ''

      Country.find_or_initialize_by(code: code).tap do |country|
        country.code3 = c['cca3']
        country.name = c.dig('name', 'common') || ''
        country.native_name = c.dig('name', 'nativeName')&.values&.first&.dig('common') || country.name
        country.phone_code = phone_code
        country.currency = currency
        country.region = c['region'] || ''
        country.subregion = c['subregion'] || ''
        country.flag_emoji = c['flag'] || ''
        country.save!
        count += 1
      end
    end

    puts "[DataSync] #{count} countries synced"
  end

  def self.sync_brazilian_states_and_cities
    puts '[DataSync] Syncing Brazilian states and cities from IBGE...'
    brazil = Country.find_by(code: 'BR')
    return puts '[DataSync] Brazil not found in countries' unless brazil

    # States
    response = HTTParty.get(IBGE_STATES_URL, timeout: 30)
    return puts '[DataSync] Failed to fetch IBGE states' unless response.success?

    states = JSON.parse(response.body)
    states.each do |s|
      State.find_or_initialize_by(code: s['sigla'], country_code: 'BR').tap do |state|
        state.name = s['nome']
        state.country = brazil
        state.save!
      end

      # Cities for this state
      cities_response = HTTParty.get(format(IBGE_CITIES_URL, s['id']), timeout: 30)
      next unless cities_response.success?

      cities = JSON.parse(cities_response.body)
      state_record = State.find_by(code: s['sigla'], country_code: 'BR')

      cities.each do |c|
        City.find_or_initialize_by(name: c['nome'], state_code: s['sigla'], country_code: 'BR').tap do |city|
          city.state = state_record
          city.save!
        end
      end

      puts "[DataSync] BR/#{s['sigla']}: #{cities.length} cities"
    end

    puts "[DataSync] Brazilian sync complete: #{State.where(country_code: 'BR').count} states, #{City.where(country_code: 'BR').count} cities"
  end

  # Sync states for major countries via CountriesNow API
  # Skips Brazil (already handled by IBGE with cities)
  PRIORITY_COUNTRIES = %w[US PT AR UY PY CL CO MX PE VE EC BO DE FR ES IT GB CA AU JP].freeze

  def self.sync_international_states
    puts '[DataSync] Syncing international states from CountriesNow API...'

    response = HTTParty.post(COUNTRIESNOW_STATES_URL, timeout: 60)
    return puts '[DataSync] Failed to fetch CountriesNow states' unless response.success?

    data = JSON.parse(response.body)
    return puts '[DataSync] CountriesNow returned error' if data['error']

    entries = data['data'] || []
    synced = 0

    entries.each do |entry|
      iso2 = entry['iso2']
      next unless iso2 && iso2.length == 2
      next if iso2 == 'BR' # Brazil handled by IBGE

      country = Country.find_by(code: iso2)
      next unless country

      states_data = entry['states'] || []
      next if states_data.empty?

      states_data.each do |s|
        code = s['state_code'] || s['name']&.slice(0, 5)&.upcase
        next unless code && s['name']

        State.find_or_initialize_by(code: code, country_code: iso2).tap do |state|
          state.name = s['name']
          state.country = country
          state.save!
        end
      end

      synced += 1
    end

    puts "[DataSync] International states synced for #{synced} countries (#{State.where(:country_code.ne => 'BR').count} total non-BR states)"
  end
end
