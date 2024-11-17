defmodule DPS.TopicServer.Utils do
  @moduledoc false

  alias ExHashRing.Ring

  @group "topic_servers"

  def shards_number, do: Application.get_env(:dps, DPS.TopicServer)[:shards_number]

  def resolve_topic_server_worker_pid(topic) do
    {:ok, node_name} = Ring.find_node(DPS.Ring, topic)

    members = :pg.get_members(DPS.PG, @group)

    topic_server_worker_pids = members |> Enum.filter(&(node(&1) == node_name))

    if length(topic_server_worker_pids) > 0 do
      pid_index =
        case length(topic_server_worker_pids) do
          1 -> 0
          len when len > 1 -> :rand.uniform(len - 1)
        end

      # TODO: do in a round-robin fashion e.g. based on load
      # route to a random topic server worker for now
      pid = topic_server_worker_pids |> Enum.at(pid_index)

      if pid == nil do
        {:error}
      else
        {:ok, pid}
      end
    else
      {:error}
    end
  end

  def join(pid) do
    :ok = :pg.join(DPS.PG, @group, pid)
  end
end

defmodule DPS.TopicServer do
  use GenServer

  import DPS.TopicServer.Utils

  def verify_opts!(opts) do
    if opts[:topic] == nil do
      raise ArgumentError, "Topic is required"
    end
  end

  def start_link(opts \\ []) do
    verify_opts!(opts)

    GenServer.start_link(
      __MODULE__,
      %{
        topic: opts[:topic],
        subscribers: MapSet.new()
      },
      name: :"DPS.TopicServer.#{opts[:topic]}"
    )
  end

  def subscribers(topic) do
    {:ok, topic_server_pid} = resolve_topic_server_worker_pid(topic)

    GenServer.call(topic_server_pid, {:subscribers, topic})
  end

  def init(state) do
    {:ok, state}
  end

  def handle_call({:join, channel_pid, topic_client_worker_pid}, _from, state) do
    :telemetry.execute(
      [:dps, :topic_server, :join],
      %{},
      %{
        topic: state.topic,
        channel_pid: channel_pid,
        topic_client_worker_pid: topic_client_worker_pid
      }
    )

    Process.monitor(channel_pid)

    {:reply, :ok,
     %{
       state
       | subscribers:
           MapSet.put(state.subscribers, %{
             channel_pid: channel_pid,
             topic_client_worker_pid: topic_client_worker_pid
           })
     }}
  end

  def handle_call({:publish, event, payload}, _from, state) do
    start = System.monotonic_time(:millisecond)

    for %{topic_client_worker_pid: topic_client_worker_pid} <- state.subscribers do
      :ok = GenServer.call(topic_client_worker_pid, {:publish, state.topic, event, payload})
    end

    duration = System.monotonic_time(:millisecond) - start

    :telemetry.execute(
      [:dps, :topic_server, :publish],
      %{},
      %{
        topic: state.topic,
        event: event,
        payload: payload,
        duration: duration
      }
    )

    {:reply, :ok, state}
  end

  def handle_call(:subscribers, _from, state) do
    {:reply, MapSet.to_list(state.subscribers), state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    :telemetry.execute(
      [:dps, :topic_server, :leave],
      %{},
      %{
        topic: state.topic,
        pid: pid
      }
    )

    # handle leaves automatically
    {:noreply,
     %{
       state
       | subscribers:
           MapSet.reject(state.subscribers, fn %{channel_pid: channel_pid} ->
             channel_pid == pid
           end)
     }}
  end
end

defmodule DPS.TopicServer.Supervisor do
  use Supervisor

  import DPS.TopicServer.Utils

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    children =
      for shard <- 0..(shards_number() - 1) do
        Supervisor.child_spec({DPS.TopicServer.Worker, [shard: shard]},
          id: "DPS.TopicServer.Supervisor.#{shard}"
        )
      end

    Supervisor.init(children, strategy: :one_for_one)
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
        result =
          DynamicSupervisor.start_child(
            DPS.TopicServer.DynamicSupervisor,
            {DPS.TopicServer, [topic: topic]}
          )

        case result do
          {:ok, pid} ->
            pid

          # can happen with concurrent requests, when branch visited by multiple workers
          {:error, {:already_started, pid}} ->
            pid
        end

      pid ->
        pid
    end
  end

  @impl true
  def handle_call({:join, topic, channel_pid, topic_client_worker_pid}, _from, state) do
    topic_server_pid = ensure_topic_server_started(topic)

    result = GenServer.call(topic_server_pid, {:join, channel_pid, topic_client_worker_pid})

    {:reply, result, state}
  end

  # send() can be used as well for perf reasons to avoid GenServer overhead
  @impl true
  def handle_call({:publish, topic, event, payload}, _from, state) do
    topic_server_pid = ensure_topic_server_started(topic)

    result = GenServer.call(topic_server_pid, {:publish, event, payload})

    {:reply, result, state}
  end

  @impl true
  def handle_call({:subscribers, topic}, _from, state) do
    topic_server_pid = ensure_topic_server_started(topic)

    result = GenServer.call(topic_server_pid, :subscribers)

    {:reply, result, state}
  end
end
