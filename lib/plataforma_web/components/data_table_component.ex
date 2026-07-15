defmodule PlataformaWeb.DataTableComponent do
  @moduledoc """
  Data Table component following Carbon Design System patterns.
  Supports: basic, selectable, expandable, sortable, paginated variants.
  """
  use PlataformaWeb, :html

  @doc """
  Renders a Carbon-style data table.

  ## Attributes
  - `id` - Unique identifier
  - `title` - Table title
  - `description` - Optional description
  - `headers` - List of %{key, label, sortable?} maps
  - `rows` - List of data rows
  - `empty_icon` - Icon name for empty state
  - `empty_message` - Message when no data
  - `empty_action_label` - Label for empty state action
  - `empty_action_path` - Path for empty state action
  - `zebra` - Enable zebra stripes (default: true)
  - `selectable` - Enable row selection
  - `selected_ids` - List of selected row IDs
  - `row_id_key` - Key to extract row ID (default: :id)
  - `sort_by` - Current sort field
  - `sort_dir` - Current sort direction (:asc or :desc)
  - `page` - Current page number
  - `page_size` - Items per page
  - `total_count` - Total items count
  - `slot :row` - Custom row rendering
  - `slot :actions` - Toolbar actions
  - `slot :batch_actions` - Batch action buttons
  """
  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, default: nil
  attr :headers, :list, required: true
  attr :rows, :list, required: true
  attr :empty_icon, :string, default: "hero-inbox"
  attr :empty_message, :string, default: "Nenhum registro encontrado."
  attr :empty_action_label, :string, default: nil
  attr :empty_action_path, :string, default: nil
  attr :zebra, :boolean, default: true
  attr :selectable, :boolean, default: false
  attr :selected_ids, :list, default: []
  attr :row_id_key, :atom, default: :id
  attr :sort_by, :string, default: nil
  attr :sort_dir, :atom, default: :asc
  attr :page, :integer, default: 1
  attr :page_size, :integer, default: 10
  attr :total_count, :integer, default: 0

  slot :actions
  slot :batch_actions
  slot :row, required: true

  def carbon_data_table(assigns) do
    total_pages = max(ceil(assigns.total_count / assigns.page_size), 1)

    assigns =
      assigns
      |> assign(:total_pages, total_pages)

    ~H"""
    <div id={@id} class="data-table-container">
      <%!-- Title and description --%>
      <div class="mb-4">
        <h2 class="text-xl font-semibold text-[#161616] dark:text-[#f4f4f4]">
          {@title}
        </h2>
        <%= if @description do %>
          <p class="mt-1 text-sm text-[#525252] dark:text-[#c6c6c6]">
            {@description}
          </p>
        <% end %>
      </div>

      <%!-- Toolbar --%>
      <div class="flex items-center justify-between border-b border-[#e0e0e0] bg-[#f4f4f4] px-4 py-3 dark:border-[#525252] dark:bg-[#393939]">
        <div class="flex items-center gap-2">
          <%= if @selectable and @selected_ids != [] do %>
            <span class="text-sm text-[#161616] dark:text-[#f4f4f4]">
              {length(@selected_ids)} item(s) selected
            </span>
            <div class="h-4 w-px bg-[#c6c6c6] dark:bg-[#525252]"></div>
          <% end %>
          <div class="flex items-center gap-2">
            {render_slot(@actions)}
          </div>
        </div>

        <%= if @selectable and @selected_ids != [] do %>
          <div class="flex items-center gap-2">
            {render_slot(@batch_actions)}
          </div>
        <% end %>
      </div>

      <%!-- Table --%>
      <div class="overflow-x-auto">
        <table class="w-full border-collapse">
          <thead>
            <tr class="border-b border-[#e0e0e0] bg-[#f4f4f4] dark:border-[#525252] dark:bg-[#393939]">
              <%= if @selectable do %>
                <th class="w-12 px-4 py-3">
                  <input
                    type="checkbox"
                    class="h-4 w-4 rounded border-[#6f6f6f] text-[#0f62fe] focus:ring-[#0f62fe]"
                    checked={all_selected?(@rows, @selected_ids, @row_id_key)}
                    indeterminate={some_selected?(@rows, @selected_ids, @row_id_key)}
                    phx-click="toggle-all"
                  />
                </th>
              <% end %>
              <%= for header <- @headers do %>
                <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-[#6f6f6f]">
                  <%= if header.sortable? do %>
                    <button
                      type="button"
                      class="flex items-center gap-1 hover:text-[#161616] dark:hover:text-[#f4f4f4]"
                      phx-click="sort"
                      phx-value-field={header.key}
                    >
                      {header.label}
                      <span class="flex flex-col">
                        <.icon
                          name="hero-chevron-up"
                          class={[
                            "size-3",
                            @sort_by == header.key and @sort_dir == :asc && "text-[#0f62fe]",
                            @sort_by != header.key && "text-[#c6c6c6]"
                          ]}
                        />
                        <.icon
                          name="hero-chevron-down"
                          class={[
                            "size-3 -mt-1",
                            @sort_by == header.key and @sort_dir == :desc && "text-[#0f62fe]",
                            @sort_by != header.key && "text-[#c6c6c6]"
                          ]}
                        />
                      </span>
                    </button>
                  <% else %>
                    {header.label}
                  <% end %>
                </th>
              <% end %>
              <th class="w-20 px-4 py-3 text-right text-xs font-semibold uppercase tracking-wider text-[#6f6f6f]">
                Ações
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-[#e0e0e0] dark:divide-[#525252]">
            <%= if Enum.empty?(@rows) do %>
              <tr>
                <td
                  colspan={length(@headers) + (@selectable && 1 || 0) + 1}
                  class="px-4 py-12 text-center"
                >
                  <.icon name={@empty_icon} class="mx-auto size-8 text-[#8d8d8d]" />
                  <p class="mt-3 text-sm text-[#525252] dark:text-[#c6c6c6]">
                    {@empty_message}
                  </p>
                  <%= if @empty_action_label and @empty_action_path do %>
                    <.link
                      href={@empty_action_path}
                      class="mt-3 inline-block text-sm font-semibold text-[#0f62fe] hover:underline"
                    >
                      {@empty_action_label}
                    </.link>
                  <% end %>
                </td>
              </tr>
            <% else %>
              <%= for row <- @rows, index <- 0..(length(@rows) - 1) do %>
                <tr
                  class={[
                    "hover:bg-[#f4f4f4] dark:hover:bg-[#393939] transition-colors",
                    @zebra && rem(index, 2) == 1 && "bg-[#f4f4f4] dark:bg-[#262626]"
                  ]}
                >
                  <%= if @selectable do %>
                    <td class="w-12 px-4 py-3">
                      <input
                        type="checkbox"
                        class="h-4 w-4 rounded border-[#6f6f6f] text-[#0f62fe] focus:ring-[#0f62fe]"
                        checked={Map.get(row, @row_id_key) in @selected_ids}
                        phx-click="toggle-row"
                        phx-value-id={Map.get(row, @row_id_key)}
                      />
                    </td>
                  <% end %>
                  {render_slot(@row, row)}
                  <td class="px-4 py-3 text-right">
                    <slot name="row_actions" row={row}>
                      <%!-- Default empty --%>
                    </slot>
                  </td>
                </tr>
              <% end %>
            <% end %>
          </tbody>
        </table>
      </div>

      <%!-- Pagination --%>
      <%= if @total_count > @page_size do %>
        <div class="flex items-center justify-between border-t border-[#e0e0e0] bg-[#f4f4f4] px-4 py-3 dark:border-[#525252] dark:bg-[#393939]">
          <span class="text-xs text-[#6f6f6f]">
            Mostrando {(@page - 1) * @page_size + 1} a {min(@page * @page_size, @total_count)} de {@total_count} registros
          </span>
          <div class="flex items-center gap-1">
            <button
              type="button"
              disabled={@page <= 1}
              phx-click="page"
              phx-value-page={@page - 1}
              class="inline-flex items-center justify-center h-8 w-8 rounded-none border border-[#393939] bg-transparent text-[#161616] hover:bg-[#f4f4f4] disabled:cursor-not-allowed disabled:opacity-50 dark:text-[#f4f4f4] dark:hover:bg-[#393939]"
            >
              <.icon name="hero-chevron-left" class="size-4" />
            </button>

            <%= for p <- 1..@total_pages do %>
              <%= if p == @page do %>
                <button
                  type="button"
                  class="inline-flex items-center justify-center h-8 w-8 rounded-none bg-[#0f62fe] text-sm font-semibold text-white"
                >
                  {p}
                </button>
              <% else %>
                <button
                  type="button"
                  phx-click="page"
                  phx-value-page={p}
                  class="inline-flex items-center justify-center h-8 w-8 rounded-none border border-[#393939] bg-transparent text-sm text-[#161616] hover:bg-[#f4f4f4] dark:text-[#f4f4f4] dark:hover:bg-[#393939]"
                >
                  {p}
                </button>
              <% end %>
            <% end %>

            <button
              type="button"
              disabled={@page >= @total_pages}
              phx-click="page"
              phx-value-page={@page + 1}
              class="inline-flex items-center justify-center h-8 w-8 rounded-none border border-[#393939] bg-transparent text-[#161616] hover:bg-[#f4f4f4] disabled:cursor-not-allowed disabled:opacity-50 dark:text-[#f4f4f4] dark:hover:bg-[#393939]"
            >
              <.icon name="hero-chevron-right" class="size-4" />
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp all_selected?(rows, selected_ids, row_id_key) do
    row_ids = Enum.map(rows, &Map.get(&1, row_id_key))
    row_ids != [] and MapSet.subset?(MapSet.new(row_ids), MapSet.new(selected_ids))
  end

  defp some_selected?(rows, selected_ids, row_id_key) do
    row_ids = Enum.map(rows, &Map.get(&1, row_id_key))
    selected = MapSet.intersection(MapSet.new(row_ids), MapSet.new(selected_ids))
    MapSet.size(selected) > 0 and not all_selected?(rows, selected_ids, row_id_key)
  end
end
