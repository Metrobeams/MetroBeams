defmodule PlataformaWeb.AgentLogRedactionTest do
  use ExUnit.Case, async: true

  test "Phoenix centrally filters every agent API secret parameter" do
    params = %{
      "enrollment_token" => "enrollment-value",
      "credential" => "credential-value",
      "authorization" => "Bearer authorization-value",
      "secret" => "secret-value",
      "token" => "generic-token-value",
      "hostname" => "PC-SAFE"
    }

    filtered = Phoenix.Logger.filter_values(params)

    for key <- ~w(enrollment_token credential authorization secret token) do
      assert filtered[key] == "[FILTERED]"
    end

    assert filtered["hostname"] == "PC-SAFE"
  end
end
