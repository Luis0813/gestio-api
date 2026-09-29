class PayrollEntriesController < ApplicationController
  before_action :authenticate_user!

  def index
    payroll_entries = scoped(:payroll_entries).recent_first

    render json: {
      status: { code: 200, message: "Payroll entries retrieved successfully." },
      data: serialize(payroll_entries)
    }, status: :ok
  end

  def show
    payroll_entry = find_scoped(:payroll_entries, params[:id])

    render json: {
      status: { code: 200, message: "Payroll entry retrieved successfully." },
      data: serialize(payroll_entry)
    }, status: :ok
  end

  def create
    payroll_entry = scoped(:payroll_entries).new(payroll_entry_params)

    if payroll_entry.save
      render json: {
        status: { code: 201, message: "Payroll entry created successfully." },
        data: serialize(payroll_entry)
      }, status: :created
    else
      render json: {
        status: { code: 422, message: "Payroll entry couldn't be created. #{payroll_entry.errors.full_messages.to_sentence}" }
      }, status: :unprocessable_entity
    end
  end

  def update
    payroll_entry = find_scoped(:payroll_entries, params[:id])

    if payroll_entry.update(payroll_entry_params)
      render json: {
        status: { code: 200, message: "Payroll entry updated successfully." },
        data: serialize(payroll_entry)
      }, status: :ok
    else
      render json: {
        status: { code: 422, message: "Payroll entry couldn't be updated. #{payroll_entry.errors.full_messages.to_sentence}" }
      }, status: :unprocessable_entity
    end
  end

  def destroy
    payroll_entry = find_scoped(:payroll_entries, params[:id])
    payroll_entry.destroy!

    render json: {
      status: { code: 200, message: "Payroll entry deleted successfully." }
    }, status: :ok
  end

  private

  def payroll_entry_params
    params.require(:payroll_entry).permit(
      :worker_name, :role, :payment_type, :base_rate, :quantity_or_hours_completed,
      :total_paid, :payment_date, :status, :notes
    )
  end
end
