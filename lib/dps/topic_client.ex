defmodule DPS.TopicClient do
  @moduledoc false

  @shards_number 1

  def shards_number, do: @shards_number

  def resolve_topic_client_worker_pid(topic) do
    shard = :erlang.phash2(topic, @shards_number)

    GenServer.whereis(:"DPS.TopicClient.Worker.#{shard}")
  end
end

defmodule DPS.TopicClient.Supervisor do
  use Supervisor

  import DPS.TopicClient

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

  @impl true
  def handle_cast({:publish, topic, event, payload}, state) do
    DPSWeb.Endpoint.local_broadcast(topic, event, payload)

    {:noreply, state}
  end
end
