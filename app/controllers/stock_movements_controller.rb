class StockMovementsController < ApplicationController
  before_action :authenticate_user!

  SALE_TYPE = "Venta"
  DECREASE_TYPES = [ "Venta", "Merma / Pérdida" ].freeze
  INCREASE_TYPES = [ "Compra Insumos", "Ajuste Stock" ].freeze

  def index
    stock_movements = scoped(:stock_movements).recent_first

    render json: {
      status: { code: 200, message: "Stock movements retrieved successfully." },
      data: serialize(stock_movements)
    }, status: :ok
  end

  def show
    stock_movement = find_scoped(:stock_movements, params[:id])

    render json: {
      status: { code: 200, message: "Stock movement retrieved successfully." },
      data: serialize(stock_movement)
    }, status: :ok
  end

  # Creating a movement also mutates the linked product's stock and the linked
  # customer's aggregates. All of that happens inside a single transaction so
  # the request is atomic (the frontend used to do it as three separate calls).
  def create
    movement = nil
    product = nil
    customer = nil

    ActiveRecord::Base.transaction do
      attributes = stock_movement_params.to_h
      product = resolve_product(attributes[:product_id])
      customer = resolve_customer(attributes[:customer_id], attributes[:customer_name])

      movement = scoped(:stock_movements).new(attributes)
      movement.product = product
      movement.customer = customer
      movement.save!

      product = adjust_product_stock(product, movement)
      customer = apply_customer_totals(customer, movement)
    end

    movement.reload

    render json: {
      status: { code: 201, message: "Stock movement created successfully." },
      data: {
        movement: serialize(movement),
        product: serialize(product),
        customer: serialize(customer)
      }
    }, status: :created
  end

  def destroy
    stock_movement = find_scoped(:stock_movements, params[:id])
    stock_movement.destroy!

    render json: {
      status: { code: 200, message: "Stock movement deleted successfully." }
    }, status: :ok
  end

  private

  # Mirrors the semantics the frontend used to apply client side:
  # sales and losses subtract (floored at 0), purchases and adjustments add.
  def adjust_product_stock(product, movement)
    return nil if product.nil?

    new_stock =
      if DECREASE_TYPES.include?(movement.type)
        [ product.stock - movement.quantity, 0 ].max
      elsif INCREASE_TYPES.include?(movement.type)
        product.stock + movement.quantity
      else
        product.stock
      end

    product.update!(stock: new_stock)
    product
  end

  # On a sale the customer's aggregates are bumped. When the client sent a
  # customer_name that matches nothing, a brand new customer is created and
  # linked to the movement.
  def apply_customer_totals(customer, movement)
    return nil unless movement.type == SALE_TYPE

    if customer
      customer.update!(
        total_orders: customer.total_orders + 1,
        total_spent: customer.total_spent + movement.total_amount,
        last_order_date: movement.date
      )
      return customer
    end

    name = movement.customer_name.presence
    return nil if name.nil?

    new_customer = scoped(:customers).create!(
      name: name,
      total_orders: 1,
      total_spent: movement.total_amount,
      last_order_date: movement.date
    )
    movement.update!(customer: new_customer)
    new_customer
  end

  def resolve_product(product_id)
    return nil if product_id.blank?

    scoped(:products).find_by(id: product_id)
  end

  def resolve_customer(customer_id, customer_name)
    if customer_id.present?
      found = scoped(:customers).find_by(id: customer_id)
      return found if found
    end

    return nil if customer_name.blank?

    scoped(:customers).where("LOWER(name) = ?", customer_name.to_s.strip.downcase).first
  end

  def stock_movement_params
    params.require(:stock_movement).permit(
      :product_id, :product_name, :type, :quantity, :unit_price, :total_amount,
      :date, :customer_id, :customer_name, :notes
    )
  end
end
