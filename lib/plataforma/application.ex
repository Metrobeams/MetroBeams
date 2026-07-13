defmodule Plataforma.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PlataformaWeb.Telemetry,
      Plataforma.Repo,
      {DNSCluster, query: Application.get_env(:plataforma, :dns_cluster_query) || :ignore},
      {Oban, Application.fetch_env!(:plataforma, Oban)},
      {Phoenix.PubSub, name: Plataforma.PubSub},
      # Start a worker by calling: Plataforma.Worker.start_link(arg)
      # {Plataforma.Worker, arg},
      # Start to serve requests, typically the last entry
      PlataformaWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Plataforma.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PlataformaWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
