# == Schema Information
#
# Table name: stock_movements
#
#  id             :bigint           not null, primary key
#  user_id        :bigint           not null
#  product_id     :bigint
#  customer_id    :bigint
#  product_name   :string
#  type           :string           not null
#  quantity       :decimal(12,2)    not null
#  unit_price     :decimal(12,2)    not null, default(0)
#  total_amount   :decimal(12,2)    not null, default(0)
#  date           :date             not null
#  customer_name  :string
#  notes          :text
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# The `type` column is intentionally NOT used for Single Table Inheritance:
# it is a plain string discriminator (Venta / Compra Insumos / Ajuste Stock /
# Merma / Pérdida) that mirrors the frontend. STI is disabled by setting
# `inheritance_column` to nil so Rails does not try to resolve a subclass
# (e.g. "Venta") from the `type` value on initialize/find. The `enum :type`
# declaration (hash form, prefix: :movement) owns the reader/writer methods.
class StockMovement < ApplicationRecord
  include Audited

  belongs_to :user
  belongs_to :product, optional: true
  belongs_to :customer, optional: true

  self.inheritance_column = nil

  enum :type, {
    "Venta" => "Venta",
    "Compra Insumos" => "Compra Insumos",
    "Ajuste Stock" => "Ajuste Stock",
    "Merma / Pérdida" => "Merma / Pérdida"
  }, prefix: :movement

  validates :type, presence: true
  validates :quantity, numericality: { greater_than_or_equal_to: 0 }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }
  validates :total_amount, numericality: { greater_than_or_equal_to: 0 }

  scope :recent_first, -> { order(created_at: :desc) }
end
