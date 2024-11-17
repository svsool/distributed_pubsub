defmodule DPS.Application do
  @moduledoc false

  use Application

  alias ExHashRing.Ring

  @impl true
  def start(_type, _args) do
    do_start(Application.get_env(:dps, :app))
  end

  # start only websocket server
  def do_start(:ws) do
    children = [
      DPSWeb.Telemetry,
      %{id: :pg, start: {:pg, :start_link, [DPS.PG]}},
      {ExHashRing.Ring, name: DPS.Ring},
      {Cluster.Supervisor,
       [Application.get_env(:libcluster, :topologies) || [], [name: DPS.ClusterSupervisor]]},
      {Phoenix.PubSub, name: DPS.PubSub},
      {DynamicSupervisor, name: DPS.TopicServer.DynamicSupervisor, strategy: :one_for_one},
      DPS.TopicClient.Supervisor,
      DPSWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: DPS.Supervisor]

    {:ok, _pid} = result = Supervisor.start_link(children, opts)

    nodes = Application.get_env(:dps, DPS.TopicServer)[:nodes]

    unless nodes do
      raise "No nodes configured for the topic server"
    end

    {:ok, _} = Ring.add_nodes(DPS.Ring, nodes |> Enum.map(&String.to_atom/1))

    DPS.TopicServer.Utils.join(self())

    result
  end

  # start only topic server
  def do_start(:ts) do
    children = [
      DPSWeb.Telemetry,
      %{id: :pg, start: {:pg, :start_link, [DPS.PG]}},
      {Cluster.Supervisor,
       [Application.get_env(:libcluster, :topologies) || [], [name: DPS.ClusterSupervisor]]},
      {DynamicSupervisor, name: DPS.TopicServer.DynamicSupervisor, strategy: :one_for_one},
      DPS.TopicServer.Supervisor
    ]

    opts = [strategy: :one_for_one, name: DPS.Supervisor]

    {:ok, _pid} = result = Supervisor.start_link(children, opts)

    result
  end

  def do_start(:all) do
    children = [
      DPSWeb.Telemetry,
      %{id: :pg, start: {:pg, :start_link, [DPS.PG]}},
      {ExHashRing.Ring, name: DPS.Ring},
      {Cluster.Supervisor,
       [Application.get_env(:libcluster, :topologies) || [], [name: DPS.ClusterSupervisor]]},
      {Phoenix.PubSub, name: DPS.PubSub},
      {DynamicSupervisor, name: DPS.TopicServer.DynamicSupervisor, strategy: :one_for_one},
      DPS.TopicClient.Supervisor,
      DPS.TopicServer.Supervisor,
      DPSWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: DPS.Supervisor]

    {:ok, _pid} = result = Supervisor.start_link(children, opts)

    nodes = Application.get_env(:dps, DPS.TopicServer)[:nodes]

    unless nodes do
      raise "No nodes configured for the topic server"
    end

    {:ok, _} = Ring.add_nodes(DPS.Ring, nodes |> Enum.map(&String.to_atom/1))

    result
  end

  @impl true
  def config_change(changed, _new, removed) do
    DPSWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
