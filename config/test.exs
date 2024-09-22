import Config

config :dps, DPSWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "BHS3gwXvWAqsLIiffXLUYHwjECc4xvg8b02BYZChpDvQT28CcR4lyTTcyn1ZfmoP",
  server: false

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime
