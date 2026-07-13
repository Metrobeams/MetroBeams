defmodule PlataformaWeb.AgentEnrollmentController do
  use PlataformaWeb, :controller

  alias Plataforma.Agents

  @device_fields ~w(machine_id hostname platform architecture agent_version)

  def create(conn, params) do
    case Map.fetch(params, "enrollment_token") do
      {:ok, enrollment_token} -> enroll(conn, enrollment_token, params)
      :error -> render_validation_error(conn, %{enrollment_token: ["can't be blank"]})
    end
  end

  defp enroll(conn, enrollment_token, params) do
    attrs = Map.take(params, @device_fields)

    case Agents.enroll_agent(enrollment_token, attrs) do
      {:ok, %{agent: agent, credential: credential}} ->
        conn
        |> put_status(:created)
        |> render(:show, agent: agent, credential: credential)

      {:error, :invalid_enrollment_token} ->
        render_error(
          conn,
          :unauthorized,
          "invalid_enrollment_token",
          "Enrollment token is invalid"
        )

      {:error, :agent_inactive} ->
        render_error(conn, :conflict, "agent_inactive", "Agent is inactive")

      {:error, :enrollment_conflict} ->
        render_error(
          conn,
          :conflict,
          "enrollment_conflict",
          "Agent enrollment conflicted with another request"
        )

      {:error, %Ecto.Changeset{} = changeset} ->
        render_validation_error(conn, errors_on(changeset))
    end
  end

  defp render_validation_error(conn, details) do
    conn
    |> put_status(:bad_request)
    |> render(:error,
      code: "invalid_request",
      message: "Request validation failed",
      details: details
    )
  end

  defp render_error(conn, status, code, message) do
    conn
    |> put_status(status)
    |> render(:error, code: code, message: message)
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
