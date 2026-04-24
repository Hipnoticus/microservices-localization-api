# frozen_string_literal: true

require 'rack/test'
require 'rspec'
require 'webmock/rspec'

ENV['RACK_ENV'] = 'test'

require_relative '../app'

RSpec.describe LocalizationController do
  include Rack::Test::Methods

  def app
    LocalizationApp
  end

  before(:each) do
    Country.delete_all
    State.delete_all
    City.delete_all
  end

  describe 'GET /health' do
    it 'returns UP status' do
      get '/health'
      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['status']).to eq('UP')
      expect(body['service']).to eq('localization-service')
    end
  end

  describe 'GET /countries' do
    it 'returns empty array when no countries' do
      get '/countries'
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)).to eq([])
    end

    it 'returns countries sorted by name' do
      Country.create!(code: 'BR', name: 'Brazil', native_name: 'Brasil')
      Country.create!(code: 'US', name: 'United States', native_name: 'United States')
      Country.create!(code: 'AR', name: 'Argentina', native_name: 'Argentina')

      get '/countries'
      body = JSON.parse(last_response.body)
      expect(body.length).to eq(3)
      expect(body.map { |c| c['code'] }).to eq(%w[AR BR US])
    end
  end

  describe 'GET /countries/:code/states' do
    it 'returns states for a country' do
      Country.create!(code: 'BR', name: 'Brazil')
      State.create!(code: 'DF', name: 'Distrito Federal', country_code: 'BR')
      State.create!(code: 'SP', name: 'São Paulo', country_code: 'BR')

      get '/countries/BR/states'
      body = JSON.parse(last_response.body)
      expect(body.length).to eq(2)
      expect(body.first['code']).to eq('DF')
    end
  end

  describe 'GET /states/:country_code/:state_code/cities' do
    it 'returns cities for a state' do
      Country.create!(code: 'BR', name: 'Brazil')
      state = State.create!(code: 'DF', name: 'Distrito Federal', country_code: 'BR')
      City.create!(name: 'Brasília', state_code: 'DF', country_code: 'BR', state: state)
      City.create!(name: 'Taguatinga', state_code: 'DF', country_code: 'BR', state: state)

      get '/states/BR/DF/cities'
      body = JSON.parse(last_response.body)
      expect(body.length).to eq(2)
      expect(body.first['name']).to eq('Brasília')
    end
  end
end
