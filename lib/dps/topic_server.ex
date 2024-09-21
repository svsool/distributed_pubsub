defmodule DPS.TopicServer do
  use GenServer

  def verify_opts(opts) do
    if opts[:topic] == nil do
      raise ArgumentError, "Topic is required"
    end
  end

  def start_link(opts \\ []) do
    verify_opts(opts)

    GenServer.start_link(__MODULE__, %{
      topic: opts[:topic],
      pids: MapSet.new()
    }, name: :"DPS.TopicServer.#{opts[:topic]}")
  end

  def init(state) do
    {:ok, state}
  end

  def handle_cast({:join, pid}, state) do
    Process.monitor(pid)

    IO.puts("Joined #{inspect(pid)} to #{inspect(state.topic)}")

    {:noreply, %{state | pids: MapSet.put(state.pids, pid)}}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    IO.puts("Left #{inspect(pid)} from #{inspect(state.topic)}")

    # handle leaves automatically
    {:noreply, %{state | pids: MapSet.delete(state.pids, pid)}}
  end
end

defmodule DPS.TopicServer.Supervisor do
  use Supervisor

  @pool_size 1

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    children =
      for shard <- 1..@pool_size do
        Supervisor.child_spec({DPS.TopicServer.Worker, [shard: shard]}, id: "DPS.TopicServer.Supervisor.#{shard}")
      end

    Supervisor.init(children, strategy: :one_for_one)
  end
end

defmodule DPS.TopicServer.Utils do
  @moduledoc false

  @group "topic_servers"

  def resolve_topic_worker_pid(topic)  do
    # TODO: select topic's pid properly by node name and use consistent hashing
    [pid] = :pg.get_members(DPS.PG, @group)

     pid
  end

  def join(pid) do
    :ok = :pg.join(DPS.PG, @group, pid)
  end
end

defmodule DPS.TopicServer.Worker do
  @moduledoc false
  use GenServer

  import DPS.TopicServer.Utils

  def start_link(opts) do
    GenServer.start_link(__MODULE__, [], name: :"DPS.TopicServer.Worker.#{opts[:shard]}")
  end

  @impl true
  def init(opts) do
    :ok = join(self())

    {:ok, %{}}
  end

  def ensure_topic_server_started(topic) do
    case GenServer.whereis(:"DPS.TopicServer.#{topic}") do
      nil ->
        {:ok, pid} = DynamicSupervisor.start_child(DPS.TopicServer.DynamicSupervisor, {DPS.TopicServer, [topic: topic]})
        pid
      pid -> pid
    end
  end

  @impl true
  def handle_cast({:join, topic, pid}, state) do
    topic_server_pid = ensure_topic_server_started(topic)

    :ok = GenServer.cast(topic_server_pid, {:join, pid})

    {:noreply, state}
  end
end



