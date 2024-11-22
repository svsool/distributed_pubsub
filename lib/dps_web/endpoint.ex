defmodule DPSWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :dps

  socket "/socket", DPSWeb.Socket,
    websocket: true,
    longpoll: false

  if code_reloading? do
    plug Phoenix.CodeReloader
  end
end
