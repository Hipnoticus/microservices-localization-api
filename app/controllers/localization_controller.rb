# frozen_string_literal: true

require 'sinatra/base'
require 'sinatra/json'

class LocalizationController < Sinatra::Base
  set :show_exceptions, false

  before do
    content_type :json
    headers 'Access-Control-Allow-Origin' => '*',
            'Access-Control-Allow-Methods' => 'GET, OPTIONS',
            'Access-Control-Allow-Headers' => 'Content-Type, Authorization'
  end

  options '*' do
    200
  end

  # GET /countries
  get '/countries' do
    countries = Country.all.order_by(name: :asc).map do |c|
      { code: c.code, code3: c.code3, name: c.name, nativeName: c.native_name,
        phoneCode: c.phone_code, currency: c.currency, region: c.region,
        subregion: c.subregion, flag: c.flag_emoji }
    end
    json countries
  end

  # GET /countries/:code
  get '/countries/:code' do
    country = Country.find_by(code: params[:code].upcase)
    halt 404, json(error: 'Country not found') unless country

    json({ code: country.code, code3: country.code3, name: country.name,
           nativeName: country.native_name, phoneCode: country.phone_code,
           currency: country.currency, region: country.region,
           subregion: country.subregion, flag: country.flag_emoji,
           statesCount: State.where(country_code: country.code).count })
  end

  # GET /countries/:code/states
  get '/countries/:code/states' do
    states = State.where(country_code: params[:code].upcase).order_by(name: :asc).map do |s|
      { code: s.code, name: s.name, countryCode: s.country_code }
    end
    json states
  end

  # GET /states/:country_code/:state_code/cities
  get '/states/:country_code/:state_code/cities' do
    cities = City.where(country_code: params[:country_code].upcase,
                        state_code: params[:state_code].upcase)
                 .order_by(name: :asc).map do |c|
      { name: c.name, stateCode: c.state_code, countryCode: c.country_code }
    end
    json cities
  end

  # GET /health
  get '/health' do
    json({ status: 'UP', service: 'localization-service',
           countries: Country.count, states: State.count, cities: City.count })
  end

  # POST /sync (trigger manual sync)
  post '/sync' do
    Thread.new { DataSyncService.sync_all }
    json({ message: 'Sync started in background' })
  end
end
