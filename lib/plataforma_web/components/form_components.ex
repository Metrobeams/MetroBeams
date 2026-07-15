defmodule PlataformaWeb.FormComponents do
  @moduledoc """
  Form components following Carbon Design System patterns.
  """
  use PlataformaWeb, :html

  @doc """
  Renders a form field with label, helper text, and error messages.
  """
  attr :id, :any, required: true
  attr :name, :any, required: true
  attr :label, :string, required: true
  attr :value, :any
  attr :type, :string, default: "text"
  attr :field, Phoenix.HTML.FormField, required: true
  attr :errors, :list, default: []
  attr :helper_text, :string, default: nil
  attr :placeholder, :string, default: nil
  attr :required, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :rest, :global, include: ~w(autocomplete min max step pattern maxlength minlength)

  def carbon_input(assigns) do
    ~H"""
    <div class="mb-8">
      <label
        for={@id}
        class="block text-sm font-semibold text-[#161616] dark:text-[#f4f4f4] mb-2"
      >
        {@label}
        <%= if @required do %>
          <span class="text-[#da1e28] ml-0.5">*</span>
        <% else %>
          <span class="text-[#6f6f6f] font-normal ml-1">(optional)</span>
        <% end %>
      </label>

      <%= if @helper_text do %>
        <p class="text-xs text-[#6f6f6f] dark:text-[#a1a1a1] mb-2">
          {@helper_text}
        </p>
      <% end %>

      <input
        type={@type}
        id={@id}
        name={@name}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        placeholder={@placeholder}
        disabled={@disabled}
        required={@required}
        class={[
          "w-full border bg-white px-4 py-3 text-sm text-[#161616] placeholder-[#6f6f6f]",
          "dark:bg-[#262626] dark:text-[#f4f4f4] dark:placeholder-[#a1a1a1]",
          "focus:outline-none focus:ring-2 focus:ring-[#0f62fe] focus:border-[#0f62fe]",
          @errors != [] && "border-[#da1e28]",
          @errors == [] && "border-[#393939] hover:border-[#6f6f6f]",
          @disabled && "bg-[#f4f4f4] text-[#c6c6c6] cursor-not-allowed dark:bg-[#393939]"
        ]}
        {@rest}
      />

      <%= for error <- @errors do %>
        <p class="mt-2 text-xs text-[#da1e28] flex items-center gap-1">
          <.icon name="hero-exclamation-circle" class="size-4" />
          {error}
        </p>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a textarea field.
  """
  attr :id, :any, required: true
  attr :name, :any, required: true
  attr :label, :string, required: true
  attr :value, :any
  attr :field, Phoenix.HTML.FormField, required: true
  attr :errors, :list, default: []
  attr :helper_text, :string, default: nil
  attr :placeholder, :string, default: nil
  attr :required, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :rows, :integer, default: 4
  attr :rest, :global, include: ~w(maxlength minlength)

  def carbon_textarea(assigns) do
    ~H"""
    <div class="mb-8">
      <label
        for={@id}
        class="block text-sm font-semibold text-[#161616] dark:text-[#f4f4f4] mb-2"
      >
        {@label}
        <%= if @required do %>
          <span class="text-[#da1e28] ml-0.5">*</span>
        <% else %>
          <span class="text-[#6f6f6f] font-normal ml-1">(optional)</span>
        <% end %>
      </label>

      <%= if @helper_text do %>
        <p class="text-xs text-[#6f6f6f] dark:text-[#a1a1a1] mb-2">
          {@helper_text}
        </p>
      <% end %>

      <textarea
        id={@id}
        name={@name}
        placeholder={@placeholder}
        disabled={@disabled}
        required={@required}
        rows={@rows}
        class={[
          "w-full border bg-white px-4 py-3 text-sm text-[#161616] placeholder-[#6f6f6f]",
          "dark:bg-[#262626] dark:text-[#f4f4f4] dark:placeholder-[#a1a1a1]",
          "focus:outline-none focus:ring-2 focus:ring-[#0f62fe] focus:border-[#0f62fe]",
          @errors != [] && "border-[#da1e28]",
          @errors == [] && "border-[#393939] hover:border-[#6f6f6f]",
          @disabled && "bg-[#f4f4f4] text-[#c6c6c6] cursor-not-allowed dark:bg-[#393939]"
        ]}
        {@rest}
      >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>

      <%= for error <- @errors do %>
        <p class="mt-2 text-xs text-[#da1e28] flex items-center gap-1">
          <.icon name="hero-exclamation-circle" class="size-4" />
          {error}
        </p>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a select field.
  """
  attr :id, :any, required: true
  attr :name, :any, required: true
  attr :label, :string, required: true
  attr :value, :any
  attr :field, Phoenix.HTML.FormField, required: true
  attr :errors, :list, default: []
  attr :helper_text, :string, default: nil
  attr :options, :list, required: true
  attr :prompt, :string, default: nil
  attr :required, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :rest, :global

  def carbon_select(assigns) do
    ~H"""
    <div class="mb-8">
      <label
        for={@id}
        class="block text-sm font-semibold text-[#161616] dark:text-[#f4f4f4] mb-2"
      >
        {@label}
        <%= if @required do %>
          <span class="text-[#da1e28] ml-0.5">*</span>
        <% else %>
          <span class="text-[#6f6f6f] font-normal ml-1">(optional)</span>
        <% end %>
      </label>

      <%= if @helper_text do %>
        <p class="text-xs text-[#6f6f6f] dark:text-[#a1a1a1] mb-2">
          {@helper_text}
        </p>
      <% end %>

      <select
        id={@id}
        name={@name}
        disabled={@disabled}
        required={@required}
        class={[
          "w-full border bg-white px-4 py-3 text-sm text-[#161616]",
          "dark:bg-[#262626] dark:text-[#f4f4f4]",
          "focus:outline-none focus:ring-2 focus:ring-[#0f62fe] focus:border-[#0f62fe]",
          @errors != [] && "border-[#da1e28]",
          @errors == [] && "border-[#393939] hover:border-[#6f6f6f]",
          @disabled && "bg-[#f4f4f4] text-[#c6c6c6] cursor-not-allowed dark:bg-[#393939]"
        ]}
        {@rest}
      >
        <%= if @prompt do %>
          <option value="">{@prompt}</option>
        <% end %>
        {Phoenix.HTML.Form.options_for_select(@options, @value)}
      </select>

      <%= for error <- @errors do %>
        <p class="mt-2 text-xs text-[#da1e28] flex items-center gap-1">
          <.icon name="hero-exclamation-circle" class="size-4" />
          {error}
        </p>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders form actions (submit and cancel buttons).
  """
  attr :submit_label, :string, required: true
  attr :cancel_path, :string, required: true
  attr :secondary_label, :string, default: "Cancelar"

  def carbon_form_actions(assigns) do
    ~H"""
    <div class="flex flex-col gap-4 sm:flex-row sm:justify-end pt-4 border-t border-[#e0e0e0] dark:border-[#525252]">
      <.link
        href={@cancel_path}
        class="inline-flex items-center justify-center rounded-none border border-[#393939] bg-transparent px-6 py-3 text-sm font-semibold text-[#161616] transition-colors hover:bg-[#f4f4f4] hover:border-[#6f6f6f] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#0f62fe] dark:text-[#f4f4f4] dark:hover:bg-[#393939]"
      >
        {@secondary_label}
      </.link>

      <button
        type="submit"
        class="inline-flex items-center justify-center rounded-none border-0 bg-[#0f62fe] px-6 py-3 text-sm font-semibold text-white transition-colors hover:bg-[#0353e9] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#0f62fe]"
      >
        {@submit_label}
      </button>
    </div>
    """
  end

  @doc """
  Renders a form header with title and description.
  """
  attr :title, :string, required: true
  attr :description, :string, default: nil
  attr :section, :string, default: nil

  def carbon_form_header(assigns) do
    ~H"""
    <div class="mb-8">
      <%= if @section do %>
        <p class="text-xs font-semibold uppercase tracking-[0.16em] text-[#0f62fe]">
          {@section}
        </p>
      <% end %>
      <h1 class="mt-2 text-3xl font-light tracking-tight text-[#161616] dark:text-[#f4f4f4]">
        {@title}
      </h1>
      <%= if @description do %>
        <p class="mt-2 text-sm text-[#525252] dark:text-[#c6c6c6]">
          {@description}
        </p>
      <% end %>
    </div>
    """
  end
end
