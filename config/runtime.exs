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

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :dps, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :dps, DPSWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: {127, 0, 0, 1}, port: port],
    secret_key_base: secret_key_base
end
