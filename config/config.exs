import Config

port = System.get_env("PORT") || 8000
path = System.get_env("SCHEMA_PATH") || "/"

# Configures the endpoint
config :schema_server, SchemaWeb.Endpoint,
  http: [port: port],
  url: [host: "localhost", path: path],
  secret_key_base: "HUvG8AlzaUpVx5PShWbGv6JpifzM/d46Rj3mxAIddA7DJ9qKg6df8sG6PsKXScAh",
  render_errors: [view: SchemaWeb.ErrorView, accepts: ~w(html json)],
  pubsub_server: Schema.PubSub

# Configures Elixir's Logger
config :logger, :console,
  handle_otp_reports: true,
  handle_sasl_reports: true,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configures the location of the schema files
config :schema_server, Schema.Cache, home: System.get_env("SCHEMA_DIR")

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
