# frozen_string_literal: true

class State
  include Mongoid::Document
  include Mongoid::Timestamps

  field :code, type: String       # UF code (DF, SP, RJ) or state code
  field :name, type: String
  field :country_code, type: String

  belongs_to :country, optional: true
  has_many :cities

  index({ code: 1, country_code: 1 }, { unique: true })
  index({ country_code: 1 })
  index({ name: 1 })

  validates :code, presence: true
  validates :name, presence: true
  validates :country_code, presence: true
end
