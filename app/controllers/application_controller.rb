class ApplicationController < ActionController::API
  include ApiSerializer
  include TenantScoped

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActionController::ParameterMissing, with: :render_parameter_missing
  rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid

  private

  def render_record_invalid(exception)
    render json: {
      status: { code: 422, message: exception.message }
    }, status: :unprocessable_entity
  end

  def render_not_found
    render json: {
      status: { code: 404, message: "Resource not found." }
    }, status: :not_found
  end

  def render_parameter_missing(exception)
    render json: {
      status: { code: 400, message: "Invalid request. #{exception.message}" }
    }, status: :bad_request
  end
end
