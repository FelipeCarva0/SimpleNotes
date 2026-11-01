# Sprint 6 — Polimento, performance e escalabilidade

**Status: PLANEJADA.** Este documento consolida as discussões e decisões
**antes** da implementação. Não substitui o `SPRINT_6_CHANGES.md` (que será
escrito ao final, com o que de fato foi implementado).

> Documentos anteriores (`SPRINT_0..5_CHANGES.md`) descrevem estados
> anteriores. Em caso de divergência, vale o `SPRINT_6_CHANGES.md` (quando
> existir) e, na falta dele, este plano.

---

## 0. Motivação

Relatos do uso real na Sprint 5:

1. **Demora para entrar numa conversa protegida** (segundos).
2. **Demora para definir/trocar senha**.
3. **Conversa grande (10k mensagens)** carrega **tudo** de uma vez, mesmo
   protegida; a UI fica pesada.

Diagnóstico (confirmado no código):

- `watchMessages` **não tem `LIMIT`** — lê a conversa inteira.
- `_decryptMessages` **decifra tudo sequencialmente**.
- `protectConversation`/`changeConversationPassword` fazem **N UPDATEs dentro
  de uma transação** (um round-trip por mensagem).
- `deriveKey` (PBKDF2 310k) roda na **main isolate** → trava a UI.
- `reorderMessage` renumera **todas** as `position` (0..N-1) → **O(n)** por
  gesto.

Conclusão: a arquitetura **não escala** para 10k. Funciona bem até ~500.

---

## 1. Objetivo da Sprint 6

**Máxima resposta, sem travamento, sem inconsistência, e escalável.**

Metas mensuráveis:

| Operação | Hoje (10k protegida) | Meta |
|---|---|---|
| Abrir conversa | 2–10 s | **≤ 500 ms** |
| Definir/trocar senha | 0.5–3 s | **≤ 700 ms** |
| Rolagem inicial | instantânea | instantânea |
| Rolagem além da janela | instantânea (tudo carregado) | **≤ 100 ms por página** (imperceptível) |
| Re-render (edição/exclusão) | re-decifra tudo | **≤ 5 ms** |
| Reordenar | O(n) por gesto | **O(1)** |
| Busca em não protegida | O(n) memória | **≤ 50 ms** |
| Busca em protegida | O(n) sequencial | **≤ 1 s** com spinner |
| Memória (pico) | O(n) sempre | **O(janela carregada)** |

**Regra de ouro**: nada de O(n) na main isolate; nada de schema change
desnecessário; nada de trade-off de segurança.

---

## 2. Decisões consolidadas

| ID | Decisão | Justificativa |
|---|---|---|
| **F** | PBKDF2 **155.000 iterações** (metade de 310k) | Com `deriveKeyInIsolate`, a UI não trava; 155k mantém resistência razoável. |
| **P1** | Página = **100 mensagens** | Equilíbrio entre tempo de decifragem (~5 ms) e round-trips. |
| **P3** | **1 página** em background ao abrir | Primeira rolagem instantânea, sem desperdício grande. |
| **R1** | `position` **esparsa** (int, gaps de 1000) | Reorder O(1) sem mudar schema. |
| **C** | **Cache de plaintext** em memória | Re-render instantâneo; invalidação por `messageId`. |
| **Z1** | **Re-bloqueio em background** (`LockOnBackground`) | Segurança: minimizar limpa as chaves. |
| **Combo** | A + B + C + D + P1–P5 + R1 + S1–S3 + S5 + E + U3 + Z1 | Ver seção 3. |

### Decisões **descartadas** e por quê

| ID | O que era | Por que foi descartado |
|---|---|---|
| **R2** | `position` como `double` | Exige schema v5; R1 (int com gaps) resolve sem migração. |
| **S4** | FTS5 (índice invertido no SQLite) | **Viola RF08**: o FTS guarda texto puro em conversa protegida. Só serviria para não protegida, e o `LIKE` já cobre. |
| **Z3** | Renumerar `position` ao abrir | Custo sem ganho com R1; a semântica esparsa é suficiente. |
| **F "agressivo"** | Reduzir para 50k ou menos | Trade-off de segurança sem ganho perceptível (isolate já resolve). |
| **Cache em Keychain/Keystore** | Persistir chave entre execuções | Exigiria `flutter_secure_storage` e **mudaria D2** ("sessão dura a vida do app"). Não é o escopo. |
| **Background isolate para `protectConversation`** | Rodar a transação em isolate | O drift não é thread-safe por padrão; exigiria segunda instância do banco. O `batch` (D) resolve a maior parte. |

---

## 3. Combinação adotada ("Combo Escalável")

> **A + B + C + D + P1 + P2 + P3 + P4 + P5 + R1 + S1 + S2 + S3 + S5 + E + U3 + Z1**

### O que cada peça resolve

| ID | Melhoria | Camada | Resolve |
|---|---|---|---|
| **A** | `deriveKey` em isolate | Cripto | UI não trava no desbloqueio |
| **B** | `Future.wait` na decifragem | Cripto | Decifragem paralela (10–50×) |
| **C** | Cache de plaintext | Cripto | Re-render de 100 ms → 1–5 ms |
| **D** | `batch` no protect/unprotect/change | Escrita | Definir/trocar: 500 ms–1.5 s → 50–200 ms |
| **P1** | Paginação `limit`/`offset` | Leitura | Abertura 10k: 2–10 s → 450 ms |
| **P2** | `watchAllMessages` (sem limite) | Leitura | Busca não é afetada pela paginação |
| **P3** | 1 página em background | Leitura | Primeira rolagem instantânea |
| **P4** | Scroll-based preload | Leitura | Zero desperdício a partir da 2ª página |
| **P5** | `_goToMessage` com ajuste de janela | Leitura | Busca leva a qualquer mensagem |
| **R1** | `position` esparsa | Ordenação | Reorder O(1) |
| **S1** | Busca em SQL (`LIKE`) para não protegida | Busca | ~30 ms em 10k |
| **S2** | Busca em memória paralela para protegida | Busca | ~500 ms em 10k |
| **S3** | Cache de resultado por query | Busca | Repetir busca é instantâneo |
| **S5** | Spinner na busca | UX | Percepção |
| **E** | Feedback "Protegendo…"/"Desbloqueando…" | UX | Percepção |
| **U3** | Cancelar preload em `dispose` | Robustez | Sem trabalho à toa |
| **Z1** | `LockOnBackground` | Segurança | Minimizar limpa as chaves |

### Combinações **coerentes** (nada desfaz o ganho do outro)

- **A + B + P1**: paginação lê 100, `Future.wait` decifra 100 em ~5 ms,
  isolate tira a derivação da main. Juntos: abertura ≤ 500 ms.
- **D + C**: `batch` escreve rápido; cache invalida por `id` e não precisa
  re-decifrar o que não mudou.
- **P1 + P2 + P5**: paginação na `ChatScreen`, `watchAllMessages` na busca,
  `_goToMessage` ajusta janela. **Nenhum quebra o outro.**
- **R1 + P1**: `position` esparsa não depende da janela; a UI usa `index`,
  não `position`; o drift ordena por `position`.

### Pontos de **atenção** (não são conflitos, mas exigem cuidado)

- **P3 sem U3**: preload continua após fechar a tela → U3 é obrigatório.
- **S4 (FTS5) + cifragem**: **incompatível** → não adotar.
- **F sem A**: reduzir iterações na main isolate ainda trava 150–200 ms →
  A é pré-requisito de F na prática (F sozinho não resolve a percepção).

---

## 4. Análise de escalabilidade (por que "escalável")

| Operação | Hoje | Com o Combo |
|---|---|---|
| Abertura (N) | **O(N)** | **O(1)** na percepção (100 fixas) |
| Decifragem (N) | O(N) sequencial | O(100) por página, paralelo |
| Re-render (N) | **O(N)** | **O(1)** com cache |
| Reorder (N) | **O(N)** | **O(1)** |
| Busca (N) | O(N) memória | O(N) paralelo **ou** O(log N) (LIKE) |
| Memória (N) | O(N) sempre | O(janela) típica |
| `protectConversation` (N) | O(N) round-trips | O(N/100) batches |

**Cresce só onde precisa** (busca, decifragem sob demanda — ambos em
background, com feedback). **Abertura, reorder e re-render são O(1).**

Escala de 100 → 100.000 mensagens com a mesma sensação de fluidez
(com exceção da busca em 100k protegida, que fica ~5 s, mas com spinner e
cache).

---

## 5. Riscos e mitigações

| Risco | Mitigação |
|---|---|
| Paginação quebra busca | **P2 obrigatório**: `SearchResultsScreen` usa `watchAllMessages`. |
| Busca leva a mensagem fora da janela | **P5**: `_goToMessage` carrega a página do alvo. |
| Reorder calcula índice errado | **R1**: `position` esparsa; a UI usa `index`, o drift usa `position`. |
| Duplicatas na concatenação de páginas | Estado em `Map<String, Message>` (chave = `id`). |
| Cache fica velho após edição/exclusão | Invalidação por `messageId` em todos os métodos de escrita. |
| Preload continua após fechar | **U3**: `_disposed` + cancelamento. |
| `_encodeForStorage` sem chave grava puro | **StateError** (defesa em profundidade, já no Bloco 4.5 da Sprint 5). |
| `batch` com callback assíncrono | **Duas fases**: cifrar em paralelo, depois `batch` síncrono. |
| `position` esparsa esgota o gap | Renumeração automática quando `newPosition` colide (raro). |
| Isolate com record como argumento | Usar record `(String, String)` — suportado em Dart 3. |
| Cache em memória aumenta RAM | **Aceito** (C foi aprovado); invalidado em `lock`/`lockAll`. |

---

## 6. Blocos de implementação (ordem respeitando dependências)

| Bloco | Entrega | Depende de |
|---|---|---|
| **6.1** | `deriveKeyInIsolate` + F (155k) + spinner | — |
| **6.2** | `Future.wait` na decifragem + `deriveKeyInIsolate` nos 4 métodos de senha | 6.1 |
| **6.3** | `batch` em `protect`/`unprotect`/`change` (2 fases) | 6.2 |
| **6.4** | `position` esparsa + `reorderMessage` O(1) | — |
| **6.5** | `watchMessagesPaginated`, `watchAllMessages`, `countMessages` | 6.2 |
| **6.6** | `ChatScreen` paginada + preload (P3) + scroll-based (P4) + U3 | 6.5 |
| **6.7** | `_goToMessage` com ajuste + `SearchResultsScreen` com `watchAllMessages` | 6.6 |
| **6.8** | Cache de plaintext (C) | 6.2 |
| **6.9** | Busca SQL (S1) + paralela (S2) + cache (S3) + spinner (S5) | 6.5 |
| **6.10** | Feedback visual (E) nos diálogos e no chat | 6.1, 6.3 |
| **6.11** | `LockOnBackground` (Z1) + `SPRINT_6_CHANGES.md` + `mapa.txt` | 6.8 |

### Agrupamento em lotes de entrega

- **Lote 1 (base)**: 6.1 + 6.2 + 6.3 — resolve o pior caso (abertura de
  conversa protegida) e definir/trocar senha.
- **Lote 2 (escala)**: 6.4 + 6.5 + 6.6 + 6.7 — resolve conversa de 10k.
- **Lote 3 (busca e polimento)**: 6.8 + 6.9 + 6.10 + 6.11 — fecha a sprint.

---

## 7. Alternativas analisadas e descartadas

| Alternativa | Por que não |
|---|---|
| Carregar **tudo** de uma vez (hoje) | Não escala (10k = 2–10 s). |
| **Só paginação** (sem A/B/C) | Decifragem de 100 sequencial ainda trava ~30 ms; sem cache, re-render re-decifra. |
| **Só A + F** (sem paginação) | Reduz derivação, mas a leitura/decifragem continuam O(N). |
| **FTS5 para tudo** | Viola RF08 (texto puro no índice). |
| **Background isolate para `protectConversation`** | Drift não é thread-safe; `batch` resolve. |
| **Cache em Keychain/Keystore** | Muda D2 (sessão em memória); fora do escopo. |
| **`position` como `double`** | Schema v5; R1 resolve sem migração. |
| **Preload "3 a cada 3"** (proposta inicial) | Desperdiça se o usuário fecha logo; "1 + scroll-based" é melhor. |
| **Renumerar `position` ao abrir** | Custo sem ganho com R1. |

---

## 8. O que **não** muda

- **Schema**: continua **v4**. `position` continua `int` (semântica muda, coluna não).
- **RF08**: nenhuma mudança de segurança. PBKDF2 continua com salt + AES-GCM
  (só reduz iterações, decisão explícita).
- **Modelo de dados**: `Conversation`, `Message`, `Tag` inalterados.
- **Invariantes da Sprint 5**: preservados (ver `mapa.txt` seção 8).
- **RF05 (busca)**: continua igual para o usuário; só fica mais rápida.
- **RF06.1 (busca por título)**: inalterada.
- **UI de conversa**: mesma aparência; só carrega em páginas.

---

## 9. Métricas de validação (por bloco)

Ver checklist detalhado em cada bloco do plano de implementação. Resumo:

- **6.1**: desbloqueio sem travar; `deriveKey` ~150–200 ms.
- **6.2**: decifrar 100 msgs em ≤ 10 ms.
- **6.3**: definir/trocar senha 10k em ≤ 700 ms.
- **6.4**: reorder normal; 50 movimentos seguidos sem gaps negativos.
- **6.5**: paginação correta (offset, count).
- **6.6**: abertura 10k protegida ≤ 500 ms; rolagem fluida.
- **6.7**: busca leva a qualquer posição, mesmo fora da janela.
- **6.8**: editar uma mensagem não re-decifra as outras.
- **6.9**: busca não protegida ≤ 50 ms; protegida ≤ 1 s com spinner.
- **6.10**: spinners visíveis nas operações longas.
- **6.11**: minimizar o app re-bloqueia.
- **Transversais**: `flutter analyze` limpo; 8 testes de crypto passam;
  conversa não protegida sem regressão.

---

## 10. Pendências e limitações que permanecem

- **Bytes de mídia em claro** no filesystem (Sprint 5, D7).
- **Título da conversa em claro** (necessário para RF06.1).
- **"Esqueci a senha"**: sem recuperação (offline).
- **RF06**: prévia da última mensagem na Home (usa só `atualizadoEm`).
- **Sprint 2 herdada**: progresso real de cópia, varredura de órfãos em
  `media/`, player interno, seleção múltipla de anexos.
- **`line_diff_engine.dart`**: legado, sem uso, candidato a remoção.

Nenhuma dessas bloqueia a Sprint 6.

---

## 11. Referências

- `mapa.txt` — estado atual do projeto.
- `SPRINT_0..5_CHANGES.md` — estados anteriores.
- `especificacao.md` v5.1 — RF01, RF02, RF03, RF04, RF05, RF06, RF07, RF08.
- Este documento (Sprint 6 — planejamento).

---

## 12. Próximo passo

Implementar por lotes:

1. **Lote 1 (6.1–6.3)** — base de performance.
2. **Lote 2 (6.4–6.7)** — escala de conversa.
3. **Lote 3 (6.8–6.11)** — busca, polimento e fechamento.

Após o Lote 3, escrever **`SPRINT_6_CHANGES.md`** com o que foi implementado
e atualizar `mapa.txt` (seção 8, invariantes; seção 9, pendências).