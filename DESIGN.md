# DESIGN.md — MetroBeams Chatbot

## 1. Objective

O chatbot deve ser uma assistente discreta e eficiente que ajuda usuários a navegar na plataforma, resolver dúvidas sobre ativos e agents, e conectar-se com suporte humano quando necessário. A experiência deve ser fluida, não intrusiva, e seguir fielmente o Carbon Design System.

## 2. Product Context

- **What the product does:** Assistente virtual integrada para suporte e navegação da plataforma MetroBeams
- **Who it's for:** Técnicos e administradores que gerenciam ativos e agents
- **Adjacent brands (feel like these):** IBM Watson Assistant, Intercom, Drift
- **Distant brand (do not feel like this):** ChatGPT (não é um chat aberto, é uma ferramenta de suporte contextual)
- **Cultural register:** Técnico e profissional — linguagem direta, sem rodeios

## 3. Visual Foundations

### 3a. Color

- **Neutral scale:** `--n-50: #f4f4f4, --n-100: #e0e0e0, --n-200: #c6c6c6, --n-300: #a1a1a1, --n-400: #8d8d8d, --n-500: #6f6f6f, --n-600: #525252, --n-700: #393939, --n-800: #262626, --n-900: #161616`
- **Accent:** `--accent-primary: #0f62fe` (Carbon Blue 60)
- **Semantic:** `--success: #24a148, --warning: #f1c21b, --error: #da1e28, --info: #0043ce`
- **Usage rules:** Accent apenas em botões primários e links. Mensagens do bot usam fundo `--n-800` com texto `--n-100`. Mensagens do usuário usam fundo `--accent-primary` com texto branco.

### 3b. Typography

- **Display face:** IBM Plex Sans
- **Body face:** IBM Plex Sans
- **Fallback stack:** -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif
- **Type scale:** 12 / 14 / 16 / 18 / 24 px
- **Weight discipline:** Regular (400) para corpo, Semibold (600) para headings e labels, Bold (700) para destaques

### 3c. Spacing & rhythm

- **Base unit:** 8 px
- **Spacing scale:** 4, 8, 12, 16, 24, 32, 48, 64 px
- **Padding do chat:** 16px entre mensagens, 24px padding do container

### 3d. Component seeds

- **Button:** Primary (preenchido), Secondary (borda), Ghost (sem estilo), Danger (vermelho)
- **Card:** Bordas de 1px `--n-200`, fundo branco, sem sombra (Carbon flat style)
- **Iconography:** Heroicons (optimized), peso "solid"
- **Input:** Bordas 1px `--n-300`, focus ring `--accent-primary`

## 4. Accessibility

- **Text contrast:** 4.5:1 mínimo para texto, 3:1 para UI
- **Motion:** Respeita `prefers-reduced-motion`
- **Focus indicators:** Focus ring de 2px `--accent-primary` com offset de 2px
- **Alt text:** Descriptivo para avatares, decorativo para ícones
- **Keyboard navigation:** Tab entre elementos, Enter/Space para ações
- **Screen reader:** aria-live para novas mensagens, aria-label para botões

## 5. Voice & Tone

- **Register:** Técnico e profissional
- **Sentence rhythm:** Frases curtas e diretas
- **Words this brand uses:** "assistir", "verificar", "configurar", "solucionar"
- **Words this brand refuses:** "seamless", "elevate", "journey", "unlock", "delight"
- **Address:** "você" (tom direto e profissional)

## 6. Implementation Practices

- **Token format:** CSS variables (Carbon tokens)
- **Component library:** Phoenix Components + Tailwind CSS
- **Image treatment:** Avatares quadrados (Carbon style), sem bordas arredondadas
- **Grid system:** Flexbox para layout do chat
- **Motion:** Transições de 200ms ease-out para abertura/fechamento

## 7. Anti-Patterns

- **No chat pop-up aleatório.** O bot só aparece quando o usuário clica no botão de abertura.
- **No typing indicator falso.** Se o bot não está processando, não mostre "digitando..."
- **No bot genérico.** Respostas devem ser contextuais à plataforma MetroBeams.
- **No chat fullscreen.** O chat é um painel lateral ou flutuante, nunca cobre a tela inteira.
- **No bot que fala sozinho.** O bot só envia mensagens em resposta a ações do usuário.

## 8. Decision-Making

1. **Carbon Design System.** Seguir os padrões Carbon em caso de conflito com outras decisões.
2. **Acessibilidade.** A11y tem precedência sobre estética.
3. **Discrição.** O chat não deve atrapalhar o fluxo de trabalho do usuário.
4. **Performance.** Respostas devem ser rápidas; mostrar feedback visual durante processamento.
5. **Consistência.** Seguir o padrão visual existente da plataforma.

## 9. Workflow

1. Verificar se o DESIGN.md existe (Move 0)
2. Identificar o designer identity (Product UI Designer)
3. Criar componentes base (botão de abertura, container do chat)
4. Implementar mensagens (bot, usuário, sistema)
5. Adicionar input do usuário
6. Implementar estados de carregamento e erro
7. Adicionar acessibilidade (aria, keyboard, focus)
8. Testar em diferentes tamanhos de tela
