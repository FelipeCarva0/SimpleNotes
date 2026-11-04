# Sprint 7 — Seleção, múltiplas mídias e compartilhamento

**Status: PLANEJADA.** Documento de decisões **antes** da implementação. Não
substitui o `SPRINT_7_CHANGES.md` (escrito ao final, com o que de fato foi
feito). Em caso de divergência, vale o `SPRINT_7_CHANGES.md` e, na falta dele,
este plano.

> Pré-requisito: Sprint 6 fechada (`SPRINT_6_CHANGES.md` escrito e `mapa.txt`
> atualizado). Esta sprint parte do código com paginação, `position` esparsa,
> cache de plaintext e re-bloqueio em background.

---

## 0. Escopo

Três funcionalidades pedidas, mais uma derivada do mesmo mecanismo:

1. **Seleção de mensagens** (qualquer tipo) com ações em lote: copiar,
   excluir, compartilhar (e, já existentes no repositório, tag e data).
2. **Recebimento de múltiplas mídias**: várias fotos/vídeos/arquivos de uma
   vez entram na conversa (galeria, seletor de arquivos).
3. **Compartilhamento**:
   - 3a. **Encaminhar** mensagens para outra Conversa do próprio app.
   - 3b. **Compartilhar para outros apps** (WhatsApp, Telegram, Instagram…).
   - 3c. **Receber compartilhamento** de outros apps (o Arquivo aparece na
     share sheet do Android).

Plataforma-alvo: **Android**. iOS fica fora (Share Extension é bem mais
pesada e não foi pedida).

---

## 1. Compatibilidade com RNF01 (offline-first)

**O app continua 100% offline.** Compartilhar no Android é comunicação entre
apps no mesmo aparelho, feita por Intents; o Arquivo nunca abre conexão.

| Fluxo | Mecanismo | Rede no Arquivo? |
|---|---|---|
| Receber (outro app → Arquivo) | `ACTION_SEND` / `ACTION_SEND_MULTIPLE`, URIs `content://` com permissão temporária | Não |
| Enviar (Arquivo → outro app) | Share sheet do sistema + `FileProvider` | Não (o outro app pode usar rede; é ação explícita do usuário e fora do nosso processo) |

Regra verificável: **o manifest de release não declara `INTERNET`**. Atenção:
o template Flutter inclui `INTERNET` nos manifests de `debug` e `profile`
(para hot reload); isso é aceitável, mas o `main/AndroidManifest.xml` e o
build de release não podem tê-la. Conferir com `aapt dump permissions` no
APK de release (critério de aceite da sprint).

Nenhuma permissão nova de runtime. Receber compartilhamento não exige
permissão de armazenamento.

---

## 2. Verificações prévias (antes de codar)

| # | Verificação | Por quê |
|---|---|---|
| V1 | `app.dart` **já envolve** a Home em `LockOnBackground`, mas o `mapa.txt` diz "NÃO ativado". Confirmar qual é o estado real e corrigir o mapa. | Define se hoje anexar/tirar foto numa conversa protegida já re-bloqueia. |
| V2 | `app.dart` contém `_DevSeedOnStart` / `seedCarros`. Remover antes de qualquer build de release. | Dado de teste e import de `dev/` em produção. |
| V3 | `MainActivity` com `launchMode` `singleTop` (padrão do template). | Necessário para a recepção (seção 9). |

---

## 3. Decisões consolidadas

| ID | Decisão | Justificativa |
|---|---|---|
| **S7-1** | Arquivos **nunca** são compartilhados entre conversas: encaminhar **copia** o arquivo físico para `media/<destino>/`. | `deleteConversationFolder` apaga a pasta inteira (invariante 8); apontar para o mesmo arquivo quebraria o destino ao excluir a origem. Evita contagem de referências. |
| **S7-2** | Primitiva única `appendMessages` (duas fases + 1 transação) usada por multi-anexo, encaminhar e receber. | Um caminho de código; uma única emissão do stream (1 rebuild, 1 scroll). |
| **S7-3** | **Escudo de auto-bloqueio** (`AppLockShield`) com janela de graça. | Picker, câmera e share sheet põem o app em `paused`; sem escudo, o Z1 re-bloqueia a conversa no meio da ação. |
| **S7-4** | Long-press **sem arrastar** entra no **modo seleção**; long-press **com arrasto** continua reordenando. | Padrão de apps de mensagens; preserva o gesto de reordenar (A4.2). |
| **S7-5** | Seleção guarda só **ids** (`Set<String>`). Ações em lote buscam por id no banco (`getMessagesByIds`, já decifrado, ordenado por `position`). | Sobrevive às mudanças da janela paginada. |
| **S7-6** | Copiar = **só texto**, em ordem de `position`; mídia é ignorada com aviso. | Copiar binário para a área de transferência não é confiável no Flutter. |
| **S7-7** | Encaminhar: data **de hoje** por padrão; opção "manter data original". Tag **não viaja** por padrão; opção "levar tag" recria no destino via `createOrGet` (nome normalizado + cor). | RF03 (data = momento da inclusão); tags são por Conversa (RF04). |
| **S7-8** | **Aviso de rebaixamento de segurança** antes de: (a) encaminhar de conversa protegida para não protegida; (b) compartilhar para outro app a partir de conversa protegida. | Os metadados passam a existir em claro fora do controle do app. |
| **S7-9** | Recebimento: texto + arquivos no mesmo compartilhamento → **uma mensagem de texto primeiro**, depois os anexos. | Decisão confirmada; comum em Chrome/Instagram. |
| **S7-10** | Encaminhar dentro do app **não usa Intent**; chama `appendMessages` direto. A share sheet do sistema é só para outros apps. | Evita desvio e loop com o próprio app. |
| **S7-11** | Multi-anexo processa em **lotes de 10** arquivos (um `appendMessages` por lote), com progresso "N de M", cancelamento e falha parcial. | Equilibra emissões do stream e feedback; falha de um lote não perde os anteriores. |

### Descartado

| O que | Por que |
|---|---|
| Referência compartilhada ao mesmo arquivo físico entre conversas | Contagem de referências + quebra o invariante 8. |
| Copiar mídia para a área de transferência | Sem suporte confiável em Flutter. |
| Sharing Shortcuts (conversas direto na share sheet) | Trabalho alto; em conversa protegida vazaria o título. Reavaliar depois. |
| Share Extension iOS | Fora de escopo (Android). |
| "Selecionar tudo" carregando mensagens completas | Basta carregar **ids** (ver 5.4). |

---

## 4. Alterações de especificação (v5.1 → v5.2)

- **RF02.3**: remover "um anexo por vez"; passa a aceitar **vários** arquivos
  por ação (galeria e seletor de arquivos). Câmera e gravador seguem unitários.
- **RF09 (novo) — Seleção de mensagens**: seleção múltipla de qualquer tipo,
  com copiar, excluir, definir tag, editar data, encaminhar e compartilhar.
- **RF10 (novo) — Importação em lote**: cada arquivo vira uma Mensagem; todas
  com a data do momento da inclusão, na ordem de seleção.
- **RF11 (novo) — Encaminhar e compartilhar**: para outra Conversa (cópia
  independente) e para outros apps (share sheet do Android).
- **RF12 (novo) — Receber compartilhamento**: o app é alvo de
  `ACTION_SEND`/`ACTION_SEND_MULTIPLE`; o usuário escolhe a Conversa de
  destino (desbloqueando-a se protegida).
- **RF08**: acrescentar que encaminhar/compartilhar a partir de conversa
  protegida **expõe** o conteúdo em claro no destino (com aviso prévio).
- **RNF01**: acrescentar "o app de release não declara `INTERNET`".

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

## 5. Blocos de implementação

### 7.1 — Fundação

**a) `appendMessages` (repositório)**

```dart
class NewMessage {
  final MessageType tipo;
  final String? texto;            // tipo == texto
  final File? arquivo;            // tipo != texto
  final String? nomeOriginal;
  final String? nomeExibicao;     // default: nomeOriginal
  final DateTime? data;           // null = hoje
  final bool dataEditadaManualmente;
  final String? tagId;            // já resolvida no destino
}

Future<List<String>> appendMessages(
  String conversationId,
  List<NewMessage> items, {
  bool Function()? isCancelled,
});
```

- **Fase 1 (fora da transação):** para cada item, `storage.saveFile` (arquivos),
  cifra metadados via `_encodeForStorage` (em paralelo, `Future.wait`).
  Checa `isCancelled` entre arquivos; se cancelar, apaga o que já copiou.
- **Fase 2 (uma transação):** calcula `_nextPosition` **uma vez** e atribui
  `base + i * _positionGap`; insere todas as linhas; atualiza `atualizadoEm`.
- **Falha em qualquer ponto:** apaga todos os arquivos copiados nesta chamada
  (mesmo padrão de `sendAttachment`). Devolve os ids criados.
- `sendAttachment` e `sendDraft` permanecem (envio unitário); opcionalmente
  `sendAttachment` passa a delegar para `appendMessages`.

**b) `getMessagesByIds(Iterable<String>)`** — devolve `List<Message>` já
decifrado, **ordenado por `position`**, consultando em blocos de 500 ids.
Reusa `_decryptRows` (e o cache de plaintext).

**c) `getMessageIds(conversationId)`** — só os ids, ordenados por `position`
(para "selecionar tudo" sem carregar conteúdo).

**d) Blocos em `*Many`** — `setMessageTagMany`, `setMessageDateMany` e
`deleteMessagesMany` passam a particionar `ids` em blocos de 500 dentro de uma
transação (invariante 20). Hoje, selecionar milhares de mensagens estoura o
limite de variáveis do SQLite.

**e) `AppLockShield`** (novo, `lib/security/app_lock_shield.dart`)

- Estado: contador/flag `armed`, e um `Timer` de graça.
- API: `Future<T> run<T>(Future<T> Function() action)` — arma antes, desarma
  no `finally`. Usado em câmera, galeria, seletor de arquivos, gravador e
  share sheet.
- **Desarme também no `resumed`**: o retorno do `Future` de alguns plugins
  (ex.: share sheet) pode ocorrer **antes** do app ir para `paused`; por isso
  o escudo só cai de fato no primeiro `resumed` depois de um `paused`.
- **Janela de graça (2 min):** se o app ficar em `paused` com o escudo
  armado, um timer chama `lockAll()` ao expirar. Impede que uma conversa
  protegida fique desbloqueada indefinidamente em segundo plano.
- Consumidores: `LockOnBackground` e `ChatScreen.didChangeAppLifecycleState`
  consultam `shield.armed` antes de limpar as chaves/o conteúdo.
- Provider: `appLockShieldProvider`.

**Testes (obrigatórios deste bloco):** `appendMessages` com drift em memória
(`NativeDatabase.memory`) e `MediaStorage.withBaseDir`: ordem/positions,
atomicidade (falha injetada limpa arquivos), cancelamento, conversa protegida
(metadados cifrados), blocos acima de 500 ids.

---

### 7.2 — Modo seleção (RF09)

**Estado em `ChatScreen`:** `_selecting`, `_selectedIds`, `_anchorId`.

**Gestos**
- Long-press **sem arrastar** (hoje abre `_showMessageActions`): entra no modo
  seleção com a mensagem marcada.
- Long-press **com arrasto >12 px**: reordenar (inalterado). Fora do modo
  seleção apenas.
- **Em modo seleção:** toque alterna a marcação; `Dismissible` fica com
  `direction: none`; reordenar desativado; toque em texto **não** edita; toque
  em mídia **não** abre o arquivo.
- Para isso, `MessageBubble` ganha `selectionMode` (um `IgnorePointer` sobre
  o conteúdo e uma camada de toque única que chama `onTap`).
- Voltar (`PopScope`) sai do modo seleção. Busca por palavra e seleção são
  mutuamente exclusivas: entrar em seleção fecha a busca.
- Visual: realce de fundo (mesmo mecanismo do `_highlightedId`) e ícone de
  marca no balão selecionado.

**Barra de seleção (`_buildSelectionAppBar`)**: botão fechar, "N selecionadas",
e ações: **Copiar**, **Compartilhar**, **Encaminhar**, **Excluir**; overflow
com **Definir tag**, **Editar data** e, só com 1 mensagem selecionada,
**Editar texto / Renomear / Substituir arquivo**. O menu atual
(`_showMessageActions`) deixa de ser aberto por long-press (suas ações
migram para a barra).

**Seleção ampla**
- **"Selecionar até aqui":** a partir de `_anchorId`, marca o intervalo na
  janela carregada.
- **"Selecionar tudo":** usa `getMessageIds` (só ids; independe da janela).
  Mostra o total real.

**Ações**
| Ação | Implementação |
|---|---|
| Copiar | `getMessagesByIds` → junta `conteudoTexto` das de texto, separadas por linha em branco, em ordem de `position` → `Clipboard.setData`. Aviso: "N arquivos não foram copiados" se houver mídia; se só houver mídia, informa e não copia. |
| Excluir | Confirmação com contagem e "inclui N arquivos"; `deleteMessagesMany`. Sem desfazer (diz no diálogo). |
| Tag / Data | `showTagPickerManySheet` + `setMessageTagMany`; `showDatePicker` + `setMessageDateMany` (já existem, usados na `SearchResultsScreen`). |
| Encaminhar / Compartilhar | Blocos 7.4 e 7.5. |

Após qualquer ação concluída, a seleção é limpa. Quando `_locked` vira
`true`, a seleção é descartada (invariante 17).

---

### 7.3 — Múltiplas mídias (RF10)

**`AttachmentService`**
- `pickMultipleMedia()` → `ImagePicker.pickMultipleMedia()` (fotos e vídeos
  juntos; tipo inferido por `inferType`).
- `pickMultipleFiles(FileType)` → `FilePicker.pickFiles(allowMultiple: true)`.
- Retornam `List<PickedAttachment>`. Câmera, vídeo e gravador continuam
  unitários.
- `attachment_picker_sheet`: "Foto da galeria" e "Vídeo da galeria" viram
  **"Galeria (fotos e vídeos)"** (multi). "Arquivo de áudio" e "Documento"
  passam a aceitar múltiplos. `AttachmentAction.gallery`/`videoGallery`
  fundem-se; ajustar o `switch` em `_onAttachPressed`.
- Todos os pickers rodam dentro de `AppLockShield.run`.
- `pickForReplace` continua **unitário** (substituir é 1 arquivo).

**Envio (`ChatScreen._sendPickedMany`)**
1. Estima o tamanho total; **checa espaço livre** e avisa se for insuficiente
   (as cópias dobram o espaço).
2. Divide em lotes de 10 (S7-11); para cada lote chama `appendMessages`.
3. Progresso "3 de 20" (substitui o `LinearProgressIndicator` indeterminado
   por determinado) com botão **Cancelar** (`isCancelled`).
4. Falha ou cancelamento no meio: mantém o que já entrou e informa
   "18 de 20 enviados".
5. Temporários (`isTemporary`) apagados no `finally`.
6. Ordem final = ordem de seleção; todas com a data de hoje.

Ponto de atenção: com paginação, `_onPage` já rola ao fim quando chega
mensagem nova no fim; com lotes, rola uma vez por lote (aceitável).

---

### 7.4 — Encaminhar para outra Conversa (RF11a)

**`DestinationPickerScreen`** (nova; **reutilizada** pela recepção, 7.6)
- Lista de Conversas com **busca por título** (mesmo `normalizeText` da Home),
  cadeado nas protegidas e botão **"Nova conversa"**.
- Protegida e bloqueada: `showUnlockDialog` + `verifyConversationPassword`
  (dentro do escudo, se necessário).
- A conversa de origem aparece desabilitada por padrão ("já está aqui").
- Devolve `conversationId`.

**Diálogo de opções** (após escolher o destino)
- ☐ **Manter data original** (padrão: desligado → data de hoje).
- ☐ **Levar tag** (padrão: desligado).
- **Aviso S7-8** quando origem protegida e destino não: "Os nomes e textos
  ficarão sem criptografia na conversa de destino."
  (Destino protegido a partir de origem não protegida é o caminho "seguro":
  nada a avisar, os metadados serão cifrados por `_encodeForStorage`.)

**Execução (`ConversationRepository.forwardMessages`)**
1. `getMessagesByIds(ids)` (já decifrado, em ordem de `position`).
2. Para cada mensagem, monta `NewMessage`: texto copia o conteúdo; arquivo usa
   o arquivo físico de origem (`storage.resolve`) como fonte do `saveFile`
   (copia para a pasta do destino). Arquivo ausente: pula e conta.
3. "Levar tag": resolve **uma vez** cada tag de origem para o destino via
   `TagRepository.createOrGet(nome, cor)`; mapa `tagIdOrigem → tagIdDestino`.
4. "Manter data": copia `data` e `dataEditadaManualmente`. Caso contrário,
   hoje e `false`.
5. `appendMessages(destino, itens)` em lotes de 10 (mesmo progresso de 7.3).
6. Resultado: "N encaminhadas" (+ "M ignoradas: arquivo indisponível").
   Oferece "Abrir conversa".

**Opcional (7.4b, só se aprovado):** **Mover** = encaminhar + `deleteMessagesMany`
na origem **depois** do sucesso de todo o encaminhamento. Para arquivos pode
mover o físico entre pastas (sem duplicar). Fica fora do escopo mínimo.

---

### 7.5 — Compartilhar com outros apps (RF11b)

- Dependência: `share_plus` (múltiplos arquivos + texto).
- `ShareService.shareMessages(List<Message>)`:
  1. **Aviso S7-8** se a conversa é protegida (confirmação explícita).
  2. Cria pasta temporária `share_tmp/<uuid>/`.
  3. Para cada arquivo: copia para o temporário **com o nome de exibição**
     (o disco tem `<uuid>.ext`); resolve colisões de nome (`nome (2).ext`) e
     sanitiza caracteres inválidos; mantém a extensão correta.
  4. Textos: juntos, na ordem de `position`, no parâmetro `text`.
  5. Chama `Share.shareXFiles(...)` dentro de `AppLockShield.run`.
  6. `finally`: apaga `share_tmp/<uuid>/`. Na abertura do app, varre
     `share_tmp/` e apaga o que sobrou (invariante 19).
- Configuração Android: `FileProvider` (o plugin cobre a maior parte;
  validar `<provider>` e `file_paths` no manifest).

**Limitações a documentar** (fora do nosso controle; testar em WhatsApp,
Telegram e Instagram):
- Texto junto com arquivos: o WhatsApp usa o texto como legenda; outros apps
  descartam o texto.
- O Instagram aceita poucas mídias por vez; limites de tamanho variam por app.
- Muitos arquivos grandes de uma vez podem demorar para o destino ler.

---

### 7.6 — Receber compartilhamento (RF12)

**Android (`AndroidManifest.xml`, `MainActivity`)**
- `intent-filter` para `ACTION_SEND` e `ACTION_SEND_MULTIPLE`, `category
  DEFAULT`, com `mimeType`: `text/plain`, `image/*`, `video/*`, `audio/*`,
  `application/*` e `*/*`.
- `launchMode="singleTop"` (verificação V3). Se o plugin escolhido exigir
  `singleTask`, ajustar e testar o comportamento do botão Voltar.
- **Sem** nova permissão e **sem** `INTERNET`.

**Dependência:** `receive_sharing_intent` **ou** `share_handler` — escolher
em um spike curto (30 min) validando: app frio, app aberto (`onNewIntent`),
vários arquivos, texto, e onde o plugin deixa os arquivos copiados (cache).
Requisito: devolver caminhos de `File` utilizáveis e permitir apagar o cache.

**`SharedPayload`**: `{ String? texto, List<File> arquivos }`.

**`ShareReceiverGate`** (widget novo, irmão do `LostCaptureGate` em `app.dart`)
- Escuta os dois casos: intent inicial (app frio) e stream (app aberto).
- Ao receber um payload: guarda em memória, empilha a `DestinationPickerScreen`
  no `Navigator` raiz (mesmo se o usuário estiver dentro de uma conversa).
- **Destino escolhido** (desbloqueando se protegida):
  1. Se há `texto`: cria uma mensagem de texto **primeiro** (S7-9).
  2. Os arquivos viram anexos via lotes de `appendMessages` (7.3), com
     progresso e cancelamento.
  3. `popUntil(first)` e abre a `ChatScreen` do destino.
  4. `finally`: apaga os arquivos do cache do plugin.
- **Cancelar** na tela de destino: descarta o payload e apaga o cache.
- **App vai para segundo plano** com payload pendente: se a Home exigir
  desbloqueio (re-bloqueio), descarta o payload e apaga o cache (não manter
  conteúdo de terceiros em memória indefinidamente).
- **Morte do processo** com payload pendente: aceita-se a perda (o usuário
  refaz o compartilhamento); a varredura de cache na abertura limpa o resto.
- Tipo inferido por `AttachmentService.inferType` (MIME). Texto que é só um
  link/URL vira mensagem de texto normal.
- Receber **para** conversa protegida é seguro: os metadados são cifrados por
  `_encodeForStorage`. As mídias seguem em claro no disco (limitação D7).

---

## 6. Ordem e lotes de entrega

| Bloco | Entrega | Depende de |
|---|---|---|
| **7.1** | `appendMessages`, `getMessagesByIds`, `getMessageIds`, blocos nos `*Many`, `AppLockShield`, testes | — |
| **7.2** | Modo seleção + copiar/excluir/tag/data | 7.1 |
| **7.3** | Multi-importação com progresso | 7.1 |
| **7.4** | `DestinationPickerScreen` + encaminhar | 7.1, 7.2 |
| **7.5** | Compartilhar com outros apps | 7.1, 7.2 |
| **7.6** | Receber compartilhamento | 7.1, 7.3, 7.4 (picker) |

- **Lote 1 (base):** 7.1 (+ V1/V2/V3). Resolve a fundação e o bug potencial de
  re-bloqueio ao anexar.
- **Lote 2 (uso diário):** 7.2 + 7.3 (independentes entre si depois do 7.1).
- **Lote 3 (circulação):** 7.4 + 7.5.
- **Lote 4 (entrada):** 7.6 (inclui o spike do plugin).

Ao fim de cada lote: `flutter analyze` limpo, testes de crypto (8) e os novos
passando, e atualização incremental do `mapa.txt`.

---

## 7. Riscos e mitigações

| Risco | Mitigação |
|---|---|
| Picker/share põe o app em `paused` e re-bloqueia a conversa | `AppLockShield` (7.1e) com desarme no `resumed` e janela de graça. |
| Retorno do `Future` do share_plus antes do `paused` | Escudo cai só no `resumed`, não no fim do `Future`. |
| Conversa protegida fica desbloqueada em background com o escudo armado | Janela de graça de 2 min → `lockAll()`. |
| Excluir conversa origem quebra mídia encaminhada | S7-1: cópia física por mensagem. |
| Falha no meio de `appendMessages` deixa arquivos órfãos | Fase 1 limpa tudo no erro; teste de falha injetada. |
| Seleção de milhares de ids estoura limite do SQLite | Blocos de 500 (invariante 20). |
| Copiar muitos arquivos grandes enche o disco | Checagem de espaço livre antes (7.3) e antes de encaminhar. |
| Destino protegido sem chave | Picker exige desbloqueio; `_encodeForStorage` continua lançando `StateError` (defesa em profundidade). |
| Rebaixamento de segurança (origem protegida → claro) | Aviso S7-8 com confirmação explícita. |
| Nomes de arquivo inválidos/duplicados ao compartilhar | Sanitização e sufixo `(n)` em `ShareService`. |
| Compartilhar do Arquivo para o próprio Arquivo | Não usa Intent para encaminhar (S7-10); caso externo vira importação normal (inofensivo; ver pendências). |
| Payload recebido some se o processo morrer | Aceito; varredura de cache na abertura. |
| Cache do plugin de recepção cresce | Apagar no `finally`/cancelamento + varredura na abertura. |
| Toque em mídia abre o arquivo durante a seleção | `selectionMode` em `MessageBubble` bloqueia os toques internos. |

---

## 8. O que **não** muda

- **Schema**: continua **v4** (nenhuma coluna/tabela nova).
- **Modelo de dados**: `Conversation`, `Message`, `Tag` inalterados.
- **RF05/RF06.1** (busca) e **RF08** (modelo de cifragem): sem mudança de
  mecanismo; só o aviso de exposição ao exportar.
- **Invariantes 1–14**: preservados. `data` só muda por data manual, exclusão
  e reenvio, ou pela opção explícita de encaminhar com/sem data original
  (que cria uma **nova** mensagem, não altera a original).
- **Paginação (Sprint 6)**: seleção usa ids, então independe da janela.

---

## 9. Métricas de validação

- **7.1:** `appendMessages` de 50 itens em uma única emissão do stream;
  atomicidade comprovada em teste; `*Many` com 5.000 ids sem erro.
- **7.2:** long-press seleciona; arrasto ainda reordena; swipe/edição/abrir
  arquivo desativados em seleção; "selecionar tudo" em 10k em ≤ 200 ms;
  copiar respeita `position`.
- **7.3:** 30 fotos de uma vez entram na ordem escolhida; progresso e
  cancelamento funcionam; falha parcial reportada; sem travar a UI.
- **7.4:** encaminhar 100 mensagens entre conversas (inclusive
  protegida↔não protegida); excluir a origem **não** afeta o destino;
  aviso S7-8 aparece; tag recriada por nome.
- **7.5:** compartilhar 1 e N arquivos para WhatsApp, Telegram e Instagram
  com o **nome de exibição**; conversa protegida **não** re-bloqueia durante
  a share sheet; temporários apagados.
- **7.6:** receber 1 e N arquivos e texto, com app frio e aberto; texto vira
  mensagem antes dos anexos; destino protegido exige senha; cancelar limpa o
  cache.
- **Transversais:** `flutter analyze` limpo; testes de crypto passam;
  `aapt dump permissions` do release **sem** `INTERNET`; conversa não
  protegida sem regressão.

---

## 10. Pendências e limitações que permanecem

- Mídias em **claro** no filesystem (D7) — agravado ao compartilhar para fora.
- Título da conversa em claro (RF06.1).
- Sem "esqueci a senha".
- Compartilhamento para fora: comportamento de texto/legenda e limites de
  mídia dependem do app de destino.
- Recebimento: o Arquivo aparece na share sheet do próprio Arquivo; excluir
  o app do chooser exigiria código nativo (`EXTRA_EXCLUDE_COMPONENTS`,
  API 24+). Fora do escopo.
- **Mover** (7.4b) e **Sharing Shortcuts** ficam como evoluções futuras.
- iOS (Share Extension): fora do escopo.
- Herdadas: prévia da última mensagem na Home, varredura de órfãos em
  `media/`, player interno, `line_diff_engine.dart` (candidato a remoção).

---

## 11. Referências

- `mapa.txt` — estado do projeto (corrigir V1).
- `SPRINT_6_PLAN.md` / `SPRINT_6_CHANGES.md` — paginação, `position` esparsa,
  cache de plaintext, re-bloqueio (Z1).
- `especificacao.md` v5.1 → v5.2 (RF02.3, RF08, RNF01 alterados; RF09–RF12
  novos).
- Este documento (Sprint 7 — planejamento).

## 12. Próximo passo

1. Resolver V1–V3.
2. Implementar o **Lote 1 (7.1)** com testes.
3. Atualizar a especificação para v5.2 e o `mapa.txt` (seção 8: invariantes
   15–20).
4. Seguir pelos lotes 2, 3 e 4; ao final escrever `SPRINT_7_CHANGES.md`.