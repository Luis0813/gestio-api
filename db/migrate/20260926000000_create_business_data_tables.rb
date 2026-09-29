# frozen_string_literal: true

# Stores the business data previously kept in browser localStorage.
# Every table is multi-tenant: each row belongs to exactly one User via
# the `user_id` foreign key (ON DELETE CASCADE).
class CreateBusinessDataTables < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.string :sku
      t.string :category
      t.string :business_domain
      t.decimal :stock, precision: 12, scale: 2, null: false, default: 0
      t.decimal :min_stock_alert, precision: 12, scale: 2, null: false, default: 0
      t.decimal :cost_price, precision: 12, scale: 2, null: false, default: 0
      t.decimal :sale_price, precision: 12, scale: 2, null: false, default: 0
      t.string :unit
      # Free-form extra attributes: { key => "text" | number | boolean }
      t.jsonb :custom_attributes, null: false, default: {}
      # Array of { raw_material_id (integer), quantity_needed (decimal) }.
      # DB ids are integers so the frontend's rawMaterialId (string) is stored
      # as an integer FK reference here.
      t.jsonb :raw_material_recipe, default: []
      t.string :image_url
      t.timestamps
    end

    create_table :raw_materials do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.string :unit
      t.decimal :current_stock, precision: 12, scale: 2, null: false, default: 0
      t.decimal :cost_per_unit, precision: 12, scale: 2, null: false, default: 0
      t.string :supplier
      t.decimal :min_stock_alert, precision: 12, scale: 2, null: false, default: 0
      t.date :last_restock_date
      t.timestamps
    end

    create_table :expenses do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :description, null: false
      t.string :category
      t.decimal :amount, precision: 12, scale: 2, null: false, default: 0
      t.date :date, null: false
      t.string :periodicity
      t.timestamps
    end

    create_table :payroll_entries do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :worker_name, null: false
      t.string :role
      t.string :payment_type
      t.decimal :base_rate, precision: 12, scale: 2, null: false, default: 0
      t.decimal :quantity_or_hours_completed, precision: 12, scale: 2, null: false, default: 0
      t.decimal :total_paid, precision: 12, scale: 2, null: false, default: 0
      t.date :payment_date, null: false
      t.string :status, null: false, default: "Pendiente"
      t.text :notes
      t.timestamps
    end

    create_table :customers do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.string :phone
      t.string :email
      t.string :address
      t.integer :total_orders, null: false, default: 0
      t.decimal :total_spent, precision: 12, scale: 2, null: false, default: 0
      t.date :last_order_date
      t.text :notes
      t.timestamps
    end

    create_table :stock_movements do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      # Nullable + nullify on delete so a removed product/customer keeps its
      # movement history (denormalized product_name/customer_name survive too).
      t.references :product, foreign_key: { on_delete: :nullify }
      t.references :customer, foreign_key: { on_delete: :nullify }
      t.string :product_name
      # Plain string discriminator (Venta / Compra Insumos / Ajuste Stock /
      # Merma / Pérdida). Named `type` to match the frontend; STI is disabled
      # on the model side via the enum declaration.
      t.string :type, null: false
      t.decimal :quantity, precision: 12, scale: 2, null: false
      t.decimal :unit_price, precision: 12, scale: 2, null: false, default: 0
      t.decimal :total_amount, precision: 12, scale: 2, null: false, default: 0
      t.date :date, null: false
      t.string :customer_name
      t.text :notes
      t.timestamps
    end

    add_index :stock_movements, %i[user_id date]
    add_index :expenses, %i[user_id date]
  end
end
