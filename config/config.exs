# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

schedulers_online = System.schedulers_online()

config :dps,
  namespace: DPS,
  generators: [timestamp_type: :utc_datetime]

config :dps, DPS.TopicClient,
  # should be same across whole fleet
  shards_number: schedulers_online

config :dps, DPS.TopicServer,
  # should be same across whole fleet
  shards_number: schedulers_online

# Configures the endpoint
config :dps, DPSWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: DPSWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: DPS.PubSub,
  live_view: [signing_salt: "inrhHm36"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
