# frozen_string_literal: true

class City
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :state_code, type: String
  field :country_code, type: String

  belongs_to :state, optional: true

  index({ state_code: 1, country_code: 1 })
  index({ name: 1 })

  validates :name, presence: true
  validates :state_code, presence: true
  validates :country_code, presence: true
end
