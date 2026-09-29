# == Schema Information
#
# Table name: payroll_entries
#
#  id                        :bigint           not null, primary key
#  user_id                   :bigint           not null
#  worker_name               :string           not null
#  role                      :string
#  payment_type              :string
#  base_rate                 :decimal(12,2)    not null, default(0)
#  quantity_or_hours_completed :decimal(12,2)  not null, default(0)
#  total_paid                :decimal(12,2)    not null, default(0)
#  payment_date              :date             not null
#  status                    :string           not null, default("Pendiente")
#  notes                     :text
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#
class PayrollEntry < ApplicationRecord
  include Audited

  belongs_to :user

  enum :payment_type, {
    "Fijo Mensual" => "Fijo Mensual",
    "Fijo Quincenal" => "Fijo Quincenal",
    "Por Hora" => "Por Hora",
    "Por Obra / Destajo" => "Por Obra / Destajo"
  }, prefix: true

  enum :status, {
    "Pagado" => "Pagado",
    "Pendiente" => "Pendiente"
  }, prefix: true

  validates :worker_name, presence: true
  validates :base_rate, numericality: { greater_than_or_equal_to: 0 }
  validates :quantity_or_hours_completed, numericality: { greater_than_or_equal_to: 0 }
  validates :total_paid, numericality: { greater_than_or_equal_to: 0 }

  scope :recent_first, -> { order(created_at: :desc) }
end
