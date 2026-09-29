# Wipes every business collection owned by the current user.
# Replaces the frontend `resetDemoData` helper. Stock movements are deleted
# first because they hold foreign keys to products and customers.
class DataController < ApplicationController
  before_action :authenticate_user!

  def destroy
    ActiveRecord::Base.transaction do
      current_user.stock_movements.destroy_all
      current_user.products.destroy_all
      current_user.raw_materials.destroy_all
      current_user.expenses.destroy_all
      current_user.payroll_entries.destroy_all
      current_user.customers.destroy_all
    end

    render json: {
      status: { code: 200, message: "All business data deleted successfully." }
    }, status: :ok
  end
end
