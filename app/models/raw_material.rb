# == Schema Information
#
# Table name: raw_materials
#
#  id                 :bigint           not null, primary key
#  user_id            :bigint           not null
#  name               :string           not null
#  unit               :string
#  current_stock      :decimal(12,2)    not null, default(0)
#  cost_per_unit      :decimal(12,2)    not null, default(0)
#  supplier           :string
#  min_stock_alert    :decimal(12,2)    not null, default(0)
#  last_restock_date  :date
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
class RawMaterial < ApplicationRecord
  include Audited

  belongs_to :user

  validates :name, presence: true
  validates :current_stock, numericality: { greater_than_or_equal_to: 0 }
  validates :cost_per_unit, numericality: { greater_than_or_equal_to: 0 }
  validates :min_stock_alert, numericality: { greater_than_or_equal_to: 0 }

  scope :recent_first, -> { order(created_at: :desc) }
end
