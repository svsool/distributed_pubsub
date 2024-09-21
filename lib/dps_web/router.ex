defmodule DPSWeb.Router do
  use DPSWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", DPSWeb do
    pipe_through :api
  end
end
