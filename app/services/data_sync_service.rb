# frozen_string_literal: true

require 'httparty'
require 'json'

# Syncs country/state/city data from public APIs
# Sources:
#   - Countries: REST Countries API (https://restcountries.com)
#   - Brazilian states/cities: IBGE API (https://servicodados.ibge.gov.br)
#   - International states: dr5hn/countries-states-cities-database (GitHub)
class DataSyncService
  RESTCOUNTRIES_URL = 'https://restcountries.com/v3.1/all?fields=name,cca2,cca3,idd,currencies,region,subregion,flag'
  IBGE_STATES_URL = 'https://servicodados.ibge.gov.br/api/v1/localidades/estados?orderBy=nome'
  IBGE_CITIES_URL = 'https://servicodados.ibge.gov.br/api/v1/localidades/estados/%s/municipios?orderBy=nome'
  # Comprehensive states JSON from dr5hn GitHub (reliable, updated regularly)
  STATES_JSON_URL = 'https://raw.githubusercontent.com/dr5hn/countries-states-cities-database/master/json/states.json'

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

    response = HTTParty.get(IBGE_STATES_URL, timeout: 30)
    return puts '[DataSync] Failed to fetch IBGE states' unless response.success?

    states = JSON.parse(response.body)
    states.each do |s|
      State.find_or_initialize_by(code: s['sigla'], country_code: 'BR').tap do |state|
        state.name = s['nome']
        state.country = brazil
        state.save!
      end

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

  def self.sync_international_states
    puts '[DataSync] Syncing international states from dr5hn database...'

    response = HTTParty.get(STATES_JSON_URL, timeout: 60)
    unless response.success?
      puts '[DataSync] Failed to fetch states JSON, skipping international sync'
      return
    end

    all_states = JSON.parse(response.body)
    synced_countries = 0

    # Group by country code
    by_country = all_states.group_by { |s| s['country_code'] }

    by_country.each do |iso2, states_data|
      next unless iso2 && iso2.length == 2
      next if iso2 == 'BR' # Brazil handled by IBGE

      country = Country.find_by(code: iso2)
      next unless country

      states_data.each do |s|
        code = s['state_code'] || s['iso2'] || s['name']&.slice(0, 8)&.upcase
        next unless code && s['name']

        begin
          State.find_or_initialize_by(code: code, country_code: iso2).tap do |state|
            state.name = s['name']
            state.country = country
            state.save!
          end
        rescue Mongo::Error::OperationFailure
          # Skip duplicates silently
        end
      end

      synced_countries += 1
    end

    total_intl = State.where(:country_code.ne => 'BR').count
    puts "[DataSync] International states synced for #{synced_countries} countries (#{total_intl} non-BR states)"
  rescue StandardError => e
    puts "[DataSync] International sync error: #{e.message}"
  end
end
