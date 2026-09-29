class CustomersController < ApplicationController
  before_action :authenticate_user!

  def index
    customers = scoped(:customers).recent_first

    render json: {
      status: { code: 200, message: "Customers retrieved successfully." },
      data: serialize(customers)
    }, status: :ok
  end

  def show
    customer = find_scoped(:customers, params[:id])

    render json: {
      status: { code: 200, message: "Customer retrieved successfully." },
      data: serialize(customer)
    }, status: :ok
  end

  def create
    customer = scoped(:customers).new(customer_params)

    if customer.save
      render json: {
        status: { code: 201, message: "Customer created successfully." },
        data: serialize(customer)
      }, status: :created
    else
      render json: {
        status: { code: 422, message: "Customer couldn't be created. #{customer.errors.full_messages.to_sentence}" }
      }, status: :unprocessable_entity
    end
  end

  def update
    customer = find_scoped(:customers, params[:id])

    if customer.update(customer_params)
      render json: {
        status: { code: 200, message: "Customer updated successfully." },
        data: serialize(customer)
      }, status: :ok
    else
      render json: {
        status: { code: 422, message: "Customer couldn't be updated. #{customer.errors.full_messages.to_sentence}" }
      }, status: :unprocessable_entity
    end
  end

  def destroy
    customer = find_scoped(:customers, params[:id])
    customer.destroy!

    render json: {
      status: { code: 200, message: "Customer deleted successfully." }
    }, status: :ok
  end

  private

  def customer_params
    params.require(:customer).permit(
      :name, :phone, :email, :address, :total_orders, :total_spent, :last_order_date, :notes
    )
  end
end
