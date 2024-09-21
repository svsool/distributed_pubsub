defmodule DPS.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      DPSWeb.Telemetry,
      {Cluster.Supervisor,
       [Application.get_env(:libcluster, :topologies) || [], [name: DPS.ClusterSupervisor]]},
      {Phoenix.PubSub, name: DPS.PubSub},
      DPSWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: DPS.Supervisor]

    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    DPSWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
