defmodule PlataformaWeb.AgentEnrollmentJSON do
  alias Plataforma.Agents.Agent

  def show(%{agent: %Agent{} = agent, credential: credential}) do
    %{
      data: %{
        agent_id: agent.id,
        credential: credential
      }
    }
  end

  def error(%{code: code, message: message, details: details}) do
    %{error: %{code: code, message: message, details: details}}
  end

  def error(%{code: code, message: message}) do
    %{error: %{code: code, message: message}}
  end
end
