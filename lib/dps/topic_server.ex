defmodule DPS.TopicServer do
  use GenServer

  import DPS.TopicRouter

  @spec verify_opts!(Keyword.t()) :: :ok
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
        subscribers: []
      },
      name: :"DPS.TopicServer.#{opts[:topic]}",
      hibernate_after: 15_000
    )
  end

  @spec subscribers(binary()) :: :ok
  def subscribers(topic) do
    {:ok, topic_server_pid} = resolve_topic_server_worker_pid(topic)

    GenServer.call(topic_server_pid, {:subscribers, topic})
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:join, subscriber_pid}, _from, state) do
    if Enum.member?(state.subscribers, subscriber_pid) do
      {:reply, :ok, state}
    else
      :telemetry.execute(
        [:dps, :topic_server, :join],
        %{},
        %{
          topic: state.topic,
          subscriber_pid: subscriber_pid
        }
      )

      Process.monitor(subscriber_pid)

      {:reply, :ok,
       %{
         state
         | subscribers: [subscriber_pid | state.subscribers]
       }}
    end
  end

  @impl true
  def handle_call({:publish, event, payload}, _from, state) do
    start = System.monotonic_time(:millisecond)

    # publish message to all subscribers grouped by their according node for traffic reduction
    Manifold.send(
      state.subscribers,
      {:publish, state.topic, event, payload}
    )

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

  @impl true
  def handle_call(:subscribers, _from, state) do
    {:reply, state.subscribers, state}
  end

  @impl true
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
           Enum.reject(state.subscribers, fn subscriber_pid ->
             subscriber_pid == pid
           end)
     }}
  end
end

defmodule DPS.TopicServer.Worker.Supervisor do
  use Supervisor

  @spec shards_number() :: non_neg_integer()
  def shards_number, do: Application.get_env(:dps, DPS.TopicServer.Worker)[:shards_number]

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children =
      for shard <- 0..(shards_number() - 1) do
        Supervisor.child_spec({DPS.TopicServer.Worker, [shard: shard]},
          id: "DPS.TopicServer.Worker.Supervisor.#{shard}"
        )
      end

    Supervisor.init(children, strategy: :one_for_one)
  end
end

defmodule DPS.TopicServer.Worker do
  use GenServer

  import DPS.TopicRouter

  @spec start_link(Keyword.t()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts,
      name: :"DPS.TopicServer.Worker.#{opts[:shard]}",
      hibernate_after: 15_000
    )
  end

  @impl true
  def init(_opts) do
    :ok = join_process_group(self())

    {:ok, %{}}
  end

  @spec ensure_topic_server_started(atom()) :: pid()
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
  def handle_call({:join, topic, subscriber_pid}, _from, state) do
    topic_server_pid = ensure_topic_server_started(topic)

    result = GenServer.call(topic_server_pid, {:join, subscriber_pid})

    {:reply, result, state}
  end

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
