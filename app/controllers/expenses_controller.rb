class ExpensesController < ApplicationController
  before_action :authenticate_user!

  def index
    expenses = scoped(:expenses).recent_first

    render json: {
      status: { code: 200, message: "Expenses retrieved successfully." },
      data: serialize(expenses)
    }, status: :ok
  end

  def show
    expense = find_scoped(:expenses, params[:id])

    render json: {
      status: { code: 200, message: "Expense retrieved successfully." },
      data: serialize(expense)
    }, status: :ok
  end

  def create
    expense = scoped(:expenses).new(expense_params)

    if expense.save
      render json: {
        status: { code: 201, message: "Expense created successfully." },
        data: serialize(expense)
      }, status: :created
    else
      render json: {
        status: { code: 422, message: "Expense couldn't be created. #{expense.errors.full_messages.to_sentence}" }
      }, status: :unprocessable_entity
    end
  end

  def update
    expense = find_scoped(:expenses, params[:id])

    if expense.update(expense_params)
      render json: {
        status: { code: 200, message: "Expense updated successfully." },
        data: serialize(expense)
      }, status: :ok
    else
      render json: {
        status: { code: 422, message: "Expense couldn't be updated. #{expense.errors.full_messages.to_sentence}" }
      }, status: :unprocessable_entity
    end
  end

  def destroy
    expense = find_scoped(:expenses, params[:id])
    expense.destroy!

    render json: {
      status: { code: 200, message: "Expense deleted successfully." }
    }, status: :ok
  end

  private

  def expense_params
    params.require(:expense).permit(:description, :category, :amount, :date, :periodicity)
  end
end
