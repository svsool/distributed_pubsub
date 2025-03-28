defmodule DPS.Application do
  use Application

  @impl true
  def start(_type, _args) do
    do_start(Application.get_env(:dps, :app))
  end

  defp resolve_nodes do
    nodes = Application.get_env(:dps, DPS.TopicServer)[:nodes]

    unless nodes do
      raise "No nodes configured for the topic server"
    end

    nodes
  end

  # start only websocket server
  @spec do_start(:ws) :: {:ok, pid()} | {:error, term()}
  def do_start(:ws) do
    children = [
      DPSWeb.Telemetry,
      %{id: :pg, start: {:pg, :start_link, [DPS.PG]}},
      {ExHashRing.Ring, name: DPS.Ring, nodes: resolve_nodes()},
      {Cluster.Supervisor,
       [Application.get_env(:libcluster, :topologies) || [], [name: DPS.ClusterSupervisor]]},
      # drains 25% of connections every 100ms by default, can be adjusted if needed
      {SocketDrano, refs: :all},
      {Phoenix.PubSub, name: DPS.PubSub},
      {DynamicSupervisor, name: DPS.TopicServer.DynamicSupervisor, strategy: :one_for_one},
      DPSWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: DPS.Supervisor]

    {:ok, _pid} = result = Supervisor.start_link(children, opts)

    DPS.TopicRouter.join_process_group(self())

    result
  end

  # start only topic server
  @spec do_start(:ts) :: {:ok, pid()} | {:error, term()}
  def do_start(:ts) do
    children = [
      DPSWeb.Telemetry,
      %{id: :pg, start: {:pg, :start_link, [DPS.PG]}},
      {Cluster.Supervisor,
       [Application.get_env(:libcluster, :topologies) || [], [name: DPS.ClusterSupervisor]]},
      {DynamicSupervisor, name: DPS.TopicServer.DynamicSupervisor, strategy: :one_for_one},
      {Registry, keys: :unique, name: DPS.TopicRegistry},
      DPS.TopicServer.Worker.Supervisor
    ]

    opts = [strategy: :one_for_one, name: DPS.Supervisor]

    {:ok, _pid} = result = Supervisor.start_link(children, opts)

    result
  end

  @spec do_start(:all) :: {:ok, pid()} | {:error, term()}
  def do_start(:all) do
    children = [
      DPSWeb.Telemetry,
      %{id: :pg, start: {:pg, :start_link, [DPS.PG]}},
      {ExHashRing.Ring, name: DPS.Ring, nodes: resolve_nodes()},
      {Cluster.Supervisor,
       [Application.get_env(:libcluster, :topologies) || [], [name: DPS.ClusterSupervisor]]},
      # drains 25% of connections every 100ms by default, can be adjusted if needed
      {SocketDrano, refs: :all},
      {Phoenix.PubSub, name: DPS.PubSub},
      {Registry, keys: :unique, name: DPS.TopicRegistry},
      {DynamicSupervisor, name: DPS.TopicServer.DynamicSupervisor, strategy: :one_for_one},
      DPS.TopicServer.Worker.Supervisor,
      DPSWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: DPS.Supervisor]

    {:ok, _pid} = result = Supervisor.start_link(children, opts)

    result
  end

  @impl true
  def config_change(changed, _new, removed) do
    DPSWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
