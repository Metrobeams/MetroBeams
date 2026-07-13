defmodule PlataformaWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use PlataformaWeb, :html

  import PlataformaWeb.OrganizationComponents, only: [organizations: 1]

  embed_templates "page_html/*"
end
