defmodule PlataformaWeb.OrganizationComponents do
  use PlataformaWeb, :html

  # Vendored paths keep the official Carbon icons available in server-rendered templates.
  @carbon_icon_paths %{
    add: ["M17 15 17 8 15 8 15 15 8 15 8 17 15 17 15 24 17 24 17 17 24 17 24 15z"],
    checkmark_outline: [
      "M14 21.414 9 16.413 10.413 15 14 18.586 21.585 11 23 12.415 14 21.414z",
      "M16,2A14,14,0,1,0,30,16,14,14,0,0,0,16,2Zm0,26A12,12,0,1,1,28,16,12,12,0,0,1,16,28Z"
    ],
    edit: [
      "M2 26H30V28H2z",
      "M25.4,9c0.8-0.8,0.8-2,0-2.8c0,0,0,0,0,0l-3.6-3.6c-0.8-0.8-2-0.8-2.8,0c0,0,0,0,0,0l-15,15V24h6.4L25.4,9z M20.4,4L24,7.6 l-3,3L17.4,7L20.4,4z M6,22v-3.6l10-10l3.6,3.6l-10,10H6z"
    ],
    email: [
      "M28,6H4A2,2,0,0,0,2,8V24a2,2,0,0,0,2,2H28a2,2,0,0,0,2-2V8A2,2,0,0,0,28,6ZM25.8,8,16,14.78,6.2,8ZM4,24V8.91l11.43,7.91a1,1,0,0,0,1.14,0L28,8.91V24Z"
    ],
    enterprise: [
      "M8 8H10V12H8z",
      "M8 14H10V18H8z",
      "M14 8H16V12H14z",
      "M14 14H16V18H14z",
      "M8 20H10V24H8z",
      "M14 20H16V24H14z",
      "M30,14a2,2,0,0,0-2-2H22V4a2,2,0,0,0-2-2H4A2,2,0,0,0,2,4V30H30ZM4,4H20V28H4ZM22,28V14h6V28Z"
    ],
    security: [
      "M14 16.59 11.41 14 10 15.41 14 19.41 22 11.41 20.59 10 14 16.59z",
      "M16,30,9.8242,26.7071A10.9818,10.9818,0,0,1,4,17V4A2.0021,2.0021,0,0,1,6,2H26a2.0021,2.0021,0,0,1,2,2V17a10.9818,10.9818,0,0,1-5.8242,9.7071ZM6,4V17a8.9852,8.9852,0,0,0,4.7656,7.9423L16,27.7333l5.2344-2.791A8.9852,8.9852,0,0,0,26,17V4Z"
    ]
  }

  attr :organizations, :list, required: true

  def organizations(assigns) do
    ~H"""
    <section id="user-home-organizations" class={["mt-16"]}>
      <div class={[
        "grid grid-cols-1 gap-y-4 border-b border-[var(--carbon-gray-20)] pb-8",
        "md:grid-cols-8 md:gap-x-4 lg:grid-cols-16"
      ]}>
        <div class={["md:col-span-6 lg:col-span-12"]}>
          <p class={["text-xs font-semibold uppercase tracking-[0.16em] text-[var(--carbon-blue-60)]"]}>
            Seus acessos
          </p>
          <h2 class={["mt-2 text-3xl font-light text-[var(--carbon-gray-100)]"]}>
            Organizações
          </h2>
          <p class={["mt-2 text-sm leading-6 text-[var(--carbon-gray-50)]"]}>
            Somente organizações ativas vinculadas à sua conta aparecem aqui.
          </p>
        </div>
        <.link
          href={~p"/organizations/new"}
          id="organization-create-link"
          class={[
            "inline-flex min-h-12 items-center justify-between gap-4 bg-[var(--carbon-blue-60)] px-4 py-3",
            "text-sm font-semibold text-white transition-colors hover:bg-[var(--carbon-blue-70)]",
            "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[var(--carbon-blue-60)]",
            "md:col-span-2 md:self-end lg:col-span-4"
          ]}
        >
          Criar organização <.carbon_icon name={:add} size={16} />
        </.link>
      </div>

      <%= if @organizations == [] do %>
        <div
          id="user-home-empty"
          class={[
            "mt-8 border border-[var(--carbon-gray-20)] bg-white"
          ]}
        >
          <div class={["grid gap-4 p-4 sm:grid-cols-[auto_1fr] sm:items-center"]}>
            <span class={[
              "grid size-12 place-items-center bg-[var(--carbon-gray-10)] text-[var(--carbon-blue-60)]"
            ]}>
              <.carbon_icon name={:email} size={24} />
            </span>
            <div>
              <h3 class={["text-lg font-light text-[var(--carbon-gray-100)]"]}>
                Nenhuma organização disponível
              </h3>
              <p class={["mt-2 max-w-2xl text-sm leading-6 text-[var(--carbon-gray-50)]"]}>
                Quando você criar uma organização ou aceitar um convite, ela aparecerá neste painel automaticamente.
              </p>
            </div>
          </div>
        </div>
      <% else %>
        <ul
          id="organization-grid"
          class={["mt-8 grid grid-cols-1 gap-8 sm:grid-cols-2 xl:grid-cols-4"]}
        >
          <li
            :for={%{organization: organization} = organization_card <- @organizations}
            class={["min-w-0"]}
          >
            <article
              id={"user-organization-#{organization.id}"}
              data-organization-card
              class={[
                "group flex min-h-64 h-full flex-col border border-[var(--carbon-gray-20)] bg-white p-4",
                "transition-colors hover:border-[var(--carbon-blue-60)]"
              ]}
            >
              <div class={["flex items-start justify-between gap-4"]}>
                <span class={[
                  "grid size-8 place-items-center text-[var(--carbon-gray-100)] transition-colors",
                  "group-hover:text-[var(--carbon-blue-60)]"
                ]}>
                  <.carbon_icon name={:enterprise} size={20} />
                </span>
                <span class={[
                  "inline-flex items-center gap-2 text-xs font-medium text-[var(--carbon-green-50)]"
                ]}>
                  <.carbon_icon name={:checkmark_outline} size={16} /> Ativa
                </span>
              </div>
              <h3 class={["mt-8 truncate text-lg font-light text-[var(--carbon-gray-100)]"]}>
                {organization.name}
              </h3>
              <p class={["mt-2 truncate text-sm text-[var(--carbon-gray-50)]"]}>
                /{organization.slug}
              </p>
              <div class={[
                "mt-auto flex items-center justify-between gap-4 border-t border-[var(--carbon-gray-20)] pt-4"
              ]}>
                <span class={[
                  "text-xs font-medium uppercase tracking-[0.12em] text-[var(--carbon-gray-50)]"
                ]}>
                  Acesso autorizado
                </span>
                <.link
                  :if={organization_card.editable?}
                  href={~p"/organizations/#{organization}/edit"}
                  id={"organization-edit-#{organization.id}"}
                  class={[
                    "inline-flex items-center gap-2 text-sm font-semibold text-[var(--carbon-blue-60)]",
                    "transition-colors hover:text-[var(--carbon-blue-70)]",
                    "focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-[var(--carbon-blue-60)]"
                  ]}
                >
                  Editar <.carbon_icon name={:edit} size={16} />
                </.link>
                <.carbon_icon
                  :if={!organization_card.editable?}
                  name={:security}
                  size={16}
                  class="text-[var(--carbon-blue-60)]"
                />
              </div>
            </article>
          </li>
        </ul>
      <% end %>
    </section>
    """
  end

  attr :name, :atom, required: true
  attr :size, :integer, required: true
  attr :class, :any, default: nil

  defp carbon_icon(assigns) do
    assigns = assign(assigns, :paths, Map.fetch!(@carbon_icon_paths, assigns.name))

    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 32 32"
      width={@size}
      height={@size}
      fill="currentColor"
      class={@class}
      data-carbon-icon={@name}
      aria-hidden="true"
      focusable="false"
    >
      <path :for={path <- @paths} d={path} />
    </svg>
    """
  end
end
