import Config

apps = %{
  "ws" => :ws,
  "ts" => :ts
}

config :dps,
  app: Map.get(apps, System.get_env("DPS_APP"), :all)

if System.get_env("PHX_SERVER") do
  config :dps, DPSWeb.Endpoint, server: true
end

if dps_port = System.get_env("DPS_PORT") do
  config :dps, DPSWeb.Endpoint, http: [ip: {127, 0, 0, 1}, port: dps_port |> String.to_integer()]
end

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  config :dps, DPSWeb.Endpoint, secret_key_base: secret_key_base
end
