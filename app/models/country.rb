# frozen_string_literal: true

class Country
  include Mongoid::Document
  include Mongoid::Timestamps

  field :code, type: String       # ISO 3166-1 alpha-2 (BR, US, PT)
  field :code3, type: String      # ISO 3166-1 alpha-3 (BRA, USA, PRT)
  field :name, type: String       # English name
  field :native_name, type: String
  field :phone_code, type: String # +55, +1, +351
  field :currency, type: String   # BRL, USD, EUR
  field :region, type: String     # Americas, Europe, etc.
  field :subregion, type: String  # South America, etc.
  field :flag_emoji, type: String

  has_many :states

  index({ code: 1 }, { unique: true })
  index({ name: 1 })

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
end
