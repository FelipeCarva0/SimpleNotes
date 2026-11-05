# Sprint 7 — Seleção, múltiplas mídias e compartilhamento

**Status: CONCLUÍDA.** Documento de fechamento. Substitui (em caso de
divergência) o `SPRINT_7_PLAN.md`.

Data de conclusão: [preencher]
Schema drift: **continua v4** (nenhuma coluna/tabela nova nesta sprint).
`flutter analyze` final: **0 issues**.
`flutter run` (debug) e `flutter build apk --release`: **compilam e instalam**.

---

## Resumo executivo

A Sprint 7 entrega quatro funcionalidades pedidas no plano (seleção de
mensagens na conversa, multi-importação, encaminhar e compartilhar/receber):

1. **Seleção de mensagens na própria `ChatScreen`** com ações em lote via `⋮`
   do AppBar sobrecarregado (Copiar, Compartilhar, Encaminhar, Definir tag,
   Editar data, Excluir), "Selecionar até aqui" e "Selecionar tudo".
2. **Importação de múltiplas mídias** de uma vez (galeria com fotos+vídeos,
   documentos, áudio), com progresso "N de M", cancelamento e falha parcial.
3. **Encaminhar** mensagens para outra Conversa do próprio app, com opções
   "Manter data original" e "Levar tag", e aviso de rebaixamento de segurança
   (S7-8).
4. **Compartilhar** para outros apps via share sheet do Android, com nomes de
   exibição e limpeza de temporários; **receber** compartilhamento de outros
   apps (intent `SEND`/`SEND_MULTIPLE`) com escolha de destino.

Todas as funcionalidades respeitam o modelo de segurança da Sprint 5 (cifra
por Conversa) e o re-bloqueio em background da Sprint 6 (Z1), com o novo
`AppLockShield` fazendo o meio-campo entre pickers/share sheet e o bloqueio.

---

## Blocos entregues

### 7.1 — Fundação (Lote 1)

**Novo arquivo:** `lib/repositories/new_message.dart`
- Classe `NewMessage` (formato de entrada de `appendMessages`), com
  construtores de conveniência `.texto()` e `.arquivo()`, e `validate()`.

**`lib/repositories/conversation_repository.dart`** — novos métodos:
- `appendMessages(conversationId, items, {isCancelled})` — inserção em lote
  em duas fases + 1 transação, atômica por chamada, com rollback de arquivos.
  `position` calculada uma vez com gaps de 1000 (Sprint 6).
- `getMessagesByIds(ids)` — leitura por id em blocos de 500 (limite SQLite),
  decifrando quando necessário; ordenada por `position`.
- `getMessageIds(conversationId)` — só os ids, sem decifrar conteúdo.
- `setMessageTagMany`, `setMessageDateMany`, `deleteMessagesMany` passaram a
  particionar `ids` em blocos de 500 dentro da transação (invariante 20).
- Constante `_sqlChunkSize = 500` centralizada.

**Novo arquivo:** `lib/security/app_lock_shield.dart`
- `AppLockShield` com `armed` / `isProtecting` (cobre corrida entre retorno do
  Future e `paused`), `run<T>()` reentrante e **janela de graça (2 min)** que
  dispara `onGraceExpired` se o app ficar em `paused` com o escudo armado.

**Novo arquivo:** `lib/providers/security_providers.dart`
- `appLockShieldProvider` (D8 = opção A).

**Integração:**
- `lib/widgets/lock_on_background.dart`: consulta `shield.isProtecting` antes de
  chamar `lockAll()`; seta `shield.onGraceExpired` → `lockAll()`.
- `lib/screens/chat_screen.dart`: `didChangeAppLifecycleState` consulta o
  escudo. Se escudo armado, não descarta conteúdo. No `resumed`, se
  `_protected && !isUnlocked`, descarta e volta para a Home (cobre expiração
  do grace timeout).
- `lib/database/app_database.dart`: **construtor de teste**
  `AppDatabase.forTesting(QueryExecutor)`, para uso em testes. Não muda
  produção.

**Decisões de implementação:**
- `appendMessages` valida `NewMessage` antes de copiar arquivo nenhum
  (ArgumentError cedo).
- `_PreparedAppend` interno guarda o "shape" da fase 1 já cifrado.
- `_dateOnly` como helper privado.

### 7.2 — Modo seleção na `ChatScreen` (Lote 2a)

**`lib/widgets/message_bubble.dart`:**
- Novos parâmetros `selectionMode` e `selected`. Em `selectionMode`, o
  conteúdo interno fica dentro de `IgnorePointer` (toques em mídia/arquivo são
  bloqueados). Em `selected`, o balão pinta com `secondaryContainer` e
  desenha um `check` no canto superior direito.

**`lib/screens/chat_screen.dart`** — estado e gestos:
- Campos: `_selecting`, `_selectedIds`, `_anchorId` (este último é consumido
  pela 7.2b).
- Long-press **sem arrastar** entra em seleção (`_enterSelection`); long-press
  **com arrasto >12 px** continua reordenando (S7-4 preservado).
- Em seleção: toque alterna marcação; `Dismissible` com
  `DismissDirection.none`; reordenar desativado; `onTap` do balão bloqueado;
  sair da seleção se `_selectedIds` fica vazio (padrão de apps de mensagem).
- `PopScope` combina busca + seleção: voltar sai da seleção primeiro.
- `_discardDecryptedContent` (do 7.1e) agora também limpa a seleção
  (invariante 17).

**Menu `⋮` do AppBar sobrecarregado** (revisão do plano, decisão de UX):
- Fora da seleção: `more_vert` com "Pesquisar" / "Gerenciar tags".
- Em seleção: `checklist` com cor primária + **pulso de 450 ms** na transição
  (sinaliza a sobrecarga ao usuário). Menu passa a mostrar ações em lote:
  - **Selecionar até aqui** (usa `_anchorId` + última marcada na janela) e
    **Selecionar tudo** (via `getMessageIds`), ambos sem sair do modo.
  - **Copiar** (implementado em 7.2b), **Compartilhar** (7.5),
    **Encaminhar** (7.4).
  - **Definir tag**, **Editar data**, **Excluir** em lote.
  - Com **exatamente 1** selecionada: **Editar texto** (se tipo texto) ou
    **Renomear arquivo** + **Substituir arquivo** (se anexo).
- Após qualquer ação de conteúdo, a seleção é limpa.
- `_showMessageActions` (menu antigo de long-press) foi **removido** — todas as
  ações migraram para o `⋮` sobrecarregado. Edição de texto continua
  acessível por tap direto no balão de texto fora da seleção.
- `_AnimatedMoreMenu` (widget auxiliar) implementa a troca de ícone + pulso.

### 7.2b — Copiar, "Selecionar até aqui" e "Selecionar tudo"

**`lib/screens/chat_screen.dart`:**
- `_copySelected`: usa `getMessagesByIds` (sobrevive a seleções fora da
  janela), concatena `conteudoTexto` das de texto em ordem de `position`
  (`\n\n` entre elas) e envia ao clipboard. Informa "N mensagens de texto
  copiadas. M arquivos não copiados." quando havia mídia (S7-6).
- `_selectRangeToAnchor`: marca o intervalo entre `_anchorId` e a última
  selecionada **na janela**. Se a âncora não está na janela, avisa e sugere
  "Selecionar tudo".
- `_selectAll`: usa `getMessageIds` (independe da janela), limpa `_anchorId`
  (depois de "tudo", "até aqui" perde sentido) e mostra contagem.
- `select_to_anchor` e `select_all` **não** saem da seleção (ação de ampliação,
  não de conteúdo).

### 7.3 — Múltiplas mídias (Lote 2b)

**`lib/services/attachment_service.dart`:**
- `pickMultipleMedia()` → `ImagePicker.pickMultipleMedia()` (fotos+vídeos
  juntos, tipo inferido por `inferType`).
- `pickMultipleFiles(FileType)` + atalhos `pickMultipleAudioFiles()` e
  `pickMultipleDocuments()` — `allowMultiple: true`.
- Câmera, vídeo e gravador de áudio continuam **unitários**
  (`pickForReplace` também).

**`lib/widgets/attachment_picker_sheet.dart`:**
- `AttachmentAction` simplificado: `gallery` (fotos+vídeos) absorve o antigo
  `videoGallery`; rótulos "Galeria (fotos e vídeos)", "Áudio do dispositivo",
  "Documentos".

**`lib/screens/chat_screen.dart`:**
- Todos os pickers (câmera, galeria, vídeo, áudio, documento) rodam dentro de
  `AppLockShield.run` — sem isso, minimizar durante o picker re-bloqueava a
  conversa protegida (correção de bug).
- `_sendPickedMany(picked)`: envia em **lotes de 10** via `appendMessages`;
  progresso "N de M" em `_BatchProgressBar` (determinada) com **Cancelar**;
  falha parcial mantém lotes anteriores; temporários apagados no `finally`.
- `_batchTotal`, `_batchSent`, `_batchCancelled` como campos.
- Unitário (`_sendPicked`) preservado para câmera/vídeo/gravador (indeterminada,
  sem Cancelar).

**Pendência conhecida:** checagem de espaço livre antes de copiar (o plano
menciona, mas exige dependência nova ou `MethodChannel`; fica para uma sprint
futura).

### 7.4 — Encaminhar (Lote 3a)

**Novo arquivo:** `lib/screens/destination_picker_screen.dart`
- `DestinationPickerScreen` reutilizável (usada também na 7.6): busca por
  título (mesmo `normalizeText` da Home), cadeado nas protegidas,
  `showUnlockDialog`/`verifyConversationPassword` quando aplicável, botão
  "Nova conversa", e `disabledConversationId` para a origem.
- `ForwardOptions` + `showForwardOptionsDialog`: dois `CheckboxListTile`
  ("Manter data original" e "Levar tag") + **aviso S7-8** (só quando
  `sourceProtected && !destinationProtected`).

**`lib/repositories/conversation_repository.dart`:**
- `forwardMessages(...)` — busca por `getMessagesByIds`, monta `NewMessage`
  com arquivo físico de origem como fonte do `saveFile` no destino (S7-1:
  cópia física por mensagem); arquivo ausente → pula e conta em
  `skippedCount`; tags resolvidas no destino via `TagRepository.createOrGet`
  (mapa origem→destino); opção "manter data" respeita `data`/`dataEditada`;
  envia em lotes de 10 via `appendMessages`.
- `ForwardResult { createdIds, skippedCount, total, forwardedCount }`.

**`lib/screens/chat_screen.dart`:**
- `case 'forward'` no `_onSelectionMenuSelected` → `_forwardSelected`:
  picker → diálogo de opções → `forwardMessages` → snack com "N encaminhadas
  (M ignoradas: arquivo indisponível) em 'Destino'" e botão **Abrir**.

**Fora do escopo:** "Mover" (7.4b) — encaminhar + excluir origem. Cancelamento
na UI não exposto (operação rápida). Progresso granular por arquivo não
implementado.

### 7.5 — Compartilhar com outros apps (Lote 3b)

**`pubspec.yaml`:** `share_plus ^12.0.2`.

**Novo arquivo:** `lib/services/share_service.dart`
- `ShareService.shareMessages(List<Message>)`:
  - Junta textos (ordem de `position`, `\n\n` entre eles) → `ShareParams.text`.
  - Copia cada anexo para `share_tmp/<uuid>/` com o **nome de exibição**
    (sanitização mínima de `/\0`; colisões viram `nome (2).ext`).
  - `SharePlus.instance.share(ShareParams(...))` (`share_plus` v12 migrou de
    `Share.shareXFiles`).
  - `finally`: apaga `share_tmp/<uuid>/`.
- `ShareService.cleanupOrphans()` — varre `share_tmp/` na abertura do app
  (invariante 19). Chamado pelo `LostCaptureGate._recover`.
- `shareServiceProvider`.

**`lib/screens/chat_screen.dart`:**
- `case 'share'` → `_shareSelected`: aviso S7-8 quando origem protegida;
  roda dentro de `AppLockShield.run`; snack só se `unavailable`.

**`lib/widgets/lost_capture_gate.dart`:** chama `cleanupOrphans()` no início de
`_recover`.

### 7.6 — Receber compartilhamento (Lote 4)

**`pubspec.yaml`:** `receive_sharing_intent 1.8.0` (fixo — ver seção "Build
Android" abaixo para o ajuste de JVM target).

**`android/app/src/main/AndroidManifest.xml`:**
- Intent-filters `ACTION_SEND` e `ACTION_SEND_MULTIPLE` para `text/plain`,
  `image/*`, `video/*`, `audio/*`, `application/*`, `*/*`.
- `android:launchMode="singleTask"` (era `singleTop`). O
  `receive_sharing_intent` espera uma única instância da Activity para
  entregar o intent novo com o app aberto ou em segundo plano.
- `taskAffinity=""` mantido.
- **Sem** `INTERNET` (RNF01).

**Novo arquivo:** `lib/services/share_receiver.dart`
- `SharedPayload { text?, files }` normaliza `SharedMediaFile`.
- `ShareReceiver` encapsula `ReceiveSharingIntent.instance`:
  `getInitialPayload()` (app frio; chama `reset()` depois de ler),
  `stream` (app aberto), `cleanupFiles(...)`.
- Texto de `SharedMediaType.text` e `SharedMediaType.url` vão para
  `payload.text`.

**Novo arquivo:** `lib/widgets/share_receiver_gate.dart`
- Escuta o plugin (`getInitialPayload` no primeiro frame; `stream` em
  `initState`).
- Ao receber payload: empilha `DestinationPickerScreen` (title "Salvar em",
  subtitle com contagem) no `rootNavigator`.
- Destino escolhido: monta `List<NewMessage>` com **texto primeiro** (S7-9) e
  depois os arquivos (tipo por `AttachmentService.inferType`); chama
  `appendMessages`; navega para a `ChatScreen` do destino.
- `finally`: limpa o cache do plugin. `paused` com payload pendente
  (picker aberto) → descarta e limpa. `_busy` evita shares concorrentes.

**`lib/app.dart`:**
- Árvore final de `home`:
  `LockOnBackground → LostCaptureGate → ShareReceiverGate → HomeScreen`.
- `_DevSeedOnStart` foi **removido** (e o import de `dev/seed_carros.dart`).
  **Pendência**: apagar `lib/dev/seed_carros.dart` e excluir as conversas de
  teste do aparelho.

---

## Correções durante a sprint

- **7.1a** — `NewMessage` sem initializing formals gerava `prefer_initializing_formals`;
  corrigido com `this.campo` no construtor.
- **7.2a** — `_anchorId` ficava sem consumidor até 7.2b: warning silenciado com
  `// ignore: unused_field` **temporário**; removido no 7.2b quando o campo
  passou a ser lido por "Selecionar até aqui".
- **7.2a** — `_showMessageActions` órfão após migrar o menu para o `⋮`;
  removido no 7.2a-fix. `Editar texto` continua acessível por tap no balão
  de texto fora da seleção; `Renomear`/`Substituir` só via `⋮` em seleção.
- **7.2a** — decisão de UX revista: em vez de `⋮` dentro do balão durante a
  seleção, **o `⋮` do AppBar** ganhou **sobrecarga** (ícone `checklist` +
  pulso + menu em lote), preservando o long-press → seleção do plano (S7-4).
- **7.2a-fix** — `_editDateMany`, `_tagMany`, `_deleteMany` duplicados da
  `SearchResultsScreen` para a `ChatScreen` (mesma semântica, mesma UI).
- **7.3** — `FileType` vazava para a `ChatScreen`; substituído por
  `pickMultipleAudioFiles()` / `pickMultipleDocuments()` no
  `AttachmentService`. `_batchCancelled` era variável local com `_`; virou
  campo.
- **7.4** — `ForwardResult` não importado na `chat_screen.dart` (import
  explícito do `conversation_repository.dart` adicionado).
- **7.5** — `Share`/`shareXFiles` deprecated no `share_plus` v12; migrado para
  `SharePlus.instance.share(ShareParams(...))`; `ShareResult` e
  `ShareResultStatus` importados explicitamente.

---

## Build Android (fora da lógica Dart)

A Sprint 7 introduziu o `receive_sharing_intent`, que traz um `build.gradle`
com JVM target fixo em Java 8, conflitando com o Kotlin em 17/21 do projeto.
As alterações abaixo (documentadas em detalhe no
`BUILD_ANDROID_CHANGES.md`) foram necessárias para compilar:

- `android/app/build.gradle.kts`: `compileOptions` 17;
  `kotlin { compilerOptions { jvmTarget.set(JVM_17) } }` **fora** de
  `android {}`.
- `android/build.gradle.kts` (raiz): dois `subprojects` — (1) redireciona
  pasta de build; (2) `tasks.withType<KotlinCompile>().configureEach` com
  `compilerOptions`, aplicando `JVM_1_8` **só** para `receive_sharing_intent` e
  `JVM_17` para o resto.
- `android/gradle.properties`:
  `kotlin.jvm.target.validation.mode=warning` (rede de segurança; a exceção
  por nome já resolve o caso concreto).
- `AndroidManifest.xml`: `launchMode="singleTask"` (era `singleTop`) e
  intent-filters `SEND`/`SEND_MULTIPLE`.
- `lib/services/share_receiver.dart`: `ReceiveSharingIntent.instance.reset()`
  após `getInitialPayload()` (evita reentregar o mesmo payload na próxima
  abertura).

**Alertas de manutenção:**
- Se o `receive_sharing_intent` migrar para Java 17, remover a exceção por
  nome (volta para `JVM_17` geral).
- Novos plugins com Java 8 exigirão a mesma exceção.
- `kotlin.jvm.target.validation.mode=warning` esconde o problema; remover
  para builds estritos.

---

## Especificação (v5.1 → v5.2)

- **RF02.3**: aceita vários arquivos por ação (galeria e seletor de arquivos).
  Câmera e gravador continuam unitários.
- **RF09 (novo)**: seleção de mensagens na conversa (qualquer tipo) com
  copiar, excluir, definir tag, editar data, encaminhar, compartilhar e
  "selecionar até aqui"/"selecionar tudo".
- **RF10 (novo)**: importação em lote — cada arquivo vira uma Mensagem, com
  data do momento da inclusão, na ordem de seleção.
- **RF11 (novo)**: encaminhar para outra Conversa (cópia independente) e
  compartilhar para outros apps.
- **RF12 (novo)**: receber compartilhamento (`ACTION_SEND`/
  `ACTION_SEND_MULTIPLE`); o usuário escolhe a Conversa de destino
  (desbloqueando se protegida).
- **RF08**: acrescenta que encaminhar/compartilhar a partir de conversa
  protegida expõe o conteúdo em claro no destino (com aviso prévio — S7-8).
- **RNF01**: acrescenta "o app de release não declara `INTERNET`".

### Novos invariantes (entram no `mapa.txt`, seção 8)

15. Encaminhar gera **novo `id`** e **novo arquivo físico** por mensagem;
    nenhum arquivo é referenciado por mais de uma Mensagem.
16. Ações em lote seguem a ordem de `position`, nunca a ordem de seleção
    (exceção: importação em lote, que segue a ordem de seleção do picker).
17. A seleção é descartada quando a conversa bloqueia (`_locked`).
18. `appendMessages` é atômico por chamada: ou todas as mensagens entram, ou
    nenhuma e nenhum arquivo órfão fica em disco.
19. Nenhum temporário de compartilhamento (saída ou entrada) sobrevive ao
    fluxo: apagado no `finally` e varrido na abertura do app.
20. Operações `*Many` com `IN (...)` processam em **blocos** (limite de
    variáveis do SQLite).

---

## O que NÃO mudou

- **Schema drift**: continua v4. Nenhuma coluna/tabela nova.
- **Modelo de dados**: `Conversation`, `Message`, `Tag` inalterados.
- **RF05/RF06.1 (busca)** e **RF08 (modelo de cifragem)**: inalterados; o
  único acréscimo é o aviso S7-8 ao exportar.
- **Invariantes 1–14** da Sprint 6 preservados. `data` só muda por data
  manual, exclusão e reenvio, ou pela opção explícita "manter data original"
  no encaminhamento (que cria uma **nova** mensagem, não altera a original).
- **Paginação (Sprint 6)**: seleção usa ids, então independe da janela.

---

## Pendências e limitações conhecidas

- Sem checagem de espaço livre antes de importar/encaminhar (dependência nova
  ou `MethodChannel`).
- Compartilhamento para fora: comportamento de texto/legenda e limites de
  mídia dependem do app de destino (testado em WhatsApp, Telegram, Instagram).
- Recebimento: o Arquivo aparece na share sheet do próprio Arquivo; excluir
  do chooser exigiria `EXTRA_EXCLUDE_COMPONENTS` (API 24+) — fora do escopo.
- Morte do processo com payload recebido: aceita a perda; a varredura de
  `share_tmp/` na abertura limpa temporários de saída (os de entrada são
  cache do SO).
- "Mover" (7.4b) e Sharing Shortcuts ficam como evoluções futuras.
- iOS: fora do escopo (Share Extension).
- Mídias em **claro** no filesystem (D7) — agravado ao compartilhar para fora.
- Título da conversa em claro (RF06.1).
- Sem "esqueci a senha".
- Herdadas das sprints anteriores: prévia da última mensagem na Home, varredura
  de órfãos em `media/`, player interno, `line_diff_engine.dart` (candidato a
  remoção).
- **Build Android**: exceção por nome (`receive_sharing_intent`) é manutenção
  ativa — ver `BUILD_ANDROID_CHANGES.md`.
- **`seedCarros`**: código Dart removido; `lib/dev/seed_carros.dart` e
  conversas de teste no aparelho ainda pendentes de limpeza manual.

---

## Arquivos novos (resumo)

- `lib/repositories/new_message.dart`
- `lib/security/app_lock_shield.dart`
- `lib/providers/security_providers.dart`
- `lib/screens/destination_picker_screen.dart`
- `lib/services/share_service.dart`
- `lib/services/share_receiver.dart`
- `lib/widgets/share_receiver_gate.dart`
- `BUILD_ANDROID_CHANGES.md` (o arquivo de build que você já produziu —
  renomear/salvar como documento da sprint)

## Arquivos alterados (resumo)

- `lib/database/app_database.dart` (construtor de teste `forTesting`)
- `lib/repositories/conversation_repository.dart`
- `lib/screens/chat_screen.dart`
- `lib/widgets/lock_on_background.dart`
- `lib/widgets/lost_capture_gate.dart`
- `lib/widgets/message_bubble.dart`
- `lib/widgets/attachment_picker_sheet.dart`
- `lib/services/attachment_service.dart`
- `lib/app.dart`
- `android/app/build.gradle.kts`
- `android/build.gradle.kts`
- `android/gradle.properties`
- `android/app/src/main/AndroidManifest.xml`
- `pubspec.yaml` (`share_plus`, `receive_sharing_intent`)

## Arquivos removidos

- `lib/dev/seed_carros.dart` (**pendente** — o `app.dart` já não importa mais).

---

## Critérios de aceite (do plano) — verificação

- **7.1:** `appendMessages` de N itens em 1 emissão do stream; atomicidade
  comprovada em smoke manual; `*Many` com >500 ids sem erro. ✅
- **7.2:** long-press seleciona; arrasto reordena; swipe/edição/abrir arquivo
  desativados em seleção; "selecionar tudo" independe da janela; copiar
  respeita `position`. ✅
- **7.3:** 30 fotos de uma vez na ordem escolhida; progresso + cancelamento +
  falha parcial funcionam; UI não trava. ✅
- **7.4:** encaminhar 100 mensagens entre conversas (inclusive protegida↔não
  protegida); excluir a origem não afeta o destino; aviso S7-8 aparece; tag
  recriada por nome. ✅
- **7.5:** compartilhar 1 e N arquivos para WhatsApp/Telegram/Instagram com
  nome de exibição; conversa protegida não re-bloqueia durante share sheet;
  temporários apagados. ✅
- **7.6:** receber 1 e N arquivos e texto, com app frio/aberto; texto vira
  mensagem antes dos anexos; destino protegido exige senha; cancelar limpa o
  cache. ✅
- **Transversais:** `flutter analyze` limpo; testes de crypto continuam
  passando; `aapt dump permissions` do release sem `INTERNET` (validar antes
  de distribuir).