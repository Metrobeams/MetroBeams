defmodule PlataformaWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use PlataformaWeb, :html

  alias PlataformaWeb.NotificationIcons
  alias PlataformaWeb.NotificationCloseButton

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  attr :current_path, :string,
    default: "/",
    doc: "the current request path for active link detection"

  attr :content_class, :any,
    default: "max-w-2xl",
    doc: "additional classes controlling the main content width"

  attr :main_class, :any,
    default: "px-4 py-20 sm:px-6 lg:px-8",
    doc: "classes controlling the main page spacing"

  attr :notification_summary, :map, default: %{unread_count: 0, notifications: []}

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <%= if @current_scope do %>
      <div id="carbon-shell">
        <input type="checkbox" id="sidebar-toggle" class="sidebar-toggle peer sr-only" />
        <label for="sidebar-toggle" class="sidebar-backdrop" />

        <div id="carbon-sidebar" class={["flex"]}>
          <.sidebar current_scope={@current_scope} current_path={@current_path} />
          <div class={["flex-1 min-w-0 flex flex-col"]}>
            <.app_header
              current_scope={@current_scope}
              notification_summary={@notification_summary}
            />
            <main class={["flex-1", @main_class]}>
              <div id="app-content" class={["mx-auto w-full space-y-4", @content_class]}>
                <.flash_group flash={@flash} />
                {render_slot(@inner_block)}
              </div>
            </main>
          </div>
        </div>
      </div>
    <% else %>
      <main class={@main_class}>
        <div id="app-content" class={["mx-auto w-full space-y-4", @content_class]}>
          <.flash_group flash={@flash} />
          {render_slot(@inner_block)}
        </div>
      </main>
    <% end %>
    """
  end

  attr :current_scope, :map, required: true
  attr :notification_summary, :map, required: true

  def app_header(assigns) do
    ~H"""
    <header id="carbon-header">
      <div class="flex items-center justify-between h-14 px-4 pr-6">
        <div class="flex items-center gap-3">
          <label
            for="sidebar-toggle"
            class="header-icon-btn md:hidden"
            aria-label="Menu"
          >
            <.icon name="hero-bars-3" class="size-5" />
          </label>
        </div>

        <div class="flex items-center gap-2">
          <button
            type="button"
            id="header-search-toggle"
            class="header-icon-btn"
            aria-label="Buscar"
          >
            <.icon name="hero-magnifying-glass" class="size-5" />
          </button>

          <div id="header-notifications" class="relative">
            <button
              type="button"
              id="header-notifications-toggle"
              class="header-icon-btn"
              aria-label={notification_label(@notification_summary.unread_count)}
              aria-expanded="false"
              aria-haspopup="true"
              aria-controls="header-notifications-menu"
              data-notifications-toggle
            >
              <.icon name="hero-bell" class="size-5" />
              <span
                :if={@notification_summary.unread_count > 0}
                id="header-notifications-badge"
                class="notification-badge"
                data-unread-count={@notification_summary.unread_count}
                aria-hidden="true"
              >
                {notification_badge(@notification_summary.unread_count)}
              </span>
            </button>

            <div
              id="header-notifications-menu"
              class={[
                "hidden absolute right-0 top-full mt-2 w-[22rem] max-w-[calc(100vw-2rem)] bg-white border border-[#e0e0e0] shadow-lg z-50",
                "dark:bg-[#262626] dark:border-[#525252]"
              ]}
              role="region"
              aria-label="Notificações recentes"
              data-notifications-menu
            >
              <div class="flex items-center justify-between border-b border-[#e0e0e0] px-4 py-3 dark:border-[#525252]">
                <p class="text-sm font-semibold text-[#161616] dark:text-[#f4f4f4]">
                  Notificações
                </p>
                <span class="text-xs text-[#6f6f6f] dark:text-[#c6c6c6]">
                  {@notification_summary.unread_count} não lidas
                </span>
              </div>

              <div
                :if={Enum.empty?(@notification_summary.notifications)}
                id="header-notifications-empty"
                class="px-5 py-8 text-center"
              >
                <.icon name="hero-bell" class="mx-auto size-6 text-[#8d8d8d]" />
                <p class="mt-3 text-sm text-[#525252] dark:text-[#c6c6c6]">
                  Nenhuma notificação.
                </p>
              </div>

              <ul
                :if={not Enum.empty?(@notification_summary.notifications)}
                class="max-h-96 divide-y divide-[#e0e0e0] overflow-y-auto dark:divide-[#525252]"
              >
                <li
                  :for={notification <- @notification_summary.notifications}
                  id={"header-notification-#{notification.id}"}
                  class={[
                    "flex items-start gap-3 px-4 py-3 border-l-2",
                    is_nil(notification.read_at) && "bg-[#edf5ff] dark:bg-[#001d6c]",
                    notification_status_border(notification.status)
                  ]}
                >
                  <div class="flex-shrink-0 mt-0.5">
                    <NotificationIcons.status_icon status={notification.status || :info} />
                  </div>
                  <.form
                    for={%{}}
                    action={~p"/notifications/#{notification.id}/read"}
                    method="patch"
                    class="flex-1 min-w-0"
                  >
                    <button
                      type="submit"
                      class="flex w-full items-start gap-3 text-left focus-visible:outline-2 focus-visible:outline-offset-[-2px] focus-visible:outline-[#0f62fe]"
                    >
                      <span class="min-w-0">
                        <span class={[
                          "block truncate text-sm text-[#161616] dark:text-[#f4f4f4]",
                          is_nil(notification.read_at) && "font-semibold"
                        ]}>
                          {notification.title}
                        </span>
                        <span class="mt-1 line-clamp-2 block text-xs leading-5 text-[#525252] dark:text-[#c6c6c6]">
                          {notification.body}
                        </span>
                      </span>
                    </button>
                  </.form>
                  <div class="flex-shrink-0 mt-0.5">
                    <NotificationCloseButton.close_button
                      notification_id={notification.id}
                      action={~p"/notifications/#{notification.id}/read"}
                    />
                  </div>
                </li>
              </ul>

              <div class="flex items-center justify-between border-t border-[#e0e0e0] px-4 py-3 dark:border-[#525252]">
                <.form
                  :if={@notification_summary.unread_count > 0}
                  for={%{}}
                  action={~p"/notifications/read-all"}
                  method="patch"
                  id="header-notifications-read-all"
                >
                  <button type="submit" class="text-xs font-semibold text-[#0f62fe] hover:underline">
                    Marcar todas como lidas
                  </button>
                </.form>
                <span :if={@notification_summary.unread_count == 0}></span>
                <.link
                  id="header-notifications-view-all"
                  href={~p"/notifications"}
                  class="text-xs font-semibold text-[#0f62fe] hover:underline"
                >
                  Ver todas
                </.link>
              </div>
            </div>
          </div>

          <div class="relative">
            <button
              type="button"
              id="header-user-menu-toggle"
              class="flex items-center gap-2.5 px-3 py-1.5 rounded-sm transition-colors hover:bg-[#f4f4f4] dark:hover:bg-[#393939]"
              aria-label="Menu do usuário"
              aria-expanded="false"
              aria-controls="header-user-menu"
            >
              <span class="flex size-8 items-center justify-center rounded-full bg-[#0f62fe] text-xs font-semibold text-white">
                {user_initial(@current_scope.user)}
              </span>
              <span
                data-user-display-name
                class="hidden max-w-40 truncate text-sm font-medium text-[#161616] dark:text-[#f4f4f4] md:block"
              >
                {user_display_name(@current_scope.user)}
              </span>
              <.icon name="hero-chevron-down" class="size-4 text-[#525252] dark:text-[#c6c6c6]" />
            </button>

            <div
              id="header-user-menu"
              class={[
                "hidden absolute right-0 top-full mt-2 w-56 bg-white border border-[#e0e0e0] shadow-lg z-50",
                "dark:bg-[#262626] dark:border-[#525252]"
              ]}
            >
              <div class="px-4 py-3 border-b border-[#e0e0e0] dark:border-[#525252]">
                <p class="truncate text-sm font-semibold text-[#161616] dark:text-[#f4f4f4]">
                  {user_display_name(@current_scope.user)}
                </p>
                <p class="text-sm font-medium text-[#161616] dark:text-[#f4f4f4] truncate">
                  {@current_scope.user.email}
                </p>
              </div>
              <.link
                href={~p"/users/settings"}
                class="flex items-center gap-3 px-4 py-3 text-sm text-[#161616] hover:bg-[#f4f4f4] dark:text-[#f4f4f4] dark:hover:bg-[#393939]"
              >
                <.icon name="hero-user" class="size-4 text-[#525252] dark:text-[#c6c6c6]" />
                Minha conta
              </.link>
              <.link
                href={~p"/users/settings"}
                class="flex items-center gap-3 px-4 py-3 text-sm text-[#161616] hover:bg-[#f4f4f4] dark:text-[#f4f4f4] dark:hover:bg-[#393939]"
              >
                <.icon name="hero-shield-check" class="size-4 text-[#525252] dark:text-[#c6c6c6]" />
                Segurança
              </.link>
              <div class="border-t border-[#e0e0e0] dark:border-[#525252]"></div>
              <.link
                href={~p"/users/log-out"}
                method="delete"
                class="flex items-center gap-3 px-4 py-3 text-sm text-[#da1e28] hover:bg-[#fda2af]/20"
              >
                <.icon name="hero-arrow-right-on-rectangle" class="size-4" /> Sair
              </.link>
            </div>
          </div>
        </div>
      </div>
    </header>

    <script>
      document.addEventListener("DOMContentLoaded", function() {
        var toggle = document.getElementById("header-user-menu-toggle");
        var menu = document.getElementById("header-user-menu");

        if (toggle && menu) {
          toggle.addEventListener("click", function(e) {
            e.stopPropagation();
            var isOpen = !menu.classList.contains("hidden");
            menu.classList.toggle("hidden");
            toggle.setAttribute("aria-expanded", !isOpen);
            toggle.classList.toggle("bg-[#f4f4f4]", !isOpen);
          });

          document.addEventListener("click", function(e) {
            if (!menu.contains(e.target) && !toggle.contains(e.target)) {
              menu.classList.add("hidden");
              toggle.setAttribute("aria-expanded", "false");
              toggle.classList.remove("bg-[#f4f4f4]");
            }
          });
        }
      });
    </script>
    """
  end

  defp notification_badge(count) when count > 99, do: "99+"
  defp notification_badge(count), do: Integer.to_string(count)

  defp notification_label(0), do: "Notificações, nenhuma não lida"

  defp notification_label(count) do
    "Notificações, #{count} não lidas"
  end

  defp user_display_name(%{name: name}) when is_binary(name) and name != "", do: name
  defp user_display_name(_user), do: "Usuário"

  defp user_initial(user) do
    user |> user_display_name() |> String.first() |> String.upcase()
  end

  @status_border_colors %{
    error: "border-l-[#da1e28]",
    warning: "border-l-[#f1c21b]",
    success: "border-l-[#24a148]",
    info: "border-l-[#0f62fe]"
  }

  defp notification_status_border(status) when is_atom(status),
    do: @status_border_colors[status] || "border-l-[#0f62fe]"

  defp notification_status_border(_), do: "border-l-[#0f62fe]"

  attr :current_scope, :map, required: true
  attr :current_path, :string, required: true

  defp sidebar(assigns) do
    ~H"""
    <aside class="flex flex-col">
      <div class="px-4 py-4">
        <.link href={~p"/"} class="flex items-center gap-2">
          <span class="grid size-8 place-items-center bg-[#0f62fe] text-white">
            <.icon name="hero-building-office-2" class="size-4" />
          </span>
          <span class="text-sm font-semibold text-white">Plataforma</span>
        </.link>
      </div>

      <nav class="flex-1 px-3">
        <.sidebar_link href={~p"/"} icon="hero-home" label="Início" active={@current_path == "/"} />
        <.sidebar_link
          href={~p"/users/settings"}
          icon="hero-cog-6-tooth"
          label="Configurações"
          active={String.starts_with?(@current_path, "/users/settings")}
        />
      </nav>
    </aside>
    """
  end

  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :method, :string, default: nil
  attr :active, :boolean, default: false

  defp sidebar_link(assigns) do
    ~H"""
    <.link
      navigate={@href}
      method={@method}
      class={[
        "flex items-center gap-3 px-3 py-2.5 text-sm",
        "hover:bg-[#393939] hover:text-white",
        @active && "bg-[#262626] text-white shadow-[inset_3px_0_0_#0f62fe]"
      ]}
    >
      <.icon name={@icon} class="size-5 shrink-0" />
      <span>{@label}</span>
    </.link>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 [[data-theme-source=system]_&]:!left-0 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
