defmodule DPSWeb.TopicsChannel do
  use DPSWeb, :channel

  import DPS.TopicClient
  import DPS.TopicServer.Utils

  intercept ["event"]

  @impl true
  def join(topic, payload, socket) do
    IO.inspect(["join topic in topics channel", topic, payload])

    topic_client_worker_pid = resolve_topic_client_worker_pid(topic)
    topic_server_worker_pid = resolve_topic_server_worker_pid(topic)

    IO.inspect([
      "channel_pid",
      self(),
      "topic_server_worker_pid",
      topic_server_worker_pid,
      "topic_client_worker_pid",
      topic_client_worker_pid
    ])

    :ok = GenServer.cast(topic_server_worker_pid, {:join, topic, self(), topic_client_worker_pid})

    {:ok, socket}
  end

  @impl true
  def handle_in("publish", [event, payload], socket) do
    IO.inspect(["publish topic in topics channel", socket.topic, payload])

    topic_server_worker_pid = resolve_topic_server_worker_pid(socket.topic)

    :ok = GenServer.cast(topic_server_worker_pid, {:publish, socket.topic, event, payload})

    {:noreply, socket}
  end

  def handle_out("event", payload, socket) do
    IO.inspect([
      "sending outgoing event #{inspect(payload)} in topic #{socket.topic} to socket #{socket.id}",
      payload
    ])

    push(socket, "event", payload)

    {:noreply, socket}
  end
end
