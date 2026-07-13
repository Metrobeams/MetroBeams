# Backlog do Módulo de Assets — MetroBeams

## Objetivo

Construir o módulo inicial de gestão de ativos do MetroBeams, preservando:

- isolamento multi-tenant;
- autorização no servidor;
- histórico de movimentações;
- operações críticas transacionais;
- desenvolvimento orientado a testes;
- Phoenix Controller + HEEx + Tailwind;
- nenhuma dependência nova sem necessidade.

---

## Epic 1 — Cadastros estruturantes

### 1. Especificação do domínio de assets

Definir antes da implementação:

- entidades iniciais;
- relacionamentos;
- regras de autorização;
- campos obrigatórios;
- estados do ativo;
- regras de unicidade;
- comportamento de exclusão e desativação;
- estratégia de histórico;
- escopo do MVP.

### 2. Categorias de ativos

Exemplos:

- Notebook
- Desktop
- Monitor
- Impressora
- Celular
- Servidor

Funcionalidades:

- listar por organização;
- criar;
- editar;
- impedir nomes duplicados na mesma organização;
- permitir o mesmo nome em organizações diferentes;
- aplicar autorização e isolamento cross-tenant.

Campos iniciais:

```text
name
description
```

### 3. Fabricantes

Exemplos:

- Dell
- Lenovo
- Apple
- Samsung

Funcionalidades:

- listar;
- criar;
- editar;
- impedir duplicidade por organização.

Campos iniciais:

```text
name
website
support_url
```

### 4. Modelos de ativos

O modelo representa o produto, não o equipamento individual.

Exemplo:

```text
Categoria: Notebook
Fabricante: Dell
Modelo: Latitude 5440
```

Campos iniciais:

```text
name
model_number
category_id
manufacturer_id
notes
```

Regras:

- categoria e fabricante devem pertencer à mesma organização;
- IDs de outro tenant devem resultar em `404`;
- o formulário não deve receber `organization_id`.

### 5. Localizações

Exemplos:

```text
Matriz
Matriz / Segundo andar
Matriz / Segundo andar / Desenvolvimento
```

Campos iniciais:

```text
name
parent_id
description
```

### 6. Status do ativo

Status iniciais sugeridos:

```text
available
assigned
maintenance
reserved
retired
lost
disposed
```

Usar `Ecto.Enum` ou estrutura equivalente controlada pelo domínio.

---

## Epic 2 — Gestão de ativos

### 1. Schema e migration de ativos

Campos iniciais:

```text
id
organization_id
asset_model_id
location_id
asset_tag
name
serial_number
status
purchase_date
purchase_cost
warranty_expires_at
notes
inserted_at
updated_at
```

Regras:

- `asset_tag` obrigatório;
- `asset_tag` único por organização;
- organizações diferentes podem repetir o mesmo `asset_tag`;
- `serial_number` pode ser opcional;
- modelo e localização devem pertencer ao mesmo tenant;
- `organization_id` nunca deve ser confiado a partir do formulário.

Índices iniciais:

```text
unique organization_id + asset_tag
organization_id + status
organization_id + serial_number
organization_id + asset_model_id
organization_id + location_id
```

### 2. Criar ativo

Critérios:

- formulário com somente campos permitidos;
- organização derivada da rota e da membership autenticada;
- validação de modelo e localização no mesmo tenant;
- flash e redirecionamento em sucesso;
- reapresentação do changeset em erro.

### 3. Listar ativos

Exibir inicialmente:

- asset tag;
- nome;
- categoria;
- fabricante;
- modelo;
- status;
- localização;
- responsável atual.

### 4. Visualizar ativo

A página de detalhes será o centro do módulo.

Seções iniciais:

```text
Visão geral
Atribuição atual
Histórico
Manutenções
Programas
Anexos
Compra e garantia
```

Na primeira fatia, somente a visão geral precisa estar funcional.

### 5. Editar ativo

Permitir alteração somente de campos administrativos autorizados.

Garantir:

- isolamento cross-tenant;
- validação dos relacionamentos;
- proteção contra mass assignment;
- manutenção do histórico quando necessário.

### 6. Busca, filtros e paginação

Busca por:

- nome;
- asset tag;
- número de série.

Filtros:

- status;
- categoria;
- fabricante;
- modelo;
- localização;
- responsável;
- garantia vencida.

Também incluir:

- paginação;
- ordenação.

### 7. Aposentar ou desativar ativo

Substituir a exclusão comum por uma operação de ciclo de vida.

Regras sugeridas:

- ativos com histórico não devem ser removidos fisicamente;
- usar status `retired` ou `disposed`;
- exclusão definitiva apenas para registros criados por engano e sem dependências.

---

## Epic 3 — Movimentação e responsabilidade

### 1. Check-out para usuário

Fluxo:

```text
Asset disponível
→ selecionar usuário
→ informar data prevista de devolução
→ confirmar entrega
```

### 2. Check-out para localização

Permitir atribuir o ativo a uma localização, quando aplicável.

### 3. Check-in

Fluxo:

```text
Asset atribuído
→ registrar devolução
→ escolher localização de retorno
→ alterar status para disponível
```

### 4. Atribuição atual

Exibir no detalhe do ativo:

- usuário ou localização responsável;
- data do check-out;
- previsão de devolução;
- responsável pela operação.

### 5. Histórico de atribuições

Criar tabela própria:

```text
asset_assignments
- id
- organization_id
- asset_id
- assigned_to_user_id
- assigned_to_location_id
- assigned_by_id
- checked_out_at
- expected_return_at
- checked_in_at
- checked_in_by_id
- notes
- inserted_at
- updated_at
```

Regras:

- atribuir a usuário ou localização, nunca ambos;
- check-out e check-in devem ser transacionais;
- bloquear o ativo durante a operação;
- impedir múltiplas atribuições abertas;
- preservar todo o histórico.

---

## Epic 4 — Histórico e auditoria

### 1. Timeline do ativo

Eventos iniciais:

```text
asset.created
asset.updated
asset.checked_out
asset.checked_in
asset.location_changed
asset.status_changed
asset.sent_to_maintenance
asset.returned_from_maintenance
asset.retired
asset.attachment_added
```

Estrutura sugerida:

```text
asset_events
- id
- organization_id
- asset_id
- actor_id
- event_type
- metadata
- inserted_at
```

O histórico deve ser append-only sempre que possível.

---

## Epic 5 — Manutenções e documentos

### 1. Controle de manutenção

Tipos:

```text
preventive
corrective
upgrade
inspection
```

Status:

```text
scheduled
in_progress
completed
cancelled
```

Campos iniciais:

```text
title
description
maintenance_type
status
started_at
completed_at
cost
supplier_id
```

### 2. Anexos do ativo

Exemplos:

- foto;
- nota fiscal;
- comprovante de garantia;
- termo de entrega;
- relatório de manutenção.

Reutilizar a infraestrutura MinIO.

Estrutura sugerida:

```text
organizations/{organization_id}/assets/{asset_id}/{uuid}
```

Não persistir URLs assinadas no banco.

### 3. Dados de compra e garantia

Campos:

```text
purchase_date
purchase_cost
warranty_expires_at
supplier_id
```

Alertas automáticos podem ficar para uma fase posterior.

---

## Epic 6 — Importação, exportação e relatórios

Prioridade recomendada:

1. exportação CSV;
2. importação CSV;
3. dashboard de métricas;
4. relatório de manutenções;
5. exportação PDF.

O dashboard e os relatórios devem entrar depois que os fluxos operacionais estiverem estáveis e houver dados reais.

---

## Epic 7 — Programas e agents

### 1. Catálogo de programas

Campos iniciais:

```text
name
vendor
category
website
```

### 2. Instalações manuais

Associar programas a assets com:

```text
software_product_id
asset_id
version
source
installed_at
last_seen_at
```

### 3. Agent

Primeira versão:

```text
Enrollment
Heartbeat
Inventário de hardware
Inventário de programas
```

Fora do escopo inicial:

- terminal remoto;
- execução de scripts;
- captura de tela;
- instalação remota;
- controle do dispositivo.

O agent inicial deve ser somente leitura e envio de inventário.

---

## Epic técnico

### CI obrigatório

Configurar o pipeline para executar:

```bash
mix format --check-formatted
mix compile --warnings-as-errors
mix test
mix assets.build
mix precommit
```

### Segurança e qualidade

Adicionar tarefas para:

- testes de isolamento cross-tenant;
- testes de UUID inválido;
- testes de concorrência em check-out;
- auditoria de índices e constraints;
- revisão de mass assignment;
- documentação do domínio;
- análise de payloads e limites;
- revisão das permissões por papel.

---

## Permissões iniciais

Sugestão:

```text
assets.view
assets.create
assets.update
assets.checkout
assets.checkin
assets.maintenance
assets.retire
asset_settings.manage
```

Mapeamento inicial:

| Papel | Permissões |
|---|---|
| owner | todas |
| admin | todas |
| technician | visualizar, criar, editar, check-in, check-out e manutenção |
| member | visualizar ativos atribuídos a ele |

---

## Ordem recomendada de implementação

```text
1. Especificação do domínio
2. Categorias
3. Fabricantes
4. Modelos
5. Localizações
6. Schema e migration de assets
7. Criar asset
8. Listar assets
9. Visualizar asset
10. Editar asset
11. Busca, filtros e paginação
12. Check-out
13. Check-in
14. Histórico
15. Manutenções
16. Anexos
17. Compra e garantia
18. Exportação CSV
19. Importação CSV
20. Dashboard e relatórios
21. Programas
22. Agent
```

---

## Próxima fatia recomendada

A próxima entrega deve ser:

> Cadastro de categorias de ativos por organização, com listagem, criação e edição, autorização no servidor, isolamento multi-tenant e TDD obrigatório.

Fluxo de desenvolvimento:

```text
Especificação
→ teste do context falhando
→ migration
→ schema e changeset
→ context
→ autorização
→ controller
→ HEEx
→ testes de integração
→ mix precommit
```
