require "test_helper"

class ApiFlowTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(
      email: "admin_test@gestio.com",
      password: "password123",
      role: "admin",
      active: true
    )

    @company_user = User.create!(
      email: "company_test@gestio.com",
      password: "password123",
      role: "company",
      company_name: "Empresa Prueba",
      active: true,
      membership_expires_at: 1.month.from_now
    )

    @expired_user = User.create!(
      email: "expired_company@gestio.com",
      password: "password123",
      role: "company",
      company_name: "Empresa Vencida",
      active: true,
      membership_expires_at: 2.days.ago
    )

    @disabled_user = User.create!(
      email: "disabled_company@gestio.com",
      password: "password123",
      role: "company",
      company_name: "Empresa Deshabilitada",
      active: false,
      membership_expires_at: 1.month.from_now
    )
  end

  # Normal flows
  test "user can signup as company user" do
    post "/signup", params: {
      user: {
        email: "new_company@gestio.com",
        password: "password123",
        password_confirmation: "password123",
        role: "company",
        company_name: "Ferreteria Don Pedro"
      }
    }, as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "new_company@gestio.com", json["data"]["email"]
    assert_not_nil response.headers["Authorization"]
  end

  test "user can login and fetch current user profile" do
    post "/login", params: {
      user: {
        email: "company_test@gestio.com",
        password: "password123"
      }
    }, as: :json

    assert_response :success
    token = response.headers["Authorization"]
    assert_not_nil token

    get "/me", headers: { "Authorization" => token }, as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "company_test@gestio.com", json["data"]["email"]
  end

  # Edge Case 1: Invalid Token / No Token
  test "rejects request with missing or invalid token on /me" do
    get "/me", headers: { "Authorization" => "Bearer invalid_token_123" }, as: :json
    assert_response :unauthorized
  end

  # Edge Case 2: Role-based permissions
  test "admin can list all companies" do
    post "/login", params: {
      user: {
        email: "admin_test@gestio.com",
        password: "password123"
      }
    }, as: :json

    token = response.headers["Authorization"]

    get "/companies", headers: { "Authorization" => token }, as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert json["data"].is_a?(Array)
    assert json["data"].any? { |c| c["email"] == "company_test@gestio.com" }
  end

  test "non-admin cannot access companies list" do
    post "/login", params: {
      user: {
        email: "company_test@gestio.com",
        password: "password123"
      }
    }, as: :json

    token = response.headers["Authorization"]

    get "/companies", headers: { "Authorization" => token }, as: :json
    assert_response :forbidden
  end

  # Edge Case 3: Expired Membership login block
  test "user with expired membership is blocked from login" do
    post "/login", params: {
      user: {
        email: "expired_company@gestio.com",
        password: "password123"
      }
    }, as: :json

    assert_response :unauthorized
  end

  # Edge Case 4: Disabled Account login block
  test "user with active=false is blocked from login" do
    post "/login", params: {
      user: {
        email: "disabled_company@gestio.com",
        password: "password123"
      }
    }, as: :json

    assert_response :unauthorized
  end

  # Edge Case 5: Wrong Password / Non-existent User
  test "rejects login with wrong password" do
    post "/login", params: {
      user: {
        email: "company_test@gestio.com",
        password: "wrongpassword"
      }
    }, as: :json

    assert_response :unauthorized
  end

  test "rejects login for non-existent email" do
    post "/login", params: {
      user: {
        email: "nonexistent@gestio.com",
        password: "password123"
      }
    }, as: :json

    assert_response :unauthorized
  end

  # Edge Case 6: Signup Validations
  test "rejects signup for company user without company_name" do
    post "/signup", params: {
      user: {
        email: "nocompanyname@gestio.com",
        password: "password123",
        password_confirmation: "password123",
        role: "company"
        # company_name omitted
      }
    }, as: :json

    assert_response :unprocessable_entity
  end

  test "rejects duplicate email signup" do
    post "/signup", params: {
      user: {
        email: "company_test@gestio.com",
        password: "password123",
        password_confirmation: "password123",
        role: "company",
        company_name: "Otra Empresa"
      }
    }, as: :json

    assert_response :unprocessable_entity
  end

  # Edge Case 7: Token revocation upon logout
  test "token is revoked after logout" do
    post "/login", params: {
      user: {
        email: "company_test@gestio.com",
        password: "password123"
      }
    }, as: :json

    token = response.headers["Authorization"]

    delete "/logout", headers: { "Authorization" => token }, as: :json
    assert_response :success

    # Attempting to use revoked token should be unauthorized
    get "/me", headers: { "Authorization" => token }, as: :json
    assert_response :unauthorized
  end

  # Edge Case 8: Admin updating company status & renewing membership
  test "admin can update company active status and extend membership" do
    post "/login", params: {
      user: {
        email: "admin_test@gestio.com",
        password: "password123"
      }
    }, as: :json

    token = response.headers["Authorization"]
    new_exp = 2.months.from_now.iso8601

    patch "/companies/#{@company_user.id}",
      params: {
        user: {
          active: false,
          membership_expires_at: new_exp
        }
      },
      headers: { "Authorization" => token },
      as: :json

    assert_response :success
    @company_user.reload
    assert_equal false, @company_user.active
  end
end
