# Sprint 4 — Arquivo (Arquivador) — Busca, navegação e reordenação

**Status: CONCLUÍDA.** Este documento registra o que foi implementado e
validado ao longo da Sprint 4 da especificação v5.1 (RF05, RF06.1), mais
três mudanças de escopo decididas durante a sprint: **data ao lado de cada
mensagem**, **detalhes da mensagem por gesto** e **reordenação de
mensagens**.

> Os documentos `SPRINT_0_CHANGES.md` a `SPRINT_3_CHANGES.md` descrevem
> estados anteriores. Em caso de divergência, vale este arquivo.

---

## Decisões de escopo

| Decisão | Resultado |
|---|---|
| Natureza da busca na conversa | A lista **nunca é filtrada**: toda busca **leva ao ponto da conversa** onde a mensagem foi postada (com destaque temporário) |
| Texto | Ignora **maiúsculas e acentos** ("jose" acha "José") |
| Busca por palavra (4.4) | **Na conversa**: destaque no balão, contador `n/total`, setas ▲▼ para saltar entre ocorrências |
| Lista de resultados (4.5) | Tela separada (`SearchResultsScreen`) com filtros combináveis de texto, tipo, tag e faixa de datas; toque leva ao local |
| Busca por data (4.3/4.6) | **Simples**: vai para a primeira mensagem do dia. **Faixa**: lista de mensagens com seleção e ações em lote |
| Filtros (4.5) | Tipo e tag, vários ao mesmo tempo, combináveis. "Ou" dentro da categoria, "e" entre categorias |
| Ações em lote (4.6) | Definir/remover tag, editar data e excluir |
| Legenda de imagem/vídeo (4.4) | Nome de exibição sob a miniatura, com destaque se casar |
| Acesso à pesquisa | Botão ⋮ no canto superior direito do chat, com **Pesquisar** e **Gerenciar tags** |
| Busca por título (Home) | Lupa na AppBar; única busca que atravessa Conversas |
| Data da mensagem | Ao lado esquerdo de cada mensagem; com tag, dentro da fita |
| Detalhes da mensagem | Arrastar a mensagem (ou a fita) para a **esquerda** abre a folha de detalhes |
| Reordenação | Segurar e mover na vertical, direto no chat. A data viaja com a mensagem |
| Schema | **Inalterado (v4)** |
| Plano B de reordenação (modo "Reordenar" pelo ⋮) | Ignorado |

---

## Etapas executadas

| Etapa | Entrega | Status |
|---|---|---|
| 4.0 | Fundação em Dart puro: normalização de texto, `MessageFilter`, função de busca | Concluída |
| 4.1 | Busca por título na Home (RF06.1) | Concluída |
| 4.2 | Navegação: `ScrollablePositionedList`, "ir para a mensagem" com destaque | Concluída |
| 4.3 | Menu ⋮ com Pesquisar e busca por **data simples** | Concluída |
| A2 | Layout: data ao lado de cada mensagem, sem separadores | Concluída |
| A3 | Detalhes da mensagem por swipe para a esquerda | Concluída |
| A4.1 | `reorderMessage` no repositório | Concluída |
| A4.2 | Gesto de segurar e mover | Concluída |
| A4.3 | Rolagem automática, vibração e desfazer | Concluída |
| A4.4 | "Mover para o início/fim" no menu de ações | Concluída |
| 4.4 | Busca por palavra na conversa (destaque, contador, setas) e legenda de mídia | Concluída |
| 4.5 | Lista de resultados única com filtros combináveis (texto, tipo, tag, data) | Concluída |
| 4.6 | Faixa de datas com seleção e ações em lote (tag, data, excluir) | Concluída |
| 4.7 | Fechamento: filtros, analyze, atualização deste documento | Concluída |

---

## Dependências

```yaml
dependencies:
  scrollable_positioned_list: ^0.3.8
  flutter_localizations:
    sdk: flutter