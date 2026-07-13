defmodule Plataforma.Organizations.OrganizationTest do
  use Plataforma.DataCase, async: true

  alias Plataforma.Organizations.Organization

  describe "changeset/2" do
    test "normalizes name and generates an accented slug" do
      changeset = Organization.changeset(%Organization{}, %{name: "  Prefeitura de Santarém  "})

      assert changeset.valid?
      assert get_change(changeset, :name) == "Prefeitura de Santarém"
      assert get_change(changeset, :slug) == "prefeitura-de-santarem"
    end

    test "normalizes an explicit slug and preserves a persisted slug on name changes" do
      explicit =
        Organization.changeset(%Organization{}, %{
          name: "Empresa Acme",
          slug: "Portal @ Corporativo"
        })

      assert get_change(explicit, :slug) == "portal-corporativo"

      persisted = %Organization{name: "Antigo", slug: "slug-estavel"}
      renamed = Organization.changeset(persisted, %{name: "Novo nome"})

      refute get_change(renamed, :slug)
      assert get_field(renamed, :slug) == "slug-estavel"
    end

    test "validates required fields, lengths, settings and active" do
      changeset =
        Organization.changeset(%Organization{}, %{
          name: "x",
          slug: "x",
          settings: "invalid",
          active: nil
        })

      refute changeset.valid?
      assert %{name: [_], slug: [_], settings: [_], active: [_]} = errors_on(changeset)
    end
  end
end
