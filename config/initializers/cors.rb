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
# Si la variable NO está definida se cae a los valores por defecto de desarrollo
# (localhost). Nunca se usa "*": combinado con `credentials` o sin validación de
# origen, permitiría que cualquier sitio reutilice la API.
default_origins = [ "http://localhost:5173", "http://localhost:3000" ]

allowed_origins = if (env = ENV["CORS_ALLOWED_ORIGINS"].presence)
  env.split(",").map(&:strip).reject(&:blank?)
else
  default_origins
end

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
