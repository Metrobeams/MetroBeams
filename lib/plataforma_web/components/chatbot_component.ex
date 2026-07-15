defmodule PlataformaWeb.ChatbotComponent do
  use PlataformaWeb, :html

  attr :chat_open, :boolean, required: true
  attr :messages, :list, required: true
  attr :input_value, :string, required: true
  attr :is_typing, :boolean, required: true
  attr :threads, :list, required: true
  attr :active_thread, :string, required: true

  def chatbot(assigns) do
    ~H"""
    <div id="chatbot-container" class="fixed bottom-6 right-6 z-50">
      <!-- Botão de abertura -->
      <button
        type="button"
        id="chatbot-toggle"
        phx-click="toggle_chat"
        class={[
          "flex h-14 w-14 items-center justify-center rounded-full",
          "bg-[#0f62fe] text-white shadow-lg transition-all duration-200",
          "hover:bg-[#0353e9] focus-visible:outline-2 focus-visible:outline-offset-2",
          "focus-visible:outline-[#0f62fe]",
          @chat_open && "rotate-90 opacity-0 pointer-events-none"
        ]}
        aria-label={if @chat_open, do: "Fechar chat", else: "Abrir chat"}
      >
        <.icon name="hero-chat-bubble-left-right" class="size-6" />
      </button>

      <!-- Container do chat -->
      <div
        id="chatbot-panel"
        class={[
          "absolute bottom-0 right-0 w-[400px] max-h-[600px]",
          "flex flex-col rounded-none border border-[#e0e0e0] bg-white",
          "shadow-2xl transition-all duration-200 dark:border-[#525252] dark:bg-[#262626]",
          @chat_open && "opacity-100 translate-y-0",
          !@chat_open && "opacity-0 translate-y-4 pointer-events-none"
        ]}
        role="dialog"
        aria-label="Chat de suporte"
      >
        <!-- Header -->
        <div class="flex items-center justify-between border-b border-[#e0e0e0] bg-[#f4f4f4] px-4 py-3 dark:border-[#525252] dark:bg-[#393939]">
          <div class="flex items-center gap-3">
            <div class="flex h-8 w-8 items-center justify-center bg-[#0f62fe]">
              <.icon name="hero-chat-bubble-left-right" class="size-4 text-white" />
            </div>
            <div>
              <h2 class="text-sm font-semibold text-[#161616] dark:text-[#f4f4f4]">
                Suporte MetroBeams
              </h2>
              <p class="text-xs text-[#6f6f6f] dark:text-[#a1a1a1]">
                Online agora
              </p>
            </div>
          </div>
          <button
            type="button"
            phx-click="toggle_chat"
            class="flex h-8 w-8 items-center justify-center text-[#6f6f6f] hover:bg-[#e0e0e0] dark:text-[#a1a1a1] dark:hover:bg-[#525252]"
            aria-label="Fechar"
          >
            <.icon name="hero-x-mark" class="size-5" />
          </button>
        </div>

        <!-- Mensagens -->
        <div
          id="chatbot-messages"
          class="flex-1 overflow-y-auto p-4 space-y-4 min-h-[300px] max-h-[400px]"
          role="log"
          aria-live="polite"
          aria-label="Mensagens do chat"
        >
          <%= if Enum.empty?(@messages) do %>
            <div class="flex flex-col items-center justify-center py-8 text-center">
              <div class="flex h-12 w-12 items-center justify-center bg-[#f4f4f4] dark:bg-[#393939]">
                <.icon name="hero-hand-raised" class="size-6 text-[#0f62fe]" />
              </div>
              <p class="mt-4 text-sm font-semibold text-[#161616] dark:text-[#f4f4f4]">
                Olá! Sou a assistente MetroBeams
              </p>
              <p class="mt-1 text-xs text-[#6f6f6f] dark:text-[#a1a1a1]">
                Como posso ajudar você hoje?
              </p>
              <div class="mt-4 flex flex-wrap justify-center gap-2">
                <button
                  type="button"
                  phx-click="send_message"
                  phx-value-message="Como configurar um agent?"
                  class="rounded-none border border-[#e0e0e0] bg-white px-3 py-1.5 text-xs text-[#161616] hover:bg-[#f4f4f4] dark:border-[#525252] dark:bg-[#262626] dark:text-[#f4f4f4] dark:hover:bg-[#393939]"
                >
                  Configurar agent
                </button>
                <button
                  type="button"
                  phx-click="send_message"
                  phx-value-message="Cadastrar fornecedor"
                  class="rounded-none border border-[#e0e0e0] bg-white px-3 py-1.5 text-xs text-[#161616] hover:bg-[#f4f4f4] dark:border-[#525252] dark:bg-[#262626] dark:text-[#f4f4f4] dark:hover:bg-[#393939]"
                >
                  Cadastrar fornecedor
                </button>
                <button
                  type="button"
                  phx-click="send_message"
                  phx-value-message="Preciso de ajuda com ativos"
                  class="rounded-none border border-[#e0e0e0] bg-white px-3 py-1.5 text-xs text-[#161616] hover:bg-[#f4f4f4] dark:border-[#525252] dark:bg-[#262626] dark:text-[#f4f4f4] dark:hover:bg-[#393939]"
                >
                  Ajuda com ativos
                </button>
              </div>
            </div>
          <% else %>
            <%= for message <- @messages do %>
              <.chat_message message={message} />
            <% end %>
          <% end %>

          <%= if @is_typing do %>
            <div class="flex items-start gap-3">
              <div class="flex h-8 w-8 shrink-0 items-center justify-center bg-[#0f62fe]">
                <.icon name="hero-chat-bubble-left-right" class="size-4 text-white" />
              </div>
              <div class="rounded-none bg-[#f4f4f4] px-4 py-3 dark:bg-[#393939]">
                <div class="flex gap-1">
                  <span class="h-2 w-2 animate-bounce bg-[#6f6f6f] [animation-delay:-0.3s]"></span>
                  <span class="h-2 w-2 animate-bounce bg-[#6f6f6f] [animation-delay:-0.15s]"></span>
                  <span class="h-2 w-2 animate-bounce bg-[#6f6f6f]"></span>
                </div>
              </div>
            </div>
          <% end %>
        </div>

        <!-- Input -->
        <div class="border-t border-[#e0e0e0] bg-[#f4f4f4] p-4 dark:border-[#525252] dark:bg-[#393939]">
          <form phx-submit="send_message" class="flex gap-2">
            <input
              type="text"
              name="message"
              value={@input_value}
              placeholder="Digite sua mensagem..."
              class="flex-1 rounded-none border border-[#e0e0e0] bg-white px-4 py-2.5 text-sm text-[#161616] placeholder-[#6f6f6f] focus:border-[#0f62fe] focus:outline-none dark:border-[#525252] dark:bg-[#262626] dark:text-[#f4f4f4] dark:placeholder-[#a1a1a1]"
              aria-label="Mensagem"
            />
            <button
              type="submit"
              class="flex h-10 w-10 shrink-0 items-center justify-center bg-[#0f62fe] text-white hover:bg-[#0353e9] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#0f62fe]"
              aria-label="Enviar mensagem"
            >
              <.icon name="hero-paper-airplane" class="size-5" />
            </button>
          </form>
        </div>
      </div>
    </div>
    """
  end

  attr :message, :map, required: true

  defp chat_message(assigns) do
    is_user = assigns.message.role == :user

    assigns =
      assigns
      |> assign(:is_user, is_user)
      |> assign(:formatted_time, format_time(assigns.message.timestamp))

    ~H"""
    <div class={[
      "flex items-start gap-3",
      @is_user && "flex-row-reverse"
    ]}>
      <%= if @is_user do %>
        <div class="flex h-8 w-8 shrink-0 items-center justify-center bg-[#393939]">
          <.icon name="hero-user" class="size-4 text-white" />
        </div>
      <% else %>
        <div class="flex h-8 w-8 shrink-0 items-center justify-center bg-[#0f62fe]">
          <.icon name="hero-chat-bubble-left-right" class="size-4 text-white" />
        </div>
      <% end %>

      <div class={[
        "max-w-[280px] rounded-none px-4 py-3",
        @is_user && "bg-[#0f62fe] text-white",
        !@is_user && "bg-[#f4f4f4] text-[#161616] dark:bg-[#393939] dark:text-[#f4f4f4]"
      ]}>
        <p class="whitespace-pre-wrap text-sm">{@message.content}</p>
        <p class={[
          "mt-1 text-xs",
          @is_user && "text-white/70",
          !@is_user && "text-[#6f6f6f] dark:text-[#a1a1a1]"
        ]}>
          {@formatted_time}
        </p>
      </div>
    </div>
    """
  end

  defp format_time(timestamp) do
    Calendar.strftime(timestamp, "%H:%M")
  end
end
