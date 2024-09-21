defmodule DPSWeb.TopicsChannel do
  use DPSWeb, :channel

  @impl true
  def join(topic, payload, socket) do
    IO.inspect([topic, payload, "test"])

    {:ok, socket}
  end
end
