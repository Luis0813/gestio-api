# == Schema Information
#
# Table name: products
#
#  id                      :bigint           not null, primary key
#  user_id                 :bigint           not null
#  name                    :string           not null
#  sku                     :string
#  category                :string
#  business_domain         :string
#  stock                   :decimal(12,2)    not null, default(0)
#  min_stock_alert         :decimal(12,2)    not null, default(0)
#  cost_price              :decimal(12,2)    not null, default(0)
#  sale_price              :decimal(12,2)    not null, default(0)
#  unit                    :string
#  custom_attributes       :jsonb            not null, default({})
#  raw_material_recipe     :jsonb            default([])
#  image_url               :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
class Product < ApplicationRecord
  include Audited

  belongs_to :user
  has_many :stock_movements, dependent: :destroy

  enum :business_domain, {
    "ropa" => "ropa",
    "empanadas" => "empanadas",
    "ferreteria" => "ferreteria",
    "custom" => "custom"
  }, prefix: true

  # Only these three are truly required to create a product. Everything else is
  # filled in by #fill_optional_defaults so a spreadsheet (or an API client) can
  # supply just a name and the two prices.
  validates :name, presence: true
  validates :cost_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :sale_price, presence: true, numericality: { greater_than_or_equal_to: 0 }

  validates :stock, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :min_stock_alert, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  before_validation :fill_optional_defaults

  scope :recent_first, -> { order(created_at: :desc) }

  private

  # Fills the non-mandatory columns when they are missing or blank, so the UI
  # never has to deal with nulls and imports can stay minimal.
  def fill_optional_defaults
    self.sku = "PROD-#{SecureRandom.hex(3).upcase}" if sku.blank?
    self.category = "General" if category.blank?
    self.unit = "Unidad" if unit.blank?
    self.stock = 0 if stock.blank?
    self.min_stock_alert = 0 if min_stock_alert.blank?
    self.custom_attributes = {} if custom_attributes.blank?
  end
end
