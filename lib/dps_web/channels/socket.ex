defmodule DPSWeb.Socket do
  use Phoenix.Socket, log: false

  channel("topics:*", DPSWeb.TopicChannel)

  @impl true
  def id(socket), do: "#{socket.assigns.id}"

  @impl true
  def connect(_params, socket, _connect_info) do
    socket_id = System.unique_integer([:positive])

    :telemetry.execute([:dps, :socket, :connect], %{}, %{socket_id: socket_id})

    {:ok, socket |> assign(:id, socket_id)}
  end
end
