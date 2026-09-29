# == Schema Information
#
# Table name: customers
#
#  id              :bigint           not null, primary key
#  user_id         :bigint           not null
#  name            :string           not null
#  phone           :string
#  email           :string
#  address         :string
#  total_orders    :integer          not null, default(0)
#  total_spent     :decimal(12,2)    not null, default(0)
#  last_order_date :date
#  notes           :text
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
class Customer < ApplicationRecord
  include Audited

  belongs_to :user
  has_many :stock_movements, dependent: :destroy

  validates :name, presence: true
  validates :total_orders, numericality: { greater_than_or_equal_to: 0 }
  validates :total_spent, numericality: { greater_than_or_equal_to: 0 }

  scope :recent_first, -> { order(created_at: :desc) }
end
