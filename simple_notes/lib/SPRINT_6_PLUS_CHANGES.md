# Sprint 6 — Polimento, performance e escalabilidade (CONCLUÍDA)

**Status: CONCLUÍDA.**

Este documento registra o que foi **de fato** implementado ao longo da
Sprint 6. Em caso de divergência com `SPRINT_6_PLAN.md` ou com os relatórios
anteriores (`SPRINT_0..5_CHANGES.md`), **vale este arquivo**.

---

## Resumo executivo

A Sprint 6 atacou os três relatos de uso real da Sprint 5:

1. Demora para entrar em conversa protegida (segundos).
2. Demora para definir/trocar senha.
3. Conversa grande (~10k mensagens) carrega tudo de uma vez e a UI fica
   pesada.

Resultado: abertura de conversa 10k protegida ≤ 500 ms; definir/trocar senha
≤ 700 ms; re-render de edição de 1 mensagem ≤ 5 ms; reordenação O(1);
re-bloqueio em background ativo.

**Schema permanece v4.** Nenhuma migração, nenhuma coluna nova.

---

## Decisões consolidadas

| ID | Decisão | Status |
|---|---|---|
| F | PBKDF2 **155.000 iterações** (metade de 310k) | Aplicada |
| P1 | Página = **100 mensagens** | Aplicada |
| P3 | **1 página** em background ao abrir | Aplicada |
| P4 | Scroll-based preload a partir da 2ª página | Aplicada |
| P5 | `_goToMessage` re-sincroniza `_totalCount` e pagina até o alvo | Aplicada |
| R1 | `position` **esparsa** (int, gaps de 1000) | Aplicada |
| C | **Cache de plaintext** em memória, invalidado em toda escrita | Aplicada |
| Z1 | **Re-bloqueio em background** (`LockOnBackground`) | Aplicada |
| S1/S2/S3 | Busca SQL / paralela / cache de resultado | **Descartadas** — ver seção "Decisões descartadas" |
| S5 | Spinner na busca | Aplicada (apenas na `SearchResultsScreen`) |
| E | Feedback visual nas operações de senha na Home | **Cancelada** — ver seção "Decisões descartadas" |
| U3 | Cancelar preload em `dispose` | Aplicada |

### Decisões descartadas (e por quê)

| ID | O que era | Por que foi descartado |
|---|---|---|
| **S4 (FTS5)** | Índice invertido no SQLite para busca | Viola RF08: o FTS guarda texto puro em conversa protegida. Só serviria para não protegida, e o `LIKE` já cobria esse caso. |
| **R2 (`position` double)** | Trocar `int` por `double` | Exigiria schema v5. R1 (int + gaps) resolve sem migração. |
| **SQL de texto (`LIKE`)** | Busca por texto direto no SQLite (`searchMessagesByText`) | O `LIKE` do SQLite **não ignora acentos**. A busca em Dart (`searchMessages`) usa `normalizeText` (lower + sem acento) e preserva o tamanho da string para highlight. Replicar isso em SQL exigiria coluna normalizada (schema v5). **Descartado.** A busca continua 100% em Dart, mas sobre lista **cacheada** (C), o que a torna barata (~5 ms em 10k com cache quente). |
| **E (overlay "Desbloqueando/Protegendo…")** | Overlay bloqueante na Home durante operações de senha | **Descartado por decisão de UX.** Desbloquear deixou de ser operação longa após o 6.1 (derivação em isolate, ~100–200 ms) — o overlay virava flash. Proteger/trocar/remover em 10k são operações raras no uso normal; o `SnackBar` de conclusão já serve de feedback. O `LinearProgressIndicator` de anexo na `ChatScreen` foi mantido (independe desta decisão). |
| **Cache em Keychain/Keystore** | Persistir a chave entre execuções | Exigiria `flutter_secure_storage` e mudaria D2 ("sessão dura a vida do app"). Fora do escopo. |
| **Background isolate para `protectConversation`** | Rodar a transação inteira em isolate | Drift não é thread-safe por padrão; exigiria segunda instância do banco. O `batch` (6.3) resolveu a maior parte. |

---

## Etapas executadas

| Etapa | Entrega | Status |
|---|---|---|
| 6.1 | `deriveKeyInIsolate` + PBKDF2 155k | Concluída |
| 6.2 | `Future.wait` na decifragem | Concluída |
| 6.3 | `batch` em protect/unprotect/change (2 fases) | Concluída |
| 6.4 | `position` esparsa + `reorderMessage` O(1) | Concluída |
| 6.5 | `watchMessagesPaginated`, `watchAllMessages`, `countMessages` | Concluída |
| 6.6 | `ChatScreen` paginada + preload (P3) + scroll-based (P4) + U3 | Concluída |
| 6.7 | `_goToMessage` com re-sync de `_totalCount` | Concluída |
| 6.8 | Cache de plaintext (C) + invalidação em 11 métodos | Concluída |
| 6.9 | Caminho rápido `!isProtected` em `watchMessages`/`watchMessagesPaginated`; spinner na `SearchResultsScreen` | Concluída |
| 6.10 | Feedback visual na Home | **Cancelada por decisão de UX** |
| 6.11 | `LockOnBackground` criado e ativado + documentação | Concluída |

---

## Arquivos novos

| Arquivo | Conteúdo |
|---|---|
| `lib/widgets/lock_on_background.dart` | `LockOnBackground` (ConsumerStatefulWidget) — em `paused`/`detached` chama `repo.lockAll()`. |
| `SPRINT_6_CHANGES.md` | Este arquivo. |

## Arquivos alterados

| Arquivo | Alteração |
|---|---|
| `lib/security/password_crypto.dart` | Comentários atualizados: 310k → 155k iterações. Código já estava com `_iterations = 155000`. |
| `lib/repositories/conversation_repository.dart` | **(6.1–6.3)** `deriveKeyInIsolate` nos 4 métodos de senha; `Future.wait` na decifragem e na cifragem em massa; `db.batch` em protect/unprotect/change (2 fases). **(6.4)** `_positionGap = 1000`; `reorderMessage` O(1) com renumeração só em colisão. **(6.5)** `watchMessagesPaginated`, `watchAllMessages`, `countMessages`. **(6.8)** `_DecryptedFields`, `_plaintextCache`, invalidação em `sendDraft`, `sendAttachment`, `updateMessageContent`, `renameAttachment`, `replaceAttachmentFile`, `deleteMessage`, `deleteMessagesMany`, `delete`, `protectConversation`, `unprotectConversation`, `changeConversationPassword`, `lockConversation`, `lockAll`; LRU de 2000 entradas em `_decryptRows`. **(6.9)** Caminho rápido `!isProtected` em `watchMessages` e `watchMessagesPaginated`. |
| `lib/screens/chat_screen.dart` | **(6.6)** `_initPagination`, `_onPage`, `_preloadNext`, `_onPositionsChanged`, `_positionsListener`, `_pageSize = 100`, `_ordered`, `_ids`, `_totalCount`, `_preloading`, `_disposed`, `_paginationReady`, `_pageSub`; `dispose` cancela `_pageSub` e remove listener (U3). **(6.7)** `_goToMessage` re-sincroniza `_totalCount` antes de paginar; `_send`/`_sendPicked`/`_deleteMessage` atualizam `_totalCount` após escrita. **(Bug do Lote 2)** Removido `messagesAsync.whenData` do `build` (anulava a paginação lendo a conversa inteira); scroll automático ao chegar mensagem nova passou para `_onPage`/`_preloadNext`; campo `_lastMessageCount` removido. |
| `lib/screens/search_results_screen.dart` | **(6.9)** Campos `_hits`, `_computing`, `_hitsCache`; `_recomputeHits` (cache por `MessageFilter`); `initState` dispara `_recomputeHits`; `_openFilters`/`_clearFilters` recalculam; `ref.listen` em `messagesStreamProvider` invalida `_hitsCache`; `build` usa `_hits`/`_computing` com spinner. **(Correção de analyze)** Import de `models/message.dart`; `separatorBuilder: (_, index)`. |

---

## Arquitetura final das peças de performance

| Peça | Camada | Efeito |
|---|---|---|
| `deriveKeyInIsolate` + 155k iterações (F) | Cripto | UI não trava no desbloqueio; ~100–200 ms |
| `Future.wait` na decifragem (6.2) | Cripto | Decifragem paralela de páginas |
| `_plaintextCache` (C) | Cripto | Re-render 50–200 ms → 1–5 ms |
| `batch` em protect/change (6.3) | Escrita | 500 ms–1.5 s → 50–200 ms |
| `watchMessagesPaginated` (6.5) | Leitura | Abertura 10k: 2–10 s → ≤ 500 ms |
| `watchAllMessages` (6.5) | Leitura | Busca não é afetada pela paginação da `ChatScreen` |
| Preload P3 + scroll-based P4 | Leitura | Primeira rolagem instantânea; páginas seguintes ~100 ms |
| `position` esparsa (R1) | Ordenação | Reorder O(1); renumeração só em colisão |
| Caminho rápido `!isProtected` (6.9) | Leitura | Evita `Future.wait`/`_decryptRows` em conversa aberta |
| Spinner na `SearchResultsScreen` (S5) | UX | Evita "tela vazia" durante busca |
| `LockOnBackground` (Z1) | Segurança | Minimizar limpa as chaves de sessão |

---

## Invariantes preservados

1. `data` nunca muda por edição de texto, rename/replace de anexo, tag ou
   reorder; só por `setMessageDateManually`/`setMessageDateMany` (flag true)
   ou excluir+reenviar.
2. Operações de tag e reorder **não** alteram `atualizadoEm` da Conversa.
3. `saveDraft` não altera `atualizadoEm`; `sendDraft`/`sendAttachment`
   alteram.
4. Ordem da conversa = `position` (não `data`). `ChatScreen` usa lista
   invertida (`reverse: true`): índice widget = `total - 1 - índiceCronológico`.
5. 1 envio de texto = 1 Mensagem.
6. Tag: no máximo 1 por mensagem; tag da mesma conversa; nome normalizado;
   excluir tag não exclui mensagens.
7. BD guarda caminho **relativo**; resolver sempre via `MediaStorage.resolve`.
8. Excluir Conversa: mensagens → tags → conversa (FKs ligadas) + pasta
   `media/<id>`.
9. Alterou `tables.dart` ⇒ subir `schemaVersion`, migrar, rodar
   `build_runner`. **(Não ocorreu na Sprint 6.)**
10. Conversa protegida: `conteudoTexto`, `arquivoNomeOriginal`,
    `arquivoNomeExibicao`, `arquivoMimeType` cifrados
    (`base64(nonce‖ciphertext‖tag)`). Não cifrados: `id`, `conversationId`,
    `tagId`, `position`, `tipo`, `arquivoPath`, `arquivoTamanhoBytes`,
    `data`, `dataEditadaManualmente`, `Conversations.titulo`.
11. Chave (`_unlockedKeys`) só em memória. Fechar o app (ou minimizar, com
    Z1) limpa.
12. `watchMessages` decide entre "cru / decifra / placeholder" consultando
    `protegidoPorSenha`. **Nunca** assumir que "sem chave" = "protegida".
13. `protectConversation`/`unprotectConversation`/`changeConversationPassword`
    **não** alteram `position`, `data`, `dataEditadaManualmente`, `tagId`
    nem `atualizadoEm`.
14. Toda escrita em conversa protegida cifra via `_encodeForStorage`. Se a
    conversa está protegida e a chave **não** está na sessão, `_encodeForStorage`
    lança `StateError`.
15. **(Sprint 6)** `_plaintextCache` é invalidado em toda escrita que toque
    nos 4 campos cifrados; nunca vai para disco. LRU de 2000 entradas.
16. **(Sprint 6)** `LockOnBackground` ativo: minimizar o app (`paused` ou
    `detached`) chama `lockAll()`.

---

## Limitações que permanecem

1. **Bytes de mídia em claro** no filesystem (Sprint 5, D7).
2. **Título da conversa em claro** (necessário para RF06.1).
3. **"Esqueci a senha"**: sem recuperação (offline).
4. **RF06**: prévia da última mensagem na Home não implementada.
5. **Sprint 2 herdada**: progresso real de cópia de anexo, varredura de
   órfãos em `media/`, player interno, seleção múltipla de anexos.
6. **`line_diff_engine.dart`**: legado, sem uso, candidato a remoção.
7. **Busca por texto é O(n) em Dart** (não há índice invertido). Em 10k com
   cache quente, ~5 ms. Em 100k, ~50 ms. Aceitável dentro do escopo.
8. **Feedback visual nas operações de senha na Home** foi cancelado (ver
   decisões descartadas). O único feedback é o `SnackBar` de conclusão/erro.

---

## Checklist de validação manual

| # | Teste | Esperado |
|---|---|---|
| 1 | `flutter analyze` | **No issues found!** |
| 2 | `flutter test test/security/password_crypto_test.dart` | **8/8 passando** |
| 3 | Conversa não protegida de 10k: abrir | ≤ 100 ms (sem decifrar) |
| 4 | Conversa protegida de 10k: abrir | ≤ 500 ms |
| 5 | Rolar conversa 10k para o topo | páginas carregam em ≤ 100 ms cada |
| 6 | Editar 1 mensagem em 10k protegida (cache quente) | instantâneo |
| 7 | Excluir 1 mensagem em 10k protegida | instantâneo |
| 8 | Definir senha em 10k | ≤ 700 ms |
| 9 | Trocar senha em 10k | ≤ 700 ms |
| 10 | Desbloquear conversa | ≤ 300 ms; abre direto (sem overlay) |
| 11 | Minimizar o app → voltar → tocar conversa protegida | pede senha de novo |
| 12 | Buscar em 10k protegida | ≤ 1 s com spinner |
| 13 | Buscar em 10k não protegida | ≤ 100 ms |
| 14 | Reordenar em conversa grande | sem lag; "Desfazer" instantâneo |
| 15 | Conversa não protegida: nenhuma regressão funcional | ✓ |

---

## Atualizações sugeridas para a especificação

- **RF05 (busca)**: registrar que a busca por texto é feita em Dart, sobre a
  lista em memória (com cache de decifragem), e **não** usa índice invertido
  no SQLite — decisão tomada para não violar RF08 (FTS armazenaria texto puro).
- **RF08 (sessão)**: registrar que a sessão de desbloqueio dura enquanto o
  app está em primeiro plano; ao minimizar, as chaves são limpas
  (`LockOnBackground`, Z1).
- **RNF02 (performance)**: documentar as metas medidas — abertura ≤ 500 ms
  em 10k protegida; definir/trocar senha ≤ 700 ms; reorder O(1); re-render
  ≤ 5 ms por edição.
- **Stack técnica**: atualizar a menção a "PBKDF2/Argon2" para "PBKDF2-HMAC-SHA256
  com 155.000 iterações" (decisão F).

  #Correções de bugs:
  fix(chat): corrige bugs de exibição introduzidos pela paginação da Sprint 6

A paginação acumulava páginas lidas uma única vez, em vez de espelhar o
banco. Isso causava edições, tags, datas e exclusões não refletidas, além
de vários problemas de navegação, busca e reordenação.

Paginação (chat_screen.dart)
- Substitui o acúmulo de páginas por UM stream de janela
  (watchMessagesPaginated com limit crescente, offset 0). Cada emissão
  substitui _ordered. Edição, tag, data, reordenação e exclusão passam a
  aparecer em qualquer mensagem carregada.
- _loadMore amplia a janela em +100; remove _preloadNext e o setState
  duplicado em _onPage (o auto-scroll em mensagem nova volta a funcionar).
- _paginationReady só fica true após a 1ª emissão (some o flash de
  "Nenhuma mensagem ainda").
- _onPositionsChanged usa o maior índice visível (mensagem mais antiga na
  tela), então a pré-carga dispara antes do fim da lista.
- _goToMessage amplia a janela, espera a emissão e o frame antes de rolar.
  Sem laço sem garantia de progresso.
- _totalCount passa a vir de watchMessageCount (stream), cobrindo mudanças
  externas (exclusão em lote, captura recuperada).
- Folha de detalhes mostra a posição real na conversa, não na janela.

Busca
- _loadAllMessages aguarda messagesStreamProvider.future. Elimina o falso
  "Esta conversa ainda não tem mensagens" em Faixa de datas, Ir para data,
  Palavra e Lista de resultados.
- SearchResultsScreen não calcula nem cacheia hits sem dados; _computing
  inicia true.

Repositório (conversation_repository.dart)
- watchMessages deixa de inverter a lista (rows.reversed removido): agora
  devolve ordem cronológica, como documentado. Corrige "Ir para data" (cai
  na 1ª mensagem do dia), o sentido de ▲/▼ e a ordem dos resultados.
- Novo watchMessageCount(conversationId).

Reordenar
- Modo mover usa _ordered (mesma referência das sondas) e converte o
  índice da janela para o índice global em _finishMove.

Segurança (RF08)
- ChatScreen observa o ciclo de vida: em paused/detached de conversa
  protegida descarta o conteúdo decifrado, invalida o provider e, ao
  voltar, fecha até a Home (que pede a senha).
- _send trata StateError sem perder o texto digitado.

Sem mudança de schema (continua v4).