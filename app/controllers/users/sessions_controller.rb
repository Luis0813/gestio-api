class Users::SessionsController < Devise::SessionsController
  include RackSessionFix
  respond_to :json

  def create
    self.resource = warden.authenticate(auth_options)

    if resource
      if resource.membership_expired?
        resource.update_column(:active, false)
        render json: {
          status: { code: 403, message: "Tu membresía ha vencido. Comunícate con soporte para renovar tu acceso." }
        }, status: :forbidden
        return
      end

      sign_in(resource_name, resource)
      respond_with resource, location: after_sign_in_path_for(resource)
    else
      email = params.dig(:user, :email)
      user = resource_class.find_by(email: email) if email

      if user && (!user.active? || user.membership_expired?)
        user.update_column(:active, false) if user.membership_expired?
        render json: {
          status: { code: 403, message: "Tu membresía ha vencido o tu cuenta ha sido deshabilitada." }
        }, status: :forbidden
      else
        render json: {
          status: { code: 401, message: "Email o contraseña incorrectos." }
        }, status: :unauthorized
      end
    end
  end

  private

  def respond_with(resource, _opts = {})
    if resource.active? && !resource.membership_expired?
      render json: {
        status: { code: 200, message: "Logged in successfully." },
        data: resource
      }, status: :ok
    else
      resource.update_column(:active, false) if resource.membership_expired?
      render json: {
        status: { code: 403, message: "Tu membresía ha vencido o tu cuenta está deshabilitada." }
      }, status: :forbidden
    end
  end

  def respond_to_on_destroy(*)
    if current_user
      render json: {
        status: 200,
        message: "Logged out successfully."
      }, status: :ok
    else
      render json: {
        status: 401,
        message: "Couldn't find an active session."
      }, status: :unauthorized
    end
  end
end
