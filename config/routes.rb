Rails.application.routes.draw do
  devise_for :users, path: '', path_names: {
    sign_in: 'login',
    sign_out: 'logout',
    registration: 'signup'
  },
  controllers: {
    sessions: 'users/sessions',
    registrations: 'users/registrations'
  }

  # Companies management (admin only)
  resources :companies, only: [:index, :update]

  # Current user status check
  get 'me', to: 'users/current_user#show'

  # Business data (tenant-scoped, requires authentication)
  resources :products do
    # Bulk import from a spreadsheet. Declared before the `:id` member routes
    # are matched so "import" is never treated as a product id.
    collection do
      post :import
    end
  end
  resources :raw_materials
  resources :payroll_entries
  resources :expenses
  resources :customers
  resources :stock_movements, only: [:index, :show, :create, :destroy]

  # Wipe all business data for the current user (replaces frontend resetDemoData)
  delete 'data', to: 'data#destroy'

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
