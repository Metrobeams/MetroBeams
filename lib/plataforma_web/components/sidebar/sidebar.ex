defmodule PlataformaWeb.Sidebar do
  use PlataformaWeb, :html

  attr :current_path, :string, required: true

  def sidebar(assigns) do
    ~H"""
    <aside id="app-sidebar" class="sidebar-panel flex flex-col" data-sidebar-panel>
      <div class="sidebar-brand flex items-center justify-center px-4 py-4">
        <.link
          href={~p"/"}
          class="sidebar-brand-link flex min-w-0 items-center justify-center"
          title="MetroBeams"
        >
          <span class="sidebar-label truncate text-sm font-semibold text-white">MetroBeams</span>
        </.link>

        <button
          type="button"
          id="sidebar-collapse-toggle"
          class="sidebar-collapse-control hidden size-8 shrink-0 place-items-center md:grid"
          aria-label="Recolher menu lateral"
          aria-controls="app-sidebar"
          aria-expanded="true"
          data-sidebar-collapse
        >
          <span class="transition-transform" data-sidebar-collapse-icon>
            <.icon name="hero-chevron-double-left" class="size-4" />
          </span>
        </button>
      </div>

      <nav class="sidebar-navigation flex-1 px-3" aria-label="Navegação principal">
        <.sidebar_link
          id="sidebar-home-link"
          href={~p"/"}
          icon="hero-home"
          label="Início"
          active={@current_path == "/"}
        />
        <.sidebar_link
          id="sidebar-assets-link"
          href={~p"/asset-categories"}
          icon="hero-tag"
          label="Categorias"
          active={String.starts_with?(@current_path, "/asset-categories")}
        />
        <.sidebar_link
          id="sidebar-settings-link"
          href={~p"/users/settings"}
          icon="hero-cog-6-tooth"
          label="Configurações"
          active={String.starts_with?(@current_path, "/users/settings")}
        />
      </nav>
    </aside>
    """
  end

  attr :id, :string, required: true
  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :method, :string, default: nil
  attr :active, :boolean, default: false

  defp sidebar_link(assigns) do
    ~H"""
    <.link
      id={@id}
      navigate={@href}
      method={@method}
      title={@label}
      aria-current={@active && "page"}
      class={[
        "sidebar-link flex items-center gap-3 px-3 py-2.5 text-sm",
        "hover:bg-[#393939] hover:text-white",
        @active && "active bg-[#262626] text-white shadow-[inset_3px_0_0_#0f62fe]"
      ]}
    >
      <.icon name={@icon} class="size-5 shrink-0" />
      <span class="sidebar-label">{@label}</span>
    </.link>
    """
  end
end
