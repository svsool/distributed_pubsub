defmodule DPS.TopicClient.Utils do
  @moduledoc false

  def shards_number, do: Application.get_env(:dps, DPS.TopicClient)[:shards_number]

  def resolve_topic_client_worker_pid(topic) do
    shard = :erlang.phash2(topic, shards_number())

    GenServer.whereis(:"DPS.TopicClient.Worker.#{shard}")
  end
end

defmodule DPS.TopicClient.Supervisor do
  use Supervisor

  import DPS.TopicClient.Utils

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    children =
      for shard <- 0..(shards_number() - 1) do
        Supervisor.child_spec({DPS.TopicClient.Worker, [shard: shard]},
          id: "DPS.TopicClient.Supervisor.#{shard}"
        )
      end

    Supervisor.init(children, strategy: :one_for_one)
  end
end

defmodule DPS.TopicClient.Worker do
  @moduledoc false
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, [], name: :"DPS.TopicClient.Worker.#{opts[:shard]}")
  end

  @impl true
  def init(opts) do
    {:ok, %{}}
  end

  # send() can be used as well for perf reasons to avoid GenServer overhead
  @impl true
  def handle_call({:publish, topic, event, payload}, _from, state) do
    start = System.monotonic_time()

    :ok = DPSWeb.Endpoint.local_broadcast(topic, event, payload)

    duration = System.monotonic_time() - start

    :telemetry.execute(
      [:dps, :topic_client, :publish],
      %{duration: duration},
      %{
        topic: topic,
        event: event,
        payload: payload
      }
    )

    {:reply, :ok, state}
  end
end
