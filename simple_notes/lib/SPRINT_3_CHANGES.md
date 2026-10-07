# Sprint 3 — Arquivo (Arquivador) — Tags: o que mudou

Cobre a Sprint 3 da especificação v5.1: gesto de arrastar (swipe) para
definir/substituir a tag da mensagem (RF04), CRUD completo de Tag, exibição
da tag junto à mensagem e gerenciamento de tags **por Conversa**.

Inclui também a correção de um bug da Sprint 2 (captura de foto/vídeo pela
câmera perdida quando o Android encerra o app), descrita ao final.

> Os documentos `SPRINT_0_CHANGES.md`, `SPRINT_1_CHANGES.md` (se existir) e
> `SPRINT_2_CHANGES.md` descrevem estados anteriores. Em caso de divergência,
> vale este arquivo.

---

## Decisões de escopo

| Decisão | Resultado |
|---|---|
| Gesto | Arrastar da **esquerda para a direita** abre o sheet de tag; o balão volta ao lugar |
| Exibição | **Fita** colorida que passa por trás do balão, de ponta a ponta da linha, com o título à esquerda (substituiu a ideia inicial de uma seta ao lado do balão) |
| Cores | **Paleta fixa** de 10 cores (hex) |
| Nome da tag | Gravado em **MAIÚSCULAS**, sem espaços nas pontas e com espaços internos colapsados; símbolos especiais permitidos |
| **Escopo da tag** | **Por Conversa**: a tag pertence a uma Conversa e só é visível nas mensagens dela. Conversas não acessam tags de outras |
| Nome duplicado ao **criar** | Não cria segunda tag: devolve a **existente na mesma conversa** (mantém a cor dela). O mesmo nome em outra conversa é uma tag independente |
| Nome duplicado ao **renomear** | **Bloqueado** com aviso, se o nome já pertence a outra tag **da mesma conversa** (não há fusão automática) |
| Mensagem x tag | No máximo **uma** tag por mensagem; nova tag substitui a anterior; "Sem tag" remove |
| Excluir tag | Remove só a tag; **as mensagens permanecem** |
| Excluir Conversa | **Exclui também as tags dela** |
| Data | **Nunca** alterada por operações de tag |
| `atualizadoEm` da Conversa | **Não** muda ao definir tag (tag não é atividade de conteúdo) |
| Acesso ao gerenciamento | Ícone na AppBar do **chat** e link "Gerenciar tags" no sheet (o ícone da Home foi removido, pois não há mais lista global) |
| Schema | **v4**: `Tags.conversationId`, com migração que preserva os dados |

---

## Etapas executadas

| Etapa | Entrega |
|---|---|
| 3.0 | Fundação: `PRAGMA foreign_keys`, paleta, `TagRepository`, providers |
| 3.1 | `setMessageTag` no `ConversationRepository` |
| 3.2 | Sheet de tag, editor de tag (nome + paleta) e `TagChip`; item "Definir tag" no long-press |
| 3.3 | Gesto de arrastar com `Dismissible` |
| 3.4 | Exibição da tag no balão, ao vivo (primeiro como seta, depois como fita) |
| 3.5 | Tela "Gerenciar tags" |
| Ajuste | Tags por conversa (schema v4, migração, escopo nos repositórios e na UI) |
| Extra | Correção da captura de câmera perdida (ver seção própria) |
| 3.6 | Fechamento (checklist abaixo) |

---

## Arquivos novos

```
lib/
├── repositories/
│   └── tag_repository.dart        # CRUD de Tag por conversa, normalização, contagem de uso
├── providers/
│   └── tag_providers.dart         # tagRepositoryProvider, tagsStreamProvider (family),
│                                  # tagUsageCountsProvider
├── screens/
│   └── tags_screen.dart           # Gerenciar tags da conversa (criar, editar, excluir)
├── widgets/
│   ├── tag_chip.dart              # seta colorida (sheets e lista de gerenciamento)
│   ├── tag_ribbon.dart            # fita atrás do balão (usada no chat)
│   ├── tag_editor_dialog.dart     # criar/editar tag (nome + paleta)
│   ├── tag_picker_sheet.dart      # sheet de tag da mensagem
│   └── lost_capture_gate.dart     # recuperação de captura de câmera perdida
└── utils/
    └── tag_colors.dart            # kTagPalette e tagColorFromHex()
```

## Arquivos alterados

| Arquivo | Alteração |
|---|---|
| `lib/database/tables.dart` | `Tags.conversationId` (FK para `Conversations`) |
| `lib/database/app_database.dart` | `schemaVersion` 4; migração v3 → v4; `beforeOpen` liga `PRAGMA foreign_keys = ON` |
| `lib/models/tag.dart` | Campo `conversationId` |
| `lib/repositories/conversation_repository.dart` | `setMessageTag` (valida que a tag existe e é da mesma conversa); `delete` de Conversa também apaga as tags dela |
| `lib/services/attachment_service.dart` | Marcador e recuperação de captura perdida |
| `lib/screens/chat_screen.dart` | `Dismissible` por mensagem, `_TagSwipeBackground`, `_openTagPicker`, item "Definir tag", mapa de tags da conversa ao vivo, ícone "Gerenciar tags" na AppBar, marcador de captura em `_onAttachPressed` |
| `lib/screens/home_screen.dart` | Sem ícone de tags (removido no ajuste por conversa) |
| `lib/widgets/message_bubble.dart` | Recebe `Tag? tag`; `Stack` com `TagRibbon` atrás do balão; balão encolhe de 78% para 66% da largura quando há tag |
| `lib/app.dart` | Home envolvida por `LostCaptureGate` |

---

## Componentes

### Foreign keys (`app_database.dart`)
O SQLite **não aplica foreign keys por padrão** e o drift não liga isso
sozinho: o `ON DELETE SET NULL` de `Messages.tagId` não funcionava na
prática. O `beforeOpen` agora executa `PRAGMA foreign_keys = ON`, depois da
migração. Além disso, a exclusão de Tag zera `tagId` explicitamente, sem
depender só do pragma.

Com as FKs ligadas, a exclusão de Conversa segue a ordem **mensagens → tags →
conversa**, dentro de uma transação.

### Migração v3 → v4
A coluna `conversation_id` é adicionada a `tags` (nullable no SQLite, pois
`ALTER TABLE ADD COLUMN` não aceita `NOT NULL` sem padrão; instalações novas
a criam `NOT NULL`). Cada par (tag, conversa) em uso vira uma **tag própria da
conversa**, as mensagens são reapontadas e as tags antigas sem conversa são
descartadas. As cópias passam a ser independentes entre si.

### `TagRepository`
- `normalizeName(raw)`: regra única (trim, colapsa espaços, `toUpperCase`);
  reaproveitar na busca da Sprint 4.
- `watchByConversation(conversationId)`: stream em ordem alfabética.
- `createOrGet(conversationId, nome, cor)`: em transação; devolve a existente
  se o nome normalizado já existir **na conversa**.
- `update(id, {nome, cor})`: lança `DuplicateTagNameException` se o nome já
  for de **outra** tag da mesma conversa.
- `delete(id)`: em transação, zera `tagId` das mensagens e apaga a tag.
- `countMessages(tagId)`: usado no aviso de exclusão.

### `ConversationRepository.setMessageTag`
- `tagId` com valor define ou substitui; `null` remove.
- Valida que a tag existe e **pertence à mesma conversa da mensagem**; falha
  com `StateError` legível caso contrário.
- Escreve **apenas** `tag_id`: `data`, `dataEditadaManualmente` e
  `atualizadoEm` ficam intactos.

### Providers
- `tagRepositoryProvider`.
- `tagsStreamProvider` (`family` por `conversationId`): tags de uma conversa.
- `tagUsageCountsProvider`: agrupa mensagens por `tagId` (mapa
  `tagId -> contagem`, ao vivo; ausente = 0). Os ids de tag são únicos, então
  o provider continua global.
- O `ChatScreen` monta um `Map<String, Tag>` a partir do stream de tags da
  conversa e passa a tag resolvida a cada balão, **sem join** na query de
  mensagens.

### Gesto de arrastar
- `Dismissible` com `direction: startToEnd`, limiar de 25%.
- `confirmDismiss` abre o sheet **sem `await`** e devolve `false`, então o
  balão nunca sai da lista e volta ao lugar na hora.
- Vibração leve ao disparar. O separador de data fica fora do `Dismissible`.
- Toque (editar texto, abrir arquivo) e long-press (menu) não conflitam.

### Sheet de tag (`tag_picker_sheet.dart`)
- Lista só as tags **da conversa da mensagem**.
- Mensagem **com** tag: topo mostra a tag atual com o botão **Configurar
  tag** (edição de nome e cor para as mensagens da conversa).
- Lista de tags (check na atual), **Nova tag**, **Sem tag** (só quando há
  tag) e **Gerenciar tags**.
- Criar com nome repetido reaproveita a existente e avisa por snack.

### Editor de tag (`tag_editor_dialog.dart`)
- `showCreateTagDialog(context, ref, conversationId)` e `showEditTagDialog`,
  reaproveitados pela tela de gerenciamento.
- O diálogo **permanece aberto** em caso de erro (ex.: nome repetido ao
  renomear), mostrando a mensagem no próprio campo.

### Exibição (`tag_ribbon.dart`)
- Fita de 20 px de altura (`TagRibbon.height`), atrás do balão, de ponta a
  ponta da linha, centrada na vertical (em imagem e vídeo fica no meio do
  balão). Título à esquerda, limitado a 26% da largura da tela, com
  reticências. Texto em branco ou preto conforme o contraste com a cor.
- Fita e balão se movem juntos no arrasto.

### Tela "Gerenciar tags" (`tags_screen.dart`)
- Recebe o `conversationId` e lista só as tags daquela conversa, com a
  quantidade de mensagens (ao vivo).
- Criar (botão `+`), editar (toque ou ícone) e excluir.
- Confirmação de exclusão consulta a contagem na hora e informa que as
  mensagens **permanecem**.

---

## Regras de negócio preservadas

- `data` e `dataEditadaManualmente` **nunca** mudam por operação de tag.
- `atualizadoEm` da Conversa não muda por operação de tag.
- Uma mensagem tem no máximo uma tag, e ela é da mesma conversa.
- Excluir uma tag nunca exclui mensagens nem arquivos.
- Excluir uma Conversa exclui as tags dela.
- Nenhuma operação de anexo (renomear, substituir) toca em `tagId`.

---

## Correção extra: captura de câmera perdida

**Sintoma:** ao tirar foto ou gravar vídeo pela câmera, o app dava uma
congelada com tela branca, voltava para a Home e a mídia não chegava à
conversa. Só ocorria com captura na hora; galeria não era afetada.

**Causa:** o Android encerra o processo do app enquanto a câmera está
aberta (pouca memória, comum em aparelhos de gama média). Ao voltar, o app
é recriado na Home e o resultado do picker se perde. Confirmado no log
(`Lost connection to device`) e pela recuperação bem-sucedida da foto.

**Solução:**
1. Antes de abrir a câmera, grava `pending_capture.txt` (diretório de
   suporte do app) com o id da conversa.
2. Fluxo normal: o resultado volta, o anexo é enviado e o marcador é
   apagado no `finally`.
3. Se o app foi morto, o marcador sobra. Na abertura seguinte, o
   `LostCaptureGate` lê o marcador, recupera o arquivo com
   `retrieveLostData()` do `image_picker`, envia o anexo para a conversa
   certa e abre o chat.

**Como reproduzir:** Opções do desenvolvedor → "Não manter atividades".

**Casos tratados:** usuário cancela a câmera (sem mensagem), conversa
excluída nesse meio tempo (ignora) e falha na recuperação (limpa o
marcador e segue). Só atua no Android.

---

## Checklist de fechamento (Etapa 3.6)

- [ ] `flutter analyze` sem issues
- [ ] Definir, trocar e remover tag em texto, imagem, vídeo, áudio e documento
- [ ] Arrastar uma mensagem que já tem tag permite trocar e configurar a tag
- [ ] Renomear e recolorir a tag atualizam todas as fitas na conversa aberta
- [ ] Tag criada na conversa A não aparece na conversa B; mesmo nome em B é uma tag independente
- [ ] Renomear/recolorir na A não afeta a B
- [ ] Nome duplicado ao criar (na mesma conversa) reaproveita a existente; ao renomear, é bloqueado
- [ ] Excluir tag (em uso e sem uso): mensagens permanecem, só perdem a fita, sem erro ao reabrir a conversa
- [ ] Excluir Conversa com tags: sem erro, e as tags somem junto
- [ ] Migração v3 → v4 por cima da instalação anterior preservou as fitas
- [ ] Contagens na tela "Gerenciar tags" corretas e atualizando
- [ ] `data` e ícone de data editada intactos após qualquer operação de tag
- [ ] Tags e atribuições persistem após fechar e reabrir o app
- [ ] `flutter run --profile`: scroll fluido com muitas mensagens marcadas
- [ ] Captura de câmera: recuperada com "Não manter atividades" ligado, sem duplicar com ele desligado

---

## Limitações conhecidas e pendências

1. **Spec a atualizar:** RF04 e o modelo de dados de `Tag` ainda não citam o
   escopo por Conversa nem `conversa_id`. Trecho sugerido: "cada Tag
   pertence a uma Conversa e só é visível nas Mensagens dela; o nome é único
   dentro da Conversa; excluir a Conversa exclui suas Tags".
2. **Sem filtro por tag ainda:** a busca por tag entra na **Sprint 4**
   (usar `TagRepository.normalizeName` para comparar nomes; as tags
   disponíveis no filtro são as da conversa aberta).
3. **`TagChip.compact` sem uso:** ficou da tentativa de seta compacta ao
   lado do balão; pode ser removido, voltando aos valores fixos.
4. **Import não usado** de `tag_repository.dart` em `tag_picker_sheet.dart`
   (remover se o `analyze` avisar).
5. **Tags sem uso:** não há limpeza automática de tags sem mensagens dentro
   de uma conversa; ficam disponíveis para reuso e podem ser excluídas na
   tela de gerenciamento.
6. **Sem fusão de tags:** renomear para um nome existente na conversa é
   bloqueado; unir duas tags exige reatribuir as mensagens e excluir a antiga.
7. **Sem copiar tags entre conversas:** para usar a mesma tag em outra
   conversa é preciso criá-la de novo lá.
8. **Acessibilidade do gesto:** o swipe tem alternativa no menu de
   long-press ("Definir tag").
9. **Pendências herdadas da Sprint 2:** progresso real de cópia, varredura
   de órfãos em `media/`, player interno, seleção múltipla, subtítulo de
   data na home e remoção de `line_diff_engine.dart`.

---

## Próxima sprint

**Sprint 4 — Busca e filtros:** busca de Conversa por título na tela
inicial (RF06.1) e, dentro da Conversa, busca por texto, data, tipo de
arquivo e tag, combináveis (RF05).