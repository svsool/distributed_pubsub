defmodule DPSWeb.TopicsChannel do
  use DPSWeb, :channel

  import DPS.TopicServer.Utils

  @impl true
  def join(topic, payload, socket) do
    IO.inspect(["join topic in topics channel", topic, payload])

    pid = resolve_topic_worker_pid(topic)

    IO.inspect([pid, "pid"])

    :ok = GenServer.cast(pid, {:join, topic, self()})

    {:ok, socket}
  end
end
