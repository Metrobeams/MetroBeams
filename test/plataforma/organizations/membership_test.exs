defmodule Plataforma.Organizations.MembershipTest do
  use Plataforma.DataCase, async: true

  alias Plataforma.Organizations.Membership

  test "validates roles and trims optional fields" do
    changeset =
      Membership.changeset(%Membership{organization_id: Ecto.UUID.generate(), user_id: 1}, %{
        role: :admin,
        job_title: "  Analista  ",
        department: "  Operações  ",
        employee_code: "  A-01  "
      })

    assert changeset.valid?
    assert get_change(changeset, :job_title) == "Analista"
    assert get_change(changeset, :department) == "Operações"
    assert get_change(changeset, :employee_code) == "A-01"
  end

  test "requires tenant, user, role and active" do
    changeset = Membership.changeset(%Membership{}, %{active: nil, role: :invalid})

    refute changeset.valid?
    assert %{organization_id: [_], user_id: [_], role: [_], active: [_]} = errors_on(changeset)
  end
end
