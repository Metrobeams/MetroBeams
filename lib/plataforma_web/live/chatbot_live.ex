defmodule PlataformaWeb.ChatbotLive do
  use PlataformaWeb, :live_view

  alias PlataformaWeb.ChatbotComponent

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       chat_open: false,
       messages: [],
       input_value: "",
       is_typing: false,
       threads: [%{id: "main", name: "Suporte MetroBeams", unread: 0}],
       active_thread: "main"
     )}
  end

  def handle_event("toggle_chat", _params, socket) do
    {:noreply, assign(socket, chat_open: !socket.assigns.chat_open)}
  end

  def handle_event("send_message", %{"message" => message}, socket) do
    if String.trim(message) == "" do
      {:noreply, socket}
    else
      user_msg = %{
        id: Ecto.UUID.generate(),
        role: :user,
        content: message,
        timestamp: DateTime.utc_now()
      }

      messages = socket.assigns.messages ++ [user_msg]

      send(self(), {:bot_response, message})

      {:noreply,
       assign(socket,
         messages: messages,
         input_value: "",
         is_typing: true
       )}
    end
  end

  def handle_info({:bot_response, user_message}, socket) do
    # Simular delay de processamento
    Process.send_after(self(), {:send_bot_reply, user_message}, 1000)
    {:noreply, socket}
  end

  def handle_info({:send_bot_reply, user_message}, socket) do
    bot_reply = generate_bot_response(user_message)

    bot_msg = %{
      id: Ecto.UUID.generate(),
      role: :bot,
      content: bot_reply,
      timestamp: DateTime.utc_now()
    }

    messages = socket.assigns.messages ++ [bot_msg]

    {:noreply,
     assign(socket,
       messages: messages,
       is_typing: false
     )}
  end

  defp generate_bot_response(message) do
    cond do
      String.contains?(String.downcase(message), ["olá", "oi", "bom dia", "boa tarde"]) ->
        "Olá! Sou a assistente MetroBeams. Como posso ajudar você hoje?"

      String.contains?(String.downcase(message), ["agente", "agent", "enrollment"]) ->
        "Para configurar um agent, você precisa de um token de enrollment. Posso ajudar com as etapas de instalação?"

      String.contains?(String.downcase(message), ["ativo", "asset", "categoria"]) ->
        "Posso ajudar com cadastro de ativos. Você quer criar uma categoria, listar ativos ou verificar fabricantes?"

      String.contains?(String.downcase(message), ["fornecedor", "supplier"]) ->
        "Para cadastrar fornecedores, acesse o menu lateral em Assets > Fornecedores. Posso ajudar com algo específico?"

      String.contains?(String.downcase(message), ["humano", "pessoa", "suporte"]) ->
        "Vou conectar você com um membro da nossa equipe. Um momento..."

      true ->
        "Entendi sua dúvida. Posso ajudar com:\n\n• Configuração de agents\n• Gerenciamento de ativos\n• Cadastro de fornecedores\n• Categorias e fabricantes\n\nO que você precisa?"
    end
  end

  def render(assigns) do
    ~H"""
    <ChatbotComponent.chatbot
      chat_open={@chat_open}
      messages={@messages}
      input_value={@input_value}
      is_typing={@is_typing}
      threads={@threads}
      active_thread={@active_thread}
    />
    """
  end
end
