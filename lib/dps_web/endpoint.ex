defmodule DPSWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :dps

  @session_options [
    store: :cookie,
    key: "_dps_key",
    signing_salt: "CceryYiF",
    same_site: "Lax"
  ]

  # socket "/live", Phoenix.LiveView.Socket,
  #   websocket: [connect_info: [session: @session_options]],
  #   longpoll: [connect_info: [session: @session_options]]

  plug Plug.Static,
    at: "/",
    from: :dps,
    gzip: false,
    only: DPSWeb.static_paths()

  if code_reloading? do
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug DPSWeb.Router
end
