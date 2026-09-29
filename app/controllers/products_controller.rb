class ProductsController < ApplicationController
  before_action :authenticate_user!

  def index
    products = scoped(:products).recent_first

    render json: {
      status: { code: 200, message: "Products retrieved successfully." },
      data: serialize(products)
    }, status: :ok
  end

  def show
    product = find_scoped(:products, params[:id])

    render json: {
      status: { code: 200, message: "Product retrieved successfully." },
      data: serialize(product)
    }, status: :ok
  end

  def create
    product = scoped(:products).new(product_params)

    if product.save
      render json: {
        status: { code: 201, message: "Product created successfully." },
        data: serialize(product)
      }, status: :created
    else
      render json: {
        status: { code: 422, message: "Product couldn't be created. #{product.errors.full_messages.to_sentence}" }
      }, status: :unprocessable_entity
    end
  end

  def update
    product = find_scoped(:products, params[:id])

    if product.update(product_params)
      render json: {
        status: { code: 200, message: "Product updated successfully." },
        data: serialize(product)
      }, status: :ok
    else
      render json: {
        status: { code: 422, message: "Product couldn't be updated. #{product.errors.full_messages.to_sentence}" }
      }, status: :unprocessable_entity
    end
  end

  def destroy
    product = find_scoped(:products, params[:id])
    product.destroy!

    render json: {
      status: { code: 200, message: "Product deleted successfully." }
    }, status: :ok
  end

  # POST /products/import
  # Bulk-creates products for the current tenant from an uploaded spreadsheet.
  #
  # Recognized headers (accents/case are normalized, so "Nombre", "nombre" and
  # "NOMBRE " all work):
  #
  #   nombre | sku | categoria | unidad | stock | stock_minimo | costo | precio
  #
  # The spreadsheet may contain any subset of these columns, and any number of
  # extra ones. Extra columns are ignored, and missing ones are filled by
  # `Product#fill_optional_defaults`. ONLY these three are mandatory:
  #
  #   Nombre, Costo (precio de inversion), Precio (precio de venta)
  #
  # A row missing any of those three is rejected with its row number in
  # `errors`; every other row is still imported. One bad line never aborts the
  # whole import.
  # Uploads are capped so a single request cannot exhaust server memory/DB.
  MAX_UPLOAD_BYTES = 10.megabytes
  MAX_IMPORT_ROWS = 5_000

  def import
    file = params[:file]

    if file.blank?
      return render json: {
        status: { code: 422, message: "Por favor, adjunta un archivo de Excel válido." }
      }, status: :unprocessable_entity
    end

    if file.size.to_i > MAX_UPLOAD_BYTES
      return render json: {
        status: { code: 413, message: "El archivo supera el límite de 10 MB." }
      }, status: 413
    end

    spreadsheet = Roo::Spreadsheet.open(file.path)
    spreadsheet = find_data_sheet(spreadsheet)
    header = spreadsheet.row(1).map { |h| normalize_header(h) }
    last_row = spreadsheet.last_row

    if last_row.to_i < 2
      return render json: {
        status: { code: 422, message: "El archivo no contiene filas de datos." }
      }, status: :unprocessable_entity
    end

    if last_row - 1 > MAX_IMPORT_ROWS
      return render json: {
        status: { code: 422, message: "El archivo tiene demasiadas filas (máximo #{MAX_IMPORT_ROWS}). Divídelo en varios archivos." }
      }, status: :unprocessable_entity
    end

    created = []
    errors = []

    (2..last_row).each do |row_number|
      cells = spreadsheet.row(row_number)
      values = Hash[header.zip(cells)]

      # Skip fully blank rows instead of reporting them as validation errors.
      next if values.values.all? { |v| v.blank? }

      product = scoped(:products).new(build_product_attributes(values))

      if product.save
        created << serialize(product)
      else
        label = values["nombre"].presence || values["name"].presence || "Sin Nombre"
        errors << "Fila #{row_number} (#{label}): #{product.errors.full_messages.to_sentence}"
      end
    end

    # Cap the echoed error list so a fully invalid 5000-row file cannot bloat the response.
    render json: {
      status: { code: 200, message: "Se importaron #{created.size} productos." },
      data: {
        created_count: created.size,
        products: created,
        errors: errors.first(100),
        errors_truncated: errors.size > 100
      }
    }, status: :ok
  rescue StandardError => e
    render json: {
      status: { code: 400, message: "Error al procesar el archivo Excel: #{e.message}" }
    }, status: :bad_request
  end

  private

  # Strips accents, lowercases and squashes whitespace so a column named
  # "Categoría " matches the "categoria" key.
  def normalize_header(value)
    value.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase.strip.squeeze(" ")
  end

  # Each logical field lists the accepted (accent-free, lowercase) header
  # spellings. This is the single source of truth for both the attribute
  # mapping and the "is this column known?" check used by #extra_attributes.
  #
  # Note: entries containing spaces MUST stay quoted; `%w[]` would split
  # "stock minimo" into two unrelated tokens.
  IMPORT_FIELDS = {
    name: [ "nombre", "name", "producto" ],
    sku: [ "sku", "codigo", "code" ],
    category: [ "categoria", "category" ],
    unit: [ "unidad", "unit", "medida" ],
    stock: [ "stock", "existencia", "cantidad" ],
    min_stock_alert: [ "stock_minimo", "stock minimo", "min_stock_alert", "alerta" ],
    cost_price: [ "costo", "cost", "cost_price", "precio_costo" ],
    sale_price: [ "precio", "price", "sale_price", "precio_venta" ]
  }.freeze

  def known_headers
    @known_headers ||= IMPORT_FIELDS.values.flatten.to_set
  end

  # Workbooks often ship with a "Instrucciones"/"Portada" sheet in front of the
  # real data. Reading sheet 1 blindly would try to import the instructions, so
  # the sheet whose first row actually looks like the product header is picked.
  # Falls back to the default sheet when no candidate is found (e.g. single
  # sheet files, or headers the user renamed).
  def find_data_sheet(spreadsheet)
    best = nil
    best_score = 0

    spreadsheet.sheets.each do |name|
      candidate = spreadsheet.sheet(name)
      headers = candidate.row(1).map { |h| normalize_header(h) }
      # Name + SKU are enough to identify a product table; score prefers more matches.
      score = headers.count { |h| known_headers.include?(h) }
      score += 2 if headers.include?("nombre") && headers.include?("sku")
      next if score.zero?
      next unless score > best_score

      best = candidate
      best_score = score
    end

    best || spreadsheet.sheet(spreadsheet.sheets.first)
  end

  # Reads the first present alias for a logical field so several header
  # spellings are accepted.
  def pick(row, *keys)
    keys.each do |key|
      value = row[key]
      return value unless value.blank?
    end
    nil
  end

  # Maps spreadsheet cells onto Product attributes, reusing the model
  # validations (mandatory name/prices, non-negative amounts) for every row.
  #
  # Only `name`, `cost_price` and `sale_price` are required. Missing or blank
  # columns are dropped (`.compact`) so `Product#fill_optional_defaults` applies
  # its own defaults instead of a zero sneaking in as a "valid" value.
  #
  # Columns that are not part of IMPORT_FIELDS are simply ignored.
  def build_product_attributes(row)
    attributes = {
      sku: pick(row, *IMPORT_FIELDS[:sku]).to_s.strip.presence,
      category: pick(row, *IMPORT_FIELDS[:category]).to_s.strip.presence,
      unit: pick(row, *IMPORT_FIELDS[:unit]).to_s.strip.presence,
      stock: pick(row, *IMPORT_FIELDS[:stock]),
      min_stock_alert: pick(row, *IMPORT_FIELDS[:min_stock_alert]),
      business_domain: "custom"
    }.compact

    # The three mandatory fields are kept even when nil: dropping them would let
    # the column DB default turn a missing price into a valid 0.00 product.
    attributes.merge(
      name: pick(row, *IMPORT_FIELDS[:name]).to_s.strip,
      cost_price: pick(row, *IMPORT_FIELDS[:cost_price]),
      sale_price: pick(row, *IMPORT_FIELDS[:sale_price])
    )
  end

  def product_params
    params.require(:product).permit(
      :name, :sku, :category, :business_domain, :stock, :min_stock_alert,
      :cost_price, :sale_price, :unit, :custom_attributes, :raw_material_recipe, :image_url
    )
  end
end
