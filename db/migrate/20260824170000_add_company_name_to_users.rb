# frozen_string_literal: true

class AddCompanyNameToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :company_name, :string
    add_index :users, :company_name
  end
end
