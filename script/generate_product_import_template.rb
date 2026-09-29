# Genera `plantillas/plantilla-productos.xlsx` con la estructura que espera
# POST /products/import. No usa caxlsx (no está en el Gemfile): arma el paquete
# OOXML a mano con rubyzip.
#
#   ruby script/generate_product_import_template.rb
#
# Ejecuta SIEMPRE dentro de chinaFit-api para tener rubyzip disponible.
require "zip"
require "fileutils"
require "erb"

OUTPUT = File.expand_path("../../plantillas/plantilla-productos.xlsx", __dir__)

# --- Columnas que el importador reconoce -------------------------------------
# Debe coincidir con ProductsController::IMPORT_FIELDS.
# Solo las marcadas "req" son obligatorias; el resto se autocompleta si faltan.
COLUMNS = [
  [ "Nombre",        "text",   28, "OBLIGATORIO. Nombre del producto.",                       true ],
  [ "Costo",         "num",    11, "OBLIGATORIO. Precio de inversión (costo). No puede ser negativo.", true ],
  [ "Precio",        "num",    11, "OBLIGATORIO. Precio de venta al público. No puede ser negativo.", true ],
  [ "SKU",           "text",   14, "Opcional. Si se deja vacío se genera uno automático.",    false ],
  [ "Categoría",     "text",   16, "Opcional. Si se deja vacío usa \"General\".",              false ],
  [ "Unidad",        "text",   12, "Opcional. Unidad / Kg / Litros / Metro / Par / Docena / Combo / Juego.", false ],
  [ "Stock",         "num",    10, "Opcional. Cantidad inicial. Si se deja vacío usa 0.",     false ],
  [ "Stock Mínimo",  "num",    13, "Opcional. Alerta de poco stock. Si se deja vacío usa 0.", false ]
].freeze

# Mismo orden que COLUMNS: Nombre, Costo, Precio, SKU, Categoría, Unidad,
# Stock, Stock Mínimo.
SAMPLES = [
  [ "Empanada de Carne", 1.50,  3.00, "EMP-001", "Alimentos",   "Unidad", 50,  10 ],
  [ "Empanada de Pollo", 1.40,  2.80, "EMP-002", "Alimentos",   "Unidad", 40,  10 ],
  [ "Camiseta Bordada",  8.00, 15.00, "CAM-001", "Ropa",        "Unidad", 25,   5 ],
  [ "Tela Algodón",      3.50,  7.00, "TEL-001", "Ropa",        "Metro", 120,  20 ],
  [ "Tornillo 1/2\"",    0.35,  0.90, "HER-001", "Ferretería",  "Unidad", 80,  15 ],
  [ "Caja de Clavos",    9.50, 18.00, "HER-002", "Ferretería",  "Docena", 18,   4 ],
  # Fila con SOLO las 3 columnas obligatorias: el resto se autocompleta.
  [ "Producto Mínimo",   2.00,  4.00, nil,        nil,           nil,     nil, nil ]
].freeze

# --- Helpers de XML ----------------------------------------------------------
def esc(value)
  ERB::Util.html_escape(value.to_s)
end

def col_letter(index)
  letters = +""
  index += 1
  while index.positive?
    index, rem = (index - 1).divmod(26)
    letters.prepend((65 + rem).chr)
  end
  letters
end

# styles.xml: 0 normal, 1 título, 2 header, 3 requerido, 4 nota, 5 ejemplo
STYLES = <<~XML
  <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
    <fonts count="4">
      <font><sz val="11"/><name val="Calibri"/></font>
      <font><b/><sz val="16"/><color rgb="FF1F2937"/><name val="Calibri"/></font>
      <font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font>
      <font><i/><sz val="10"/><color rgb="FF6B7280"/><name val="Calibri"/></font>
    </fonts>
    <fills count="3">
      <fill><patternFill patternType="none"/></fill>
      <fill><patternFill patternType="gray125"/></fill>
      <fill><patternFill patternType="solid"><fgColor rgb="FF4F46E5"/><bgColor indexed="64"/></patternFill></fill>
    </fills>
    <borders count="2">
      <border><left/><right/><top/><bottom/><diagonal/></border>
      <border>
        <left style="thin"><color rgb="FFCBD5E1"/></left>
        <right style="thin"><color rgb="FFCBD5E1"/></right>
        <top style="thin"><color rgb="FFCBD5E1"/></top>
        <bottom style="thin"><color rgb="FFCBD5E1"/></bottom>
        <diagonal/>
      </border>
    </borders>
    <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
    <cellXfs count="6">
      <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
      <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>
      <xf numFmtId="0" fontId="2" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>
      <xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1"/>
      <xf numFmtId="0" fontId="3" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1"><alignment wrapText="1" vertical="top"/></xf>
      <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0" applyFont="1"/>
    </cellXfs>
  </styleSheet>
XML

def cell(ref, value, type, style)
  if type == :num
    %(<c r="#{ref}" s="#{style}"><v>#{value}</v></c>)
  else
    %(<c r="#{ref}" s="#{style}" t="inlineStr"><is><t xml:space="preserve">#{esc(value)}</t></is></c>)
  end
end

# --- Hoja 1: "Instrucciones" -------------------------------------------------
instructions = +""
instructions << %(<row r="1">#{cell("A1", "Importación de Productos - Gestio", :str, 1)}</row>\n)
instructions << %(<row r="2">#{cell("A2", "Copia la fila de encabezados de la hoja \"Plantilla\" y pega tus productos a partir de la fila 2.", :str, 4)}</row>\n)

r = 4
instructions << %(<row r="#{r}">#{cell("A#{r}", "Reglas", :str, 2)}</row>\n)
rules = [
  "La PRIMERA fila debe contener los encabezados. No la borres ni la modifiques.",
  "SOLO son obligatorios: Nombre, Costo y Precio. Las filas a las que les falte alguno se rechazan (el resto sí se importa).",
  "Puedes borrar o dejar vacías las demás columnas: SKU, Categoría, Unidad, Stock y Stock Mínimo se completan automáticamente.",
  "Si agregas columnas EXTRA (Color, Marca, Talla...) se ignoran sin error.",
  "No importa si escribes con o sin tildes ni mayúsculas: \"Categoría\" y \"categoria\" funcionan igual.",
  "El orden de las columnas puede cambiar, pero el nombre de cada encabezado debe seguir siendo reconocible.",
  "Costo y Precio no pueden ser negativos.",
  "Filas completamente vacías se saltan automáticamente."
]
rules.each_with_index do |text, i|
  row = r + 1 + i
  instructions << %(<row r="#{row}">#{cell("A#{row}", "• #{text}", :str, 3)}</row>\n)
end

r = r + rules.size + 2
instructions << %(<row r="#{r}">#{cell("A#{r}", "Qué significa cada columna", :str, 2)}</row>\n)
COLUMNS.each_with_index do |(label, _, _, note, required), ci|
  row = r + 1 + ci
  marker = required ? "#{label} *" : label
  instructions << %(<row r="#{row}">#{cell("A#{row}", marker, :str, 3)}#{cell("B#{row}", note, :str, 3)}</row>\n)
end
r = r + COLUMNS.size + 2

instructions << %(<row r="#{r}">#{cell("A#{r}", "Nombres alternativos aceptados", :str, 2)}</row>\n)
aliases = {
  "Nombre" => "nombre, name, producto",
  "SKU" => "sku, codigo, code",
  "Categoría" => "categoria, category",
  "Unidad" => "unidad, unit, medida",
  "Stock" => "stock, existencia, cantidad",
  "Stock Mínimo" => "stock_minimo, stock minimo, min_stock_alert, alerta",
  "Costo" => "costo, cost, cost_price, precio_costo",
  "Precio" => "precio, price, sale_price, precio_venta"
}
aliases.each_with_index do |(canonical, options), i|
  row = r + 1 + i
  instructions << %(<row r="#{row}">#{cell("A#{row}", canonical, :str, 3)}#{cell("B#{row}", options, :str, 3)}</row>\n)
end

sheet1 = <<~XML
  <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
    <cols>
      <col min="1" max="1" width="95" customWidth="1"/>
      <col min="2" max="2" width="45" customWidth="1"/>
    </cols>
    <sheetData>
  #{instructions}  </sheetData>
  </worksheet>
XML

# --- Hoja 2: "Plantilla" -----------------------------------------------------
plantilla = +""
header_cells = COLUMNS.each_with_index.map do |(label, _, _, _, _), i|
  cell("#{col_letter(i)}1", label, :str, 2)
end.join
plantilla << %(<row r="1">#{header_cells}</row>\n)

SAMPLES.each_with_index do |row_values, ri|
  row_number = ri + 2
  cells = row_values.each_with_index.map do |value, ci|
    # nil means "left blank on purpose" -> emit an empty inline string.
    if value.nil?
      %(<c r="#{col_letter(ci)}#{row_number}" s="3" t="inlineStr"><is><t/></is></c>)
    else
      type = COLUMNS[ci][1] == "num" ? :num : :str
      cell("#{col_letter(ci)}#{row_number}", value, type, 3)
    end
  end.join
  plantilla << %(<row r="#{row_number}">#{cells}</row>\n)
end

cols_xml = COLUMNS.map.with_index do |(_, _, width, _, _), i|
  %(<col min="#{i + 1}" max="#{i + 1}" width="#{width}" customWidth="1"/>)
end.join

sheet2 = <<~XML
  <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
    <cols>#{cols_xml}</cols>
    <sheetData>
  #{plantilla}  </sheetData>
  </worksheet>
XML

# --- Paquete OOXML -----------------------------------------------------------
CONTENT_TYPES = <<~XML
  <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
    <Default Extension="xml" ContentType="application/xml"/>
    <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
    <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
    <Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
    <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
  </Types>
XML

ROOT_RELS = <<~XML
  <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
  </Relationships>
XML

WORKBOOK = <<~XML
  <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
    <sheets>
      <sheet name="Instrucciones" sheetId="1" r:id="rId1"/>
      <sheet name="Plantilla" sheetId="2" r:id="rId2"/>
    </sheets>
  </workbook>
XML

WORKBOOK_RELS = <<~XML
  <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
    <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/>
    <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
  </Relationships>
XML

FileUtils.mkdir_p(File.dirname(OUTPUT))
File.binwrite(OUTPUT, Zip::OutputStream.write_buffer do |zip|
  zip.put_next_entry("[Content_Types].xml"); zip.write(CONTENT_TYPES)
  zip.put_next_entry("_rels/.rels");            zip.write(ROOT_RELS)
  zip.put_next_entry("xl/workbook.xml");       zip.write(WORKBOOK)
  zip.put_next_entry("xl/_rels/workbook.xml.rels"); zip.write(WORKBOOK_RELS)
  zip.put_next_entry("xl/styles.xml");         zip.write(STYLES)
  zip.put_next_entry("xl/worksheets/sheet1.xml"); zip.write(sheet1)
  zip.put_next_entry("xl/worksheets/sheet2.xml"); zip.write(sheet2)
end.string)

puts "Generado: #{OUTPUT} (#{File.size(OUTPUT)} bytes)"
