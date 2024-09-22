defmodule DPSWeb.Socket do
  use Phoenix.Socket

  channel("topics:*", DPSWeb.TopicChannel)

  @impl true
  def id(socket), do: "#{socket.assigns.id}"

  @impl true
  def connect(_params, socket, _connect_info) do
    {:ok, socket |> assign(:id, System.unique_integer([:positive]))}
  end
end
