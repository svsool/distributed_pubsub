defmodule DPS.MixProject do
  use Mix.Project

  def project do
    [
      app: :dps,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      dialyzer: dialyzer()
    ]
  end

  defp extra_applications(:dev), do: [:observer, :wx]
  defp extra_applications(_), do: []

  def application do
    [
      mod: {DPS.Application, []},
      extra_applications: [:logger, :runtime_tools] ++ extra_applications(Mix.env())
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.7.14"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:bandit, "~> 1.5"},
      {:libcluster, "~> 3.4.1"},
      {:ex_hash_ring, "~> 6.0"},
      {:manifold, "~> 1.5"},
      {:plug_cowboy, "~> 2.5"},
      {:socket_drano, "~> 0.5"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"],
      quality: ["compile --warnings-as-errors", "format", "credo --strict", "dialyzer"]
    ]
  end

  defp dialyzer() do
    plt_core_path = "_build/#{Mix.env()}"

    [
      plt_core_path: plt_core_path,
      plt_file: {:no_warn, "#{plt_core_path}/dialyzer.plt"}
    ]
  end
end
