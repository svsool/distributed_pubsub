defmodule DPSWeb.TopicChannel do
  use DPSWeb, :channel

  import DPS.TopicClient
  import DPS.TopicServer.Utils

  intercept ["event"]

  @impl true
  def join(topic, payload, socket) do
    topic_client_worker_pid = resolve_topic_client_worker_pid(topic)
    topic_server_worker_pid = resolve_topic_server_worker_pid(topic)

    start = System.monotonic_time()

    topic_channel_pid = self()

    :ok =
      GenServer.cast(
        topic_server_worker_pid,
        {:join, topic, topic_channel_pid, topic_client_worker_pid}
      )

    duration = System.monotonic_time() - start

    :telemetry.execute(
      [:dps, :topic_channel, :join],
      %{duration: duration},
      %{
        socket_id: socket.id,
        topic: topic,
        payload: payload,
        topic_channel_pid: topic_channel_pid,
        topic_client_worker_pid: topic_client_worker_pid,
        topic_server_worker_pid: topic_server_worker_pid
      }
    )

    {:ok, socket}
  end

  @impl true
  def handle_in("publish", [event, payload], socket) do
    topic_server_worker_pid = resolve_topic_server_worker_pid(socket.topic)

    start = System.monotonic_time()

    :ok = GenServer.cast(topic_server_worker_pid, {:publish, socket.topic, event, payload})

    duration = System.monotonic_time() - start

    :telemetry.execute(
      [:dps, :topic_channel, :publish],
      %{duration: duration},
      %{
        socket_id: socket.id,
        topic: socket.topic,
        event: event,
        payload: payload,
        topic_server_worker_pid: topic_server_worker_pid
      }
    )

    {:reply, :ok, socket}
  end

  @impl true
  def handle_out(event, payload, socket) do
    start = System.monotonic_time()

    :ok = push(socket, "event", payload)

    duration = System.monotonic_time() - start

    :telemetry.execute(
      [:dps, :topic_channel, :handle_out],
      %{duration: duration},
      %{
        socket_id: socket.id,
        topic: socket.topic,
        event: event,
        payload: payload
      }
    )

    {:noreply, socket}
  end
end
