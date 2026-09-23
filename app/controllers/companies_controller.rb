class CompaniesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!

  def index
    companies = User.where(role: 'company')
                    .order(created_at: :desc)
                    .select(:id, :email, :company_name, :active, :membership_expires_at, :created_at)

    render json: {
      status: { code: 200, message: 'Companies retrieved successfully.' },
      data: companies
    }, status: :ok
  end

  def update
    company = User.where(role: 'company').find(params[:id])

    if company.update(company_params)
      render json: {
        status: { code: 200, message: 'Company updated successfully.' },
        data: company
      }, status: :ok
    else
      render json: {
        status: { code: 422, message: "Company couldn't be updated. #{company.errors.full_messages.to_sentence}" }
      }, status: :unprocessable_entity
    end
  end

  private

  def ensure_admin!
    unless current_user&.role == 'admin'
      render json: {
        status: { code: 403, message: 'Access denied. Admin only.' }
      }, status: :forbidden
    end
  end

  def company_params
    params.require(:user).permit(:active, :membership_expires_at)
  end
end
