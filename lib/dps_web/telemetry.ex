defmodule DPSWeb.Telemetry.Logger do
  use GenServer

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    :ok = init_telemetry()

    {:ok, opts}
  end

  def init_telemetry do
    :telemetry.attach_many(
      __MODULE__,
      [
        [:dps, :socket, :connect],
        [:dps, :topic_server, :join],
        [:dps, :topic_server, :publish],
        [:dps, :topic_server, :leave],
        [:dps, :topic_client, :publish],
        [:dps, :topic_channel, :join],
        [:dps, :topic_channel, :publish],
        [:dps, :topic_channel, :handle_out]
      ],
      &handle_event/4,
      nil
    )
  end

  def format_measurements(measurements) do
    duration = Map.get(measurements, :duration, nil)

    if duration do
      %{measurements | duration: System.convert_time_unit(duration, :native, :microsecond)}
    else
      measurements
    end
  end

  def handle_event(
        event,
        measurements,
        metadata,
        _config
      ) do
    Logger.info("#{inspect(event)} - #{inspect(measurements)} - #{inspect(metadata)}")
  end
end

defmodule DPSWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    Supervisor.init(
      [
        # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()},
        DPSWeb.Telemetry.Logger
      ],
      strategy: :one_for_one
    )
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.start.system_time",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_joined.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_handled_in.duration",
        tags: [:event],
        unit: {:native, :millisecond}
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io"),

      # DPS
      counter("dps.topic_server.join.count"),
      counter("dps.topic_server.publish.count"),
      counter("dps.topic_server.leave.count"),
      counter("dps.topic_client.publish.count"),
      counter("dps.topic_channel.join.count"),
      counter("dps.topic_channel.publish.count"),
      counter("dps.topic_channel.handle_out.count")
    ]
  end
end
