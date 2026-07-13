defmodule Plataforma.Repo do
  use Ecto.Repo,
    otp_app: :plataforma,
    adapter: Ecto.Adapters.Postgres
end
