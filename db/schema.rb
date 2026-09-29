# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_26_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "audits", force: :cascade do |t|
    t.string "action"
    t.integer "associated_id"
    t.string "associated_type"
    t.integer "auditable_id"
    t.string "auditable_type"
    t.text "audited_changes"
    t.string "comment"
    t.datetime "created_at"
    t.string "remote_address"
    t.string "request_uuid"
    t.integer "user_id"
    t.string "user_type"
    t.string "username"
    t.integer "version", default: 0
    t.index ["associated_type", "associated_id"], name: "associated_index"
    t.index ["auditable_type", "auditable_id", "version"], name: "auditable_index"
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["request_uuid"], name: "index_audits_on_request_uuid"
    t.index ["user_id", "user_type"], name: "user_index"
  end

  create_table "customers", force: :cascade do |t|
    t.string "address"
    t.datetime "created_at", null: false
    t.string "email"
    t.date "last_order_date"
    t.string "name", null: false
    t.text "notes"
    t.string "phone"
    t.integer "total_orders", default: 0, null: false
    t.decimal "total_spent", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_customers_on_user_id"
  end

  create_table "expenses", force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2, default: "0.0", null: false
    t.string "category"
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.string "description", null: false
    t.string "periodicity"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "date"], name: "index_expenses_on_user_id_and_date"
    t.index ["user_id"], name: "index_expenses_on_user_id"
  end

  create_table "payroll_entries", force: :cascade do |t|
    t.decimal "base_rate", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.text "notes"
    t.date "payment_date", null: false
    t.string "payment_type"
    t.decimal "quantity_or_hours_completed", precision: 12, scale: 2, default: "0.0", null: false
    t.string "role"
    t.string "status", default: "Pendiente", null: false
    t.decimal "total_paid", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "worker_name", null: false
    t.index ["user_id"], name: "index_payroll_entries_on_user_id"
  end

  create_table "products", force: :cascade do |t|
    t.string "business_domain"
    t.string "category"
    t.decimal "cost_price", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.jsonb "custom_attributes", default: {}, null: false
    t.string "image_url"
    t.decimal "min_stock_alert", precision: 12, scale: 2, default: "0.0", null: false
    t.string "name", null: false
    t.jsonb "raw_material_recipe", default: []
    t.decimal "sale_price", precision: 12, scale: 2, default: "0.0", null: false
    t.string "sku"
    t.decimal "stock", precision: 12, scale: 2, default: "0.0", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_products_on_user_id"
  end

  create_table "raw_materials", force: :cascade do |t|
    t.decimal "cost_per_unit", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.decimal "current_stock", precision: 12, scale: 2, default: "0.0", null: false
    t.date "last_restock_date"
    t.decimal "min_stock_alert", precision: 12, scale: 2, default: "0.0", null: false
    t.string "name", null: false
    t.string "supplier"
    t.string "unit"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_raw_materials_on_user_id"
  end

  create_table "stock_movements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "customer_id"
    t.string "customer_name"
    t.date "date", null: false
    t.text "notes"
    t.bigint "product_id"
    t.string "product_name"
    t.decimal "quantity", precision: 12, scale: 2, null: false
    t.decimal "total_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.string "type", null: false
    t.decimal "unit_price", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["customer_id"], name: "index_stock_movements_on_customer_id"
    t.index ["product_id"], name: "index_stock_movements_on_product_id"
    t.index ["user_id", "date"], name: "index_stock_movements_on_user_id_and_date"
    t.index ["user_id"], name: "index_stock_movements_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "company_name"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "jti", null: false
    t.datetime "membership_expires_at"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role", default: "client", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_users_on_active"
    t.index ["company_name"], name: "index_users_on_company_name"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["jti"], name: "index_users_on_jti", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "customers", "users", on_delete: :cascade
  add_foreign_key "expenses", "users", on_delete: :cascade
  add_foreign_key "payroll_entries", "users", on_delete: :cascade
  add_foreign_key "products", "users", on_delete: :cascade
  add_foreign_key "raw_materials", "users", on_delete: :cascade
  add_foreign_key "stock_movements", "customers", on_delete: :nullify
  add_foreign_key "stock_movements", "products", on_delete: :nullify
  add_foreign_key "stock_movements", "users", on_delete: :cascade
end
