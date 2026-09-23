class Users::CurrentUserController < ApplicationController
  before_action :authenticate_user!

  def show
    if current_user.membership_expired?
      current_user.update_column(:active, false)
      render json: {
        status: { code: 403, message: "Tu membresía ha vencido." }
      }, status: :forbidden
    elsif !current_user.active?
      render json: {
        status: { code: 403, message: "Tu cuenta ha sido deshabilitada." }
      }, status: :forbidden
    else
      render json: {
        status: { code: 200, message: "Current user retrieved successfully." },
        data: current_user
      }, status: :ok
    end
  end
end
