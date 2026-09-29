class RawMaterialsController < ApplicationController
  before_action :authenticate_user!

  def index
    raw_materials = scoped(:raw_materials).recent_first

    render json: {
      status: { code: 200, message: "Raw materials retrieved successfully." },
      data: serialize(raw_materials)
    }, status: :ok
  end

  def show
    raw_material = find_scoped(:raw_materials, params[:id])

    render json: {
      status: { code: 200, message: "Raw material retrieved successfully." },
      data: serialize(raw_material)
    }, status: :ok
  end

  def create
    raw_material = scoped(:raw_materials).new(raw_material_params)

    if raw_material.save
      render json: {
        status: { code: 201, message: "Raw material created successfully." },
        data: serialize(raw_material)
      }, status: :created
    else
      render json: {
        status: { code: 422, message: "Raw material couldn't be created. #{raw_material.errors.full_messages.to_sentence}" }
      }, status: :unprocessable_entity
    end
  end

  def update
    raw_material = find_scoped(:raw_materials, params[:id])

    if raw_material.update(raw_material_params)
      render json: {
        status: { code: 200, message: "Raw material updated successfully." },
        data: serialize(raw_material)
      }, status: :ok
    else
      render json: {
        status: { code: 422, message: "Raw material couldn't be updated. #{raw_material.errors.full_messages.to_sentence}" }
      }, status: :unprocessable_entity
    end
  end

  def destroy
    raw_material = find_scoped(:raw_materials, params[:id])
    raw_material.destroy!

    render json: {
      status: { code: 200, message: "Raw material deleted successfully." }
    }, status: :ok
  end

  private

  def raw_material_params
    params.require(:raw_material).permit(
      :name, :unit, :current_stock, :cost_per_unit, :supplier, :min_stock_alert, :last_restock_date
    )
  end
end
