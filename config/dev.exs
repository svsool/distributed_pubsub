import Config

config :dps, DPSWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "/C2+I8FuGmAHq+MfX1wGFmmBhDavp6xhBDD7W2rx1vzSYVWjsc+Qow54KOp+Z2eL",
  watchers: []

{:ok, hostname} = :inet.gethostname()

config :dps, DPS.TopicServer, nodes: ["dps-ts-a@#{hostname}", "dps-ts-b@#{hostname}"]

config :libcluster,
  # debug: true,
  topologies: [
    gossip: [
      strategy: Cluster.Strategy.Gossip
    ]
  ]

config :dps, dev_routes: true

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20

config :phoenix, :plug_init_mode, :runtime
