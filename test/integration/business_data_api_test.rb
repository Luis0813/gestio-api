require "test_helper"
require "tempfile"
require "zip"

class BusinessDataApiTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "biz_owner@gestio.com",
      password: "password123",
      role: "company",
      company_name: "Empresa Datos",
      active: true,
      membership_expires_at: 1.month.from_now
    )

    @other_user = User.create!(
      email: "biz_other@gestio.com",
      password: "password123",
      role: "company",
      company_name: "Empresa Ajena",
      active: true,
      membership_expires_at: 1.month.from_now
    )

    @token = login(@user)
    @other_token = login(@other_user)
  end

  # --- Authentication -------------------------------------------------------

  test "business data endpoints require authentication" do
    get "/products", as: :json
    assert_response :unauthorized

    get "/expenses", as: :json
    assert_response :unauthorized

    get "/customers", as: :json
    assert_response :unauthorized
  end

  # --- Tenant isolation (most important) ------------------------------------

  test "tenant isolation: cannot read update or delete another user's product" do
    foreign_product = @other_user.products.create!(product_attributes(name: "Producto Ajeno", stock: 10, sale_price: 5.5))

    get "/products/#{foreign_product.id}", headers: auth_headers(@token), as: :json
    assert_response :not_found
    assert_equal 404, JSON.parse(response.body)["status"]["code"]

    patch "/products/#{foreign_product.id}",
      params: { product: { name: "Hackeado" } },
      headers: auth_headers(@token),
      as: :json
    assert_response :not_found
    assert_equal "Producto Ajeno", foreign_product.reload.name

    put "/products/#{foreign_product.id}",
      params: { product: { name: "Hackeado" } },
      headers: auth_headers(@token),
      as: :json
    assert_response :not_found
    assert_equal "Producto Ajeno", foreign_product.reload.name

    delete "/products/#{foreign_product.id}", headers: auth_headers(@token), as: :json
    assert_response :not_found
    assert Product.exists?(foreign_product.id)
  end

  test "tenant isolation: index only lists current user's products" do
    @other_user.products.create!(product_attributes(name: "Producto Ajeno", stock: 1))
    create_product_via_api(name: "Producto Propio")

    get "/products", headers: auth_headers(@token), as: :json
    assert_response :success

    names = JSON.parse(response.body)["data"].map { |p| p["name"] }
    assert_includes names, "Producto Propio"
    assert_not_includes names, "Producto Ajeno"
  end

  test "tenant isolation: cannot touch another user's expense" do
    foreign_expense = @other_user.expenses.create!(description: "Gasto Ajeno", amount: 10, date: Date.current)

    get "/expenses/#{foreign_expense.id}", headers: auth_headers(@token), as: :json
    assert_response :not_found

    delete "/expenses/#{foreign_expense.id}", headers: auth_headers(@token), as: :json
    assert_response :not_found
    assert Expense.exists?(foreign_expense.id)
  end

  # --- Products CRUD round trip --------------------------------------------

  test "full product CRUD round trip with numeric decimals and ISO dates" do
    post "/products", params: {
      product: {
        name: "Camisa Polo",
        sku: "SKU-001",
        category: "Ropa",
        business_domain: "ropa",
        stock: 25,
        min_stock_alert: 5,
        cost_price: 10.5,
        sale_price: 20.75,
        unit: "unidad"
      }
    }, headers: auth_headers(@token), as: :json

    assert_response :created
    json = JSON.parse(response.body)
    product = json["data"]

    assert_equal 201, json["status"]["code"]
    assert_kind_of Integer, product["id"]

    # Decimals must arrive as JSON numbers, not strings.
    assert_kind_of Numeric, product["stock"]
    assert_kind_of Numeric, product["cost_price"]
    assert_kind_of Numeric, product["sale_price"]
    assert_equal 20.75, product["sale_price"]

    # Timestamps are ISO8601 strings.
    assert_match(/\A\d{4}-\d{2}-\d{2}T/, product["created_at"])

    product_id = product["id"]

    get "/products", headers: auth_headers(@token), as: :json
    assert_response :success
    assert JSON.parse(response.body)["data"].any? { |p| p["id"] == product_id }

    get "/products/#{product_id}", headers: auth_headers(@token), as: :json
    assert_response :success
    assert_equal "Camisa Polo", JSON.parse(response.body)["data"]["name"]

    patch "/products/#{product_id}",
      params: { product: { name: "Camisa Polo Premium", stock: 30 } },
      headers: auth_headers(@token),
      as: :json
    assert_response :success
    updated = JSON.parse(response.body)["data"]
    assert_equal "Camisa Polo Premium", updated["name"]
    assert_equal 30, updated["stock"]

    delete "/products/#{product_id}", headers: auth_headers(@token), as: :json
    assert_response :success
    assert_equal 200, JSON.parse(response.body)["status"]["code"]

    get "/products/#{product_id}", headers: auth_headers(@token), as: :json
    assert_response :not_found
  end

  test "product creation returns 422 with error message on invalid payload" do
    post "/products", params: { product: { sku: "SIN-NOMBRE" } }, headers: auth_headers(@token), as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal 422, json["status"]["code"]
    assert_includes json["status"]["message"], "couldn't be created"
  end

  test "expense serializes amount as number and date as YYYY-MM-DD" do
    post "/expenses", params: {
      expense: {
        description: "Alquiler del local",
        category: "Alquiler",
        amount: 1200.5,
        date: "2026-09-26",
        periodicity: "Mensual"
      }
    }, headers: auth_headers(@token), as: :json

    assert_response :created
    expense = JSON.parse(response.body)["data"]
    assert_kind_of Numeric, expense["amount"]
    assert_equal 1200.5, expense["amount"]
    assert_equal "2026-09-26", expense["date"]
    assert_match(/\A\d{4}-\d{2}-\d{2}\z/, expense["date"])
  end

  test "raw material, payroll entry and customer CRUD work" do
    post "/raw_materials", params: {
      raw_material: { name: "Algodón", unit: "kg", current_stock: 40, cost_per_unit: 3.75, last_restock_date: "2026-09-20" }
    }, headers: auth_headers(@token), as: :json
    assert_response :created
    raw_material = JSON.parse(response.body)["data"]
    assert_equal 40, raw_material["current_stock"]
    assert_equal "2026-09-20", raw_material["last_restock_date"]

    post "/payroll_entries", params: {
      payroll_entry: {
        worker_name: "Luis Pérez",
        role: "Cocinero",
        payment_type: "Por Hora",
        base_rate: 5.0,
        quantity_or_hours_completed: 40,
        total_paid: 200.0,
        payment_date: "2026-09-25",
        status: "Pagado"
      }
    }, headers: auth_headers(@token), as: :json
    assert_response :created
    payroll_entry = JSON.parse(response.body)["data"]
    assert_equal 200.0, payroll_entry["total_paid"]
    assert_equal "2026-09-25", payroll_entry["payment_date"]

    post "/customers", params: {
      customer: { name: "Ana Gómez", phone: "0412-1234567", total_spent: 50.0, last_order_date: "2026-09-01" }
    }, headers: auth_headers(@token), as: :json
    assert_response :created
    customer = JSON.parse(response.body)["data"]
    assert_equal "Ana Gómez", customer["name"]
    assert_equal 50.0, customer["total_spent"]

    get "/raw_materials", headers: auth_headers(@token), as: :json
    assert_response :success
    get "/payroll_entries", headers: auth_headers(@token), as: :json
    assert_response :success
    get "/customers", headers: auth_headers(@token), as: :json
    assert_response :success
  end

  # --- Stock movements ------------------------------------------------------

  test "creating a Venta movement decrements stock and bumps the customer in one request" do
    product = @user.products.create!(product_attributes(name: "Empanada", stock: 20, sale_price: 2.5))
    customer = @user.customers.create!(name: "Cliente Fiel", total_orders: 3, total_spent: 40.0)

    post "/stock_movements", params: {
      stock_movement: {
        product_id: product.id,
        customer_id: customer.id,
        customer_name: "Cliente Fiel",
        type: "Venta",
        quantity: 6,
        unit_price: 2.5,
        total_amount: 15.0,
        date: "2026-09-26"
      }
    }, headers: auth_headers(@token), as: :json

    assert_response :created
    data = JSON.parse(response.body)["data"]

    assert_equal 14.0, product.reload.stock.to_f
    assert_equal 4, customer.reload.total_orders
    assert_equal 55.0, customer.total_spent.to_f
    assert_equal Date.new(2026, 9, 26), customer.last_order_date

    # Nested payload lets the frontend reconcile without a refetch.
    assert_equal 14.0, data["product"]["stock"]
    assert_equal 4, data["customer"]["total_orders"]
    assert_equal 55.0, data["customer"]["total_spent"]
    assert_equal 15.0, data["movement"]["total_amount"]
    assert_equal 6.0, data["movement"]["quantity"]
    assert_equal "2026-09-26", data["movement"]["date"]
    assert_kind_of Numeric, data["movement"]["total_amount"]

    # Single movement was recorded.
    assert_equal 1, @user.stock_movements.count
  end

  test "creating a Venta movement with an unknown customer_name creates the customer" do
    product = @user.products.create!(product_attributes(name: "Cable", stock: 50, sale_price: 1.0))

    post "/stock_movements", params: {
      stock_movement: {
        product_id: product.id,
        customer_name: "nuevo cliente",
        type: "Venta",
        quantity: 2,
        unit_price: 10.0,
        total_amount: 20.0,
        date: "2026-09-26"
      }
    }, headers: auth_headers(@token), as: :json

    assert_response :created
    data = JSON.parse(response.body)["data"]

    customer = @user.customers.find_by(name: "nuevo cliente")
    assert_not_nil customer
    assert_equal 1, customer.total_orders
    assert_equal 20.0, customer.total_spent.to_f
    assert_equal Date.new(2026, 9, 26), customer.last_order_date
    assert_equal customer.id, data["customer"]["id"]
    assert_equal 48.0, product.reload.stock.to_f
  end

  test "creating a Venta movement matches an existing customer by case insensitive name" do
    @user.customers.create!(name: "Maria Lopez", total_orders: 1, total_spent: 10.0)
    product = @user.products.create!(product_attributes(name: "Tornillo", stock: 100))

    post "/stock_movements", params: {
      stock_movement: {
        product_id: product.id,
        customer_name: "  MARIA LOPEZ ",
        type: "Venta",
        quantity: 1,
        unit_price: 5.0,
        total_amount: 5.0,
        date: "2026-09-26"
      }
    }, headers: auth_headers(@token), as: :json

    assert_response :created
    assert_equal 1, @user.customers.count
    assert_equal 15.0, @user.customers.first.total_spent.to_f
  end

  test "Merma movement decrements stock and never goes below zero" do
    product = @user.products.create!(product_attributes(name: "Harina", stock: 3))

    post "/stock_movements", params: {
      stock_movement: {
        product_id: product.id,
        type: "Merma / Pérdida",
        quantity: 10,
        total_amount: 0,
        date: "2026-09-26"
      }
    }, headers: auth_headers(@token), as: :json

    assert_response :created
    data = JSON.parse(response.body)["data"]
    assert_equal 0.0, product.reload.stock.to_f
    assert_equal 0.0, data["product"]["stock"]
    assert_nil data["customer"]
  end

  test "Compra Insumos movement increases stock" do
    product = @user.products.create!(product_attributes(name: "Azúcar", stock: 5))

    post "/stock_movements", params: {
      stock_movement: {
        product_id: product.id,
        type: "Compra Insumos",
        quantity: 12.5,
        unit_price: 2.0,
        total_amount: 25.0,
        date: "2026-09-26"
      }
    }, headers: auth_headers(@token), as: :json

    assert_response :created
    assert_equal 17.5, product.reload.stock.to_f
  end

  test "stock movements are tenant scoped" do
    foreign_product = @other_user.products.create!(product_attributes(name: "Producto Ajeno", stock: 8))
    foreign_movement = @other_user.stock_movements.create!(
      product: foreign_product, type: "Venta", quantity: 1, total_amount: 1, date: Date.current
    )

    get "/stock_movements/#{foreign_movement.id}", headers: auth_headers(@token), as: :json
    assert_response :not_found

    delete "/stock_movements/#{foreign_movement.id}", headers: auth_headers(@token), as: :json
    assert_response :not_found

    # A movement may not adjust stock on a product of another tenant.
    post "/stock_movements", params: {
      stock_movement: { product_id: foreign_product.id, type: "Venta", quantity: 5, date: "2026-09-26" }
    }, headers: auth_headers(@token), as: :json
    assert_response :created
    assert_equal 8.0, foreign_product.reload.stock.to_f
  end

  # --- Data reset -----------------------------------------------------------

  test "DELETE /data wipes all collections for the current user only" do
    product = @user.products.create!(product_attributes(name: "Producto Propio", stock: 3))
    @user.raw_materials.create!(name: "Harina")
    @user.expenses.create!(description: "Gasto", amount: 1, date: Date.current)
    @user.payroll_entries.create!(worker_name: "Luis", payment_date: Date.current)
    @user.customers.create!(name: "Cliente")
    @user.stock_movements.create!(product: product, type: "Venta", quantity: 1, total_amount: 1, date: Date.current)

    other_product = @other_user.products.create!(product_attributes(name: "Producto Ajeno", stock: 9))
    @other_user.customers.create!(name: "Cliente Ajeno")

    delete "/data", headers: auth_headers(@token), as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 200, json["status"]["code"]
    assert_nil json["data"]

    assert_equal 0, @user.products.count
    assert_equal 0, @user.raw_materials.count
    assert_equal 0, @user.expenses.count
    assert_equal 0, @user.payroll_entries.count
    assert_equal 0, @user.customers.count
    assert_equal 0, @user.stock_movements.count

    # Other tenant untouched.
    assert_equal 1, @other_user.products.count
    assert_equal 1, @other_user.customers.count
    assert Product.exists?(other_product.id)
  end

  test "DELETE /data requires authentication" do
    delete "/data", as: :json
    assert_response :unauthorized
  end

  # --- Spreadsheet import ---------------------------------------------------

  test "POST /products/import creates products and reports per-row errors" do
    post "/products/import", params: { file: xlsx_upload([
      [ "Nombre", "SKU", "Categoría", "Unidad", "Stock", "Stock Mínimo", "Costo", "Precio", "Color" ],
      [ "Empanada Carne", "EMP-1", "Alimentos", "Unidad", 50, 10, 1.5, 3.0, "Rojo" ],
      [ "Camiseta", "CAM-2", "Ropa", "Unidad", 20, 5, 8, 15, "Azul" ],
      [ "", "", "", "", "", "", "", "", "" ], # blank row -> skipped
      [ "Producto Sin Precio", "SIN-3", "Alimentos", "Unidad", 5, 1, nil, nil, "" ] # -> validation error
    ]) }, headers: auth_headers(@token)

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal 2, body["data"]["created_count"]
    assert_equal 1, body["data"]["errors"].size
    assert_match(/Fila 5/, body["data"]["errors"].first)
    # Only name/cost/sale are required, so a row without prices is the one case
    # that must be rejected instead of silently imported at 0.00
    assert_match(/Cost price can't be blank/, body["data"]["errors"].first)
    assert_match(/Sale price can't be blank/, body["data"]["errors"].first)

    products = @user.products.order(:id).to_a
    assert_equal [ "Empanada Carne", "Camiseta" ], products.map(&:name)
    assert_equal "EMP-1", products[0].sku
    assert_equal "Alimentos", products[0].category
    # Decimals must arrive as JSON numbers, never strings (the toFixed crash)
    assert_equal 1.5, body["data"]["products"][0]["cost_price"]
    assert_equal 3.0, body["data"]["products"][0]["sale_price"]
    # Unknown columns are ignored, not stored
    assert_empty products[0].custom_attributes
    assert_empty products[1].custom_attributes
  end

  test "POST /products/import works with ONLY the 3 mandatory columns" do
    post "/products/import", params: { file: xlsx_upload([
      [ "Nombre", "Costo", "Precio" ],
      [ "Empanada minima", 1.5, 3.0 ]
    ]) }, headers: auth_headers(@token)

    assert_response :ok
    body = JSON.parse(response.body)
    assert_empty body["data"]["errors"]
    assert_equal 1, body["data"]["created_count"]

    product = @user.products.order(:id).first
    assert_equal "Empanada minima", product.name
    # Everything else is auto-filled
    assert_match(/\APROD-/, product.sku)
    assert_equal "General", product.category
    assert_equal "Unidad", product.unit
    assert_equal 0, product.stock.to_f
    assert_equal 0, product.min_stock_alert.to_f
  end

  test "POST /products/import fills blanks in optional columns" do
    post "/products/import", params: { file: xlsx_upload([
      [ "Nombre", "SKU", "Categoría", "Unidad", "Stock", "Stock Mínimo", "Costo", "Precio" ],
      [ "Blancos", "", "", "", "", "", 2.0, 5.0 ]
    ]) }, headers: auth_headers(@token)

    assert_response :ok
    assert_empty JSON.parse(response.body)["data"]["errors"]

    product = @user.products.order(:id).first
    assert_equal "Blancos", product.name
    assert_match(/\APROD-/, product.sku)
    assert_equal "General", product.category
    assert_equal "Unidad", product.unit
    assert_equal 0, product.stock.to_f
  end

  test "POST /products/import ignores columns it does not know" do
    post "/products/import", params: { file: xlsx_upload([
      [ "Nombre", "Costo", "Precio", "Color", "Marca", "Proveedor", "Whatever" ],
      [ "Con extras", 1.0, 2.0, "Rojo", "Nike", "ACME", "xyz" ]
    ]) }, headers: auth_headers(@token)

    assert_response :ok
    body = JSON.parse(response.body)
    assert_empty body["data"]["errors"]
    assert_equal 1, body["data"]["created_count"]

    product = @user.products.order(:id).first
    assert_equal "Con extras", product.name
    assert_empty product.custom_attributes
  end

  test "POST /products/import skips a column entirely when the header is absent" do
    post "/products/import", params: { file: xlsx_upload([
      [ "Nombre", "Precio", "Notas Internas" ],
      [ "Sin costo", 9.0, "cualquier cosa" ]
    ]) }, headers: auth_headers(@token)

    assert_response :ok
    body = JSON.parse(response.body)
    # Cost is mandatory, so this row is rejected with a clear message
    assert_equal 0, body["data"]["created_count"]
    assert_equal 1, body["data"]["errors"].size
    assert_match(/Cost price can't be blank/, body["data"]["errors"].first)
  end

  test "POST /products/import is tenant scoped and requires authentication" do
    post "/products/import", as: :json
    assert_response :unauthorized

    post "/products/import", params: { file: xlsx_upload([
      [ "Nombre", "Costo", "Precio" ],
      [ "Ajeno", 1, 2 ]
    ]) }, headers: auth_headers(@token)
    assert_response :ok

    assert_equal 0, @other_user.products.count
    assert_equal 1, @user.products.count
  end

  test "POST /products/import rejects a missing file" do
    post "/products/import", params: {}, headers: auth_headers(@token)
    assert_response :unprocessable_entity
  end

  test "POST /products/import rejects a file over the size limit" do
    oversized = Tempfile.new([ "grande", ".xlsx" ])
    oversized.binmode
    # A valid zip header followed by padding past MAX_UPLOAD_BYTES.
    oversized.write("PK\x03\x04")
    oversized.write("0" * (ProductsController::MAX_UPLOAD_BYTES + 1024))
    oversized.flush
    oversized.close

    post "/products/import",
      params: { file: Rack::Test::UploadedFile.new(oversized.path, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet") },
      headers: auth_headers(@token)

    assert_response 413
    assert_equal 0, @user.products.count
  end

  test "POST /products/import rejects a file with too many rows" do
    too_many = [ [ "Nombre", "Costo", "Precio" ] ]
    (ProductsController::MAX_IMPORT_ROWS + 2).times { |i| too_many << [ "P#{i}", 1, 2 ] }

    post "/products/import", params: { file: xlsx_upload(too_many) }, headers: auth_headers(@token)

    assert_response :unprocessable_entity
    assert_match(/demasiadas filas/, JSON.parse(response.body)["status"]["message"])
    assert_equal 0, @user.products.count
  end

  test "POST /products/import caps the returned error list and flags truncation" do
    invalid = [ [ "Nombre", "Costo", "Precio" ] ]
    150.times { |i| invalid << [ "Sin precio #{i}", nil, nil ] }

    post "/products/import", params: { file: xlsx_upload(invalid) }, headers: auth_headers(@token)

    assert_response :ok
    body = JSON.parse(response.body)["data"]
    assert_equal 0, body["created_count"]
    assert_equal 100, body["errors"].size
    assert body["errors_truncated"]
  end

  test "the generated plantilla-productos.xlsx is importable end to end" do
    template = Rails.root.join("..", "plantillas", "plantilla-productos.xlsx")
    skip "plantilla no generada" unless File.exist?(template)

    post "/products/import", params: { file: Rack::Test::UploadedFile.new(template.to_s, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet") },
      headers: auth_headers(@token)

    assert_response :ok
    body = JSON.parse(response.body)
    assert_empty body["data"]["errors"], "la plantilla debe ser 100% importable"
    assert_equal 7, body["data"]["created_count"]

    imported = @user.products.order(:id).to_a
    assert_equal 7, imported.count
    assert_equal [ "EMP-001", "CAM-001", "HER-001" ], imported.map(&:sku).values_at(0, 2, 4)
    assert_equal [ "Alimentos", "Ropa", "Ferretería" ], imported.map(&:category).values_at(0, 2, 4)
    assert_equal [ "Unidad", "Metro", "Docena" ], imported.map(&:unit).values_at(0, 3, 5)
    # `pluck` returns BigDecimal from Postgres; compare as floats.
    sale_prices = imported.map { |p| p.sale_price.to_f }
    assert_equal 0.90, sale_prices.min
    assert_equal 18.00, sale_prices.max
    # The last sample row only has the 3 mandatory columns and must be auto-filled
    minimal = imported.last
    assert_equal "Producto Mínimo", minimal.name
    assert_match(/\APROD-/, minimal.sku)
    assert_equal "General", minimal.category
    assert_equal 0, minimal.stock.to_f
    # Decimals arrive as JSON numbers, not strings (the original toFixed crash)
    body["data"]["products"].each do |product|
      assert_kind_of Float, product["sale_price"]
      assert_kind_of Float, product["cost_price"]
      assert_kind_of Float, product["stock"]
    end
  end

  private

  # Builds an in-memory .xlsx payload without adding a binary fixture to the repo.

  # Rack's multipart parser reads the file off disk during the request, so the
  # Tempfile is intentionally left on disk for the duration of the test.
  def xlsx_upload(rows)
    file = Tempfile.new([ "productos", ".xlsx" ])
    file.binmode
    file.write(write_xlsx(rows))
    file.flush # the controller reads the file from disk, so it must hit the FS first
    file.close
    Rack::Test::UploadedFile.new(file.path, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
  end

  # Minimal xlsx (zip of XML parts) writer good enough for Roo to parse.
  def write_xlsx(rows)
    sheet_rows = rows.map.with_index do |cells, i|
      cell_xml = cells.each_with_index.map do |value, j|
        # A1-style reference: column letters then the 1-based row number.
        ref = "#{column_letter(j)}#{i + 1}"
        "<c r=\"#{ref}\" t=\"inlineStr\"><is><t>#{ERB::Util.html_escape(value.to_s)}</t></is></c>"
      end.join
      %(<row r="#{i + 1}">#{cell_xml}</row>)
    end.join

    document = %(<?xml version="1.0" encoding="UTF-8"?>
      <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>#{sheet_rows}</sheetData></worksheet>)

    # rubyzip >= 3 exposes `write_buffer` (the old `Zip::OutputStream.write` is gone).
    buffer = Zip::OutputStream.write_buffer do |zip|
      zip.put_next_entry("[Content_Types].xml")
      zip.write(%(<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>))
      zip.put_next_entry("_rels/.rels")
      zip.write(%(<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>))
      zip.put_next_entry("xl/workbook.xml")
      zip.write(%(<?xml version="1.0" encoding="UTF-8"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Hoja1" sheetId="1" r:id="rId1"/></sheets></workbook>))
      zip.put_next_entry("xl/_rels/workbook.xml.rels")
      zip.write(%(<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>))
      zip.put_next_entry("xl/worksheets/sheet1.xml")
      zip.write(document)
    end

    buffer.string
  end

  def login(user)
    post "/login", params: { user: { email: user.email, password: "password123" } }, as: :json
    response.headers["Authorization"]
  end

  def auth_headers(token)
    { "Authorization" => token }
  end

  # 0 -> A, 1 -> B, ... 25 -> Z, 26 -> AA
  def column_letter(index)
    letters = +""
    index += 1
    while index.positive?
      index, remainder = (index - 1).divmod(26)
      letters.prepend((65 + remainder).chr)
    end
    letters
  end

  # Product requires name, sku, category, unit and the numeric fields, so every
  # fixture goes through this helper to keep the mandatory attributes in sync.
  def product_attributes(overrides = {})
    {
      name: "Producto Test",
      sku: "SKU-#{SecureRandom.hex(4).upcase}",
      category: "General",
      unit: "Unidad",
      stock: 10,
      min_stock_alert: 2,
      cost_price: 1.0,
      sale_price: 3.0
    }.merge(overrides)
  end

  def create_product_via_api(name:, **overrides)
    post "/products", params: { product: product_attributes({ name: name }.merge(overrides)) },
      headers: auth_headers(@token), as: :json
    JSON.parse(response.body)["data"]
  end
end
