# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

# config/initializers/cors.rb

# Orígenes permitidos. Se configura por variable de entorno para no tener que
# tocar el código en cada deploy.
#
#   CORS_ALLOWED_ORIGINS=https://app.vercel.app,https://mitienda.com
#
# Si la variable NO está definida se cae a los valores por defecto, que incluyen
# SIEMPRE el frontend de producción. Esto evita que un redeploy sin la variable
# configurada en el hosting rompa el login con "No 'Access-Control-Allow-Origin'
# header is present".
#
# Nunca se usa "*": combinado con `credentials` o sin validación de origen,
# permitiría que cualquier sitio reutilice la API.
default_origins = [
  "http://localhost:5173",
  "http://localhost:3000",
  "https://gestio-page.vercel.app"
]

# La variable de entorno SUMA a los defaults, no los reemplaza. Así una variable
# mal escrita nunca deja fuera al frontend de producción ni a localhost.
env_origins = ENV["CORS_ALLOWED_ORIGINS"].to_s.split(",").map(&:strip).reject(&:blank?)

allowed_origins = (default_origins + env_origins).uniq

# Previews de Vercel sólo en desarrollo, para no abrir producción.
vercel_preview = if Rails.env.development?
  [ /https:\/\/.*\.vercel\.app\z/ ]
else
  []
end

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*allowed_origins, *vercel_preview)

    resource "*",
      headers: :any,
      expose: [ "Authorization" ],
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      max_age: 600
  end
end
