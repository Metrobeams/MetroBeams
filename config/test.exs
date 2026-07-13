import Config
config :plataforma, Oban, testing: :manual

config :plataforma,
  invitation_email_from: {"Plataforma test", "no-reply@test.local"},
  invitation_base_url: "http://example.test/invitations/accept",
  invitation_token_salt: "organization-invitation-test",
  storage: Plataforma.StorageMock,
  image_processor: Plataforma.ImageProcessorMock

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :plataforma, Plataforma.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "plataforma_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :plataforma, PlataformaWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "ig3H9KN7dHLnELCgIoFH1WYRoz3Li/j4mOJI23RMSwhXrNjllxNUA5EiraMA8xpb",
  server: false

# In test we don't send emails
config :plataforma, Plataforma.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
