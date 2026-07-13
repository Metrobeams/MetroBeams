defmodule PlataformaWeb.OrganizationHTML do
  use PlataformaWeb, :html

  attr :form, Phoenix.HTML.Form, required: true
  attr :action, :string, required: true
  attr :method, :string, default: "post"
  attr :submit_label, :string, required: true

  def organization_form(assigns) do
    ~H"""
    <.form
      for={@form}
      id="organization-form"
      action={@action}
      method={@method}
      class="mt-8 space-y-6"
    >
      <.input
        field={@form[:name]}
        id="organization-name"
        type="text"
        label="Nome da organização"
        autocomplete="organization"
        placeholder="Ex.: Empresa Acme"
        minlength="2"
        maxlength="120"
        required
        class={[
          "w-full rounded-lg border border-slate-300 bg-white px-4 py-3 text-sm text-slate-950",
          "shadow-sm outline-none transition placeholder:text-slate-400",
          "focus:border-blue-600 focus:ring-2 focus:ring-blue-600/20"
        ]}
        error_class="border-red-600 focus:border-red-600 focus:ring-red-600/20"
      />

      <div class="flex flex-col-reverse gap-3 border-t border-slate-200 pt-6 sm:flex-row sm:justify-end">
        <.link
          href={~p"/"}
          class={[
            "inline-flex min-h-11 items-center justify-center rounded-lg border border-slate-300 px-5 py-2.5",
            "text-sm font-semibold text-slate-700 transition hover:bg-slate-50",
            "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-600"
          ]}
        >
          Cancelar
        </.link>
        <button
          id="organization-submit"
          type="submit"
          class={[
            "inline-flex min-h-11 items-center justify-center gap-2 rounded-lg bg-blue-600 px-5 py-2.5",
            "text-sm font-semibold text-white transition hover:bg-blue-700",
            "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-600"
          ]}
        >
          {@submit_label}
          <.icon name="hero-arrow-right" class="size-4" />
        </button>
      </div>
    </.form>
    """
  end

  embed_templates "organization_html/*"
end
