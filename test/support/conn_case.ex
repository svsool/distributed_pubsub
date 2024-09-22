defmodule DPSWeb.ConnCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint DPSWeb.Endpoint

      use DPSWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import DPSWeb.ConnCase
    end
  end

  setup _tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
