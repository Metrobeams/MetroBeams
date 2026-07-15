defmodule PlataformaWeb.DataTableComponents do
  @moduledoc """
  Helper components for DataTable rows and cells.
  """
  use PlataformaWeb, :html

  @doc """
  Renders a table cell with consistent styling.

  ## Attributes
  - `class` - Additional CSS classes
  - `truncate` - Truncate long text (default: true)
  - `slot :inner_block` - Cell content
  """
  attr :class, :string, default: ""
  attr :truncate, :boolean, default: true

  def carbon_cell(assigns) do
    ~H"""
    <td class={[
      "px-4 py-3 text-sm text-[#161616] dark:text-[#f4f4f4]",
      @truncate && "max-w-[200px] truncate",
      @class
    ]}>
      {render_slot(@inner_block)}
    </td>
    """
  end

  @doc """
  Renders a table cell with a link.

  ## Attributes
  - `href` - Link URL
  - `class` - Additional CSS classes
  - `slot :inner_block` - Link text
  """
  attr :href, :string, required: true
  attr :class, :string, default: ""

  def carbon_cell_link(assigns) do
    ~H"""
    <td class="px-4 py-3 text-sm">
      <.link
        href={@href}
        class={[
          "text-[#0f62fe] hover:underline",
          @class
        ]}
      >
        {render_slot(@inner_block)}
      </.link>
    </td>
    """
  end

  @doc """
  Renders a table cell with a badge/tag.

  ## Attributes
  - `color` - Badge background color (hex)
  - `text_color` - Badge text color (default: white)
  - `class` - Additional CSS classes
  - `slot :inner_block` - Badge text
  """
  attr :color, :string, required: true
  attr :text_color, :string, default: "#ffffff"
  attr :class, :string, default: ""

  def carbon_cell_badge(assigns) do
    ~H"""
    <td class="px-4 py-3 text-sm">
      <span
        class={[
          "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
          @class
        ]}
        style={"background-color: #{@color}; color: #{@text_color}"}
      >
        {render_slot(@inner_block)}
      </span>
    </td>
    """
  end

  @doc """
  Renders a table cell with icon and text.

  ## Attributes
  - `icon` - Heroicon name
  - `icon_color` - Icon color (default: currentColor)
  - `class` - Additional CSS classes
  - `slot :inner_block` - Text content
  """
  attr :icon, :string, required: true
  attr :icon_color, :string, default: nil
  attr :class, :string, default: ""

  def carbon_cell_with_icon(assigns) do
    ~H"""
    <td class="px-4 py-3 text-sm">
      <span class="flex items-center gap-2">
        <.icon
          name={@icon}
          class={[
            "size-4 shrink-0",
            @icon_color && "text-[#{@icon_color}]"
          ]}
        />
        <span class={@class}>{render_slot(@inner_block)}</span>
      </span>
    </td>
    """
  end

  @doc """
  Renders a table cell with empty state placeholder.

  ## Attributes
  - `class` - Additional CSS classes
  """
  attr :class, :string, default: ""

  def carbon_cell_empty(assigns) do
    ~H"""
    <td class={[
      "px-4 py-3 text-sm text-[#6f6f6f] dark:text-[#a1a1a1]",
      @class
    ]}>
      -
    </td>
    """
  end
end
