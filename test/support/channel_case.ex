defmodule DPSWeb.ChannelCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ChannelTest
      import DPSWeb.ChannelCase

      @endpoint DPSWeb.Endpoint
    end
  end
end
