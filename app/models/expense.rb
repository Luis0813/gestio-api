# == Schema Information
#
# Table name: expenses
#
#  id          :bigint           not null, primary key
#  user_id     :bigint           not null
#  description :string           not null
#  category    :string
#  amount      :decimal(12,2)    not null, default(0)
#  date        :date             not null
#  periodicity :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class Expense < ApplicationRecord
  include Audited

  belongs_to :user

  enum :category, {
    "Alquiler" => "Alquiler",
    "Servicios" => "Servicios",
    "Mantenimiento" => "Mantenimiento",
    "Marketing" => "Marketing",
    "Herramientas" => "Herramientas",
    "Impuestos" => "Impuestos",
    "Otros" => "Otros"
  }, prefix: true

  enum :periodicity, {
    "Único" => "Único",
    "Semanal" => "Semanal",
    "Quincenal" => "Quincenal",
    "Mensual" => "Mensual"
  }, prefix: true

  validates :description, presence: true
  validates :amount, numericality: { greater_than_or_equal_to: 0 }

  scope :recent_first, -> { order(created_at: :desc) }
end
