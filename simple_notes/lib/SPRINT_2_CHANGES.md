# Sprint 2 — Arquivo (Arquivador) — Anexos de mídia: o que mudou

Cobre a Sprint 2 da especificação v5.1: seleção/captura de imagem, vídeo,
áudio e documento (RF02.3), armazenamento em filesystem com metadados no
banco (RF07), renderização por tipo (RNF03) e ações específicas de anexo
(RF02.4, RF02.5).

> Os documentos `SPRINT_0_CHANGES.md` e (se existir) `SPRINT_1_CHANGES.md`
> descrevem estados anteriores. Em caso de divergência, vale este arquivo.

---

## Decisões de escopo

| Decisão | Resultado |
|---|---|
| Reprodução de vídeo/áudio | Abre no **app padrão do sistema** via `open_filex` (sem player interno) |
| Quantidade de anexos | **Um por vez** (sem seleção múltipla) |
| Compressão | **Nenhuma**: arquivo copiado intacto; `image_picker` sem `imageQuality`/`maxWidth`/`maxHeight` |
| RF06 (correção da spec) | Home **sem prévia** da última mensagem, por segurança. A antiga Etapa 2.7 (prévia) foi removida da sprint |
| Método de validação | **Sem pasta `test/`**: validação executando o app no dispositivo (`flutter analyze` + `flutter run`) |

---

## Etapas executadas

| Etapa | Entrega |
|---|---|
| 2.0 | Dependências e permissões (Android/iOS) |
| 2.1 | `MediaStorage` (filesystem) |
| 2.2 | Repositório: enviar, renomear, substituir e excluir anexo |
| 2.3 | `AttachmentService` (pickers e gravador) |
| 2.4 | UI de anexo no composer |
| 2.5 | Renderização por tipo no `MessageBubble` |
| 2.6 | Ações de anexo no menu (renomear, substituir) |
| 2.7 | Robustez e fechamento (checklist abaixo) |

---

## Arquivos novos

```
lib/
├── storage/
│   └── media_storage.dart            # copia/lê/apaga arquivos; thumbnails em disco
├── services/
│   └── attachment_service.dart       # câmera, galeria, file_picker, gravador
├── widgets/
│   ├── attachment_picker_sheet.dart  # bottom sheet com as 7 ações de anexo
│   └── audio_recorder_dialog.dart    # diálogo com cronômetro durante a gravação
└── utils/
    └── format.dart                   # formatBytes()
```

## Arquivos alterados

| Arquivo | Alteração |
|---|---|
| `pubspec.yaml` | Novas dependências + `dependency_overrides` (ver abaixo) |
| `android/app/src/main/AndroidManifest.xml` | Permissões, `<uses-feature>` e `<queries>` |
| `ios/Runner/Info.plist` | `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`, `NSPhotoLibraryUsageDescription` |
| `lib/providers/conversation_providers.dart` | `mediaStorageProvider`, `attachmentServiceProvider`; `conversationRepositoryProvider` agora injeta `MediaStorage` |
| `lib/repositories/conversation_repository.dart` | Construtor recebe `MediaStorage`; `sendAttachment`, `renameAttachment`, `replaceAttachmentFile`; `deleteMessage` e `delete` (Conversa) apagam arquivos físicos |
| `lib/screens/chat_screen.dart` | Botão de anexo, fluxo de envio, barra de progresso, renomear/substituir, menu por tipo, `onTap` só para texto |
| `lib/widgets/message_bubble.dart` | Reescrito como `ConsumerWidget`, com ramificação por `MessageType` |

---

## Dependências

```yaml
dependencies:
  image_picker: ^1.1.2
  file_picker: ^8.1.2
  record: ^5.1.2
  mime: ^1.0.5
  video_thumbnail: ^0.5.3
  open_filex: ^4.5.0

dependency_overrides:
  record_linux: ^1.2.1   # corrige incompatibilidade com record_platform_interface 1.6.0
```

> O `dependency_overrides` existe porque o `pub get` resolveu `record_linux
> 0.7.x`, que não implementa `startStream` nem o novo `hasPermission`, e o
> build Android quebrava ao compilar o plugin do Linux. Reavaliar o override
> ao atualizar o `record`.

Android: `minSdkVersion 23` ou superior. iOS: plataforma mínima 13.0.

---

## Componentes

### `MediaStorage`
- Guarda **caminho relativo** no banco: `media/<conversationId>/<uuid>.<ext>`
  (o diretório base pode mudar entre atualizações, principalmente no iOS).
- `saveFile` **copia** (não move) o arquivo; a cópia é por streaming, sem
  carregar o arquivo na memória. Falha no meio remove o arquivo parcial.
- `resolve`, `exists`, `delete` (não falha se já não existir),
  `deleteConversationFolder`.
- Thumbnails de vídeo em `media_thumbs/<uuid>.jpg` (cache recriável),
  apagados junto com o arquivo e com a pasta da Conversa.
- Construtor `withBaseDir` permite injetar o diretório base.

### Repositório
- `sendAttachment`: copia o arquivo, insere a Mensagem (data de hoje,
  `position` seguinte, `atualizadoEm` atualizado) em transação. Se o banco
  falhar, remove o arquivo copiado.
- `renameAttachment`: altera só `arquivoNomeExibicao`. **Não toca em `data`.**
- `replaceAttachmentFile`: troca o arquivo físico mantendo `id`, `position`,
  `tagId`, `tipo`, nome de exibição e `data`. O arquivo antigo só é apagado
  depois que o banco aceitou a atualização.
- `deleteMessage`: remove o registro e depois o arquivo (ordem escolhida para
  nunca deixar mensagem apontando para arquivo inexistente).
- `delete` (Conversa): remove mensagens e conversa em transação e depois a
  pasta de mídia.

### `AttachmentService`
- Foto/vídeo por câmera e galeria (`image_picker`); documento e arquivo de
  áudio (`file_picker`); gravador (`record`, AAC `.m4a`, em diretório
  temporário).
- Devolve `PickedAttachment` (arquivo, nome original, tipo, `isTemporary`).
- Tipo inferido pelo MIME; o que não for imagem/vídeo/áudio vira `documento`.
- Cancelamento = `null`. Permissão negada = `AttachmentPermissionException`.
- Nome amigável para câmera: `Foto 20261006-153012.jpg`, `Vídeo ...`.
- `pickForReplace(tipo)`: seletor restrito ao mesmo tipo da mensagem.

### UI
- Clipe à esquerda do campo de texto; bottom sheet com: tirar foto, foto da
  galeria, gravar vídeo, vídeo da galeria, gravar áudio, arquivo de áudio,
  documento.
- Diálogo de gravação com cronômetro (parar e enviar / cancelar).
- `LinearProgressIndicator` e composer desabilitado durante a cópia.
- Temporários (gravação) são apagados após copiados para o storage.

### Renderização (`MessageBubble`)
- **Imagem:** miniatura 220 px com `cacheWidth` (decodifica pequeno).
- **Vídeo:** thumbnail gerado uma única vez e cacheado em disco; ícone de
  play e tamanho sobrepostos.
- **Áudio e documento:** cartão com ícone (por extensão), nome de exibição e
  tamanho.
- Toque abre no app do sistema; sem app disponível, mostra aviso.
- Arquivo ausente: "Arquivo indisponível", sem crash.
- Futuros resolvidos em `initState` (não refazem a cada rebuild) e
  recarregados em `didUpdateWidget` quando `arquivoPath` muda.

### Menu de long-press
- **Texto:** Editar texto, Editar data, Excluir.
- **Anexo:** Renomear arquivo, Substituir arquivo, Editar data, Excluir.
- Toque simples no balão só edita mensagens de texto.

---

## Regras de negócio preservadas

- `data` **nunca** muda por renomear ou substituir (RF02.4 / RF03).
- Substituir **mantém o tipo** da Mensagem.
- Substituir mantém o nome de exibição editado; só o nome original muda.
- `tagId` não é tocado por nenhuma operação de anexo.

---

## Limpezas feitas na sprint

- `_, __` → `_, _` em `chat_screen.dart`.
- `withOpacity` → `withValues(alpha: ...)` em `message_bubble.dart`.
- Removidos `test/widget_test.dart` (referenciava `MyApp`, inexistente) e
  testes de `MediaStorage` (decisão de validar no app).
- Import `dart:io` não usado removido de `chat_screen.dart`.

---

## Checklist de fechamento (Etapa 2.7)

- [ ] `flutter analyze` sem issues
- [ ] Vídeo grande (200 MB+) anexado sem congelar a UI
- [ ] `flutter run --profile`: scroll fluido com 50+ mídias e digitação com lista cheia
- [ ] Modo avião: enviar texto, anexar da galeria, gravar áudio, abrir, renomear, substituir, excluir
- [ ] Excluir Conversa com anexos: `media/<id>` e thumbnails removidos
- [ ] Substituir vídeo e excluir: sem sobras em `media/` e `media_thumbs/`
- [ ] Arquivo apagado externamente: "Arquivo indisponível"

---

## Limitações conhecidas e pendências (Sprint 6)

1. **Progresso real de cópia:** hoje só há barra indeterminada. Exigiria cópia
   em chunks com `openRead`/`openWrite`.
2. **Varredura de órfãos na inicialização:** se o app morrer entre a cópia e o
   insert, sobra arquivo em `media/`. Comparar `media/` e `media_thumbs/` com
   `arquivoPath` no banco.
3. **Player interno** de áudio/vídeo (`just_audio` / `video_player`) em vez de
   abrir no sistema.
4. **Seleção múltipla** de anexos.
5. **Nome de exibição de imagem e vídeo** não aparece no balão (só áudio e
   documento mostram nome). Renomear foto/vídeo só terá efeito visível na
   busca da Sprint 4, a menos que o nome passe a ser exibido sob a miniatura.
6. **Thumbnails de vídeo em massa** na primeira rolagem de uma conversa com
   muitos vídeos: monitorar em profile.
7. **Subtítulo de data na home** (`atualizadoEm`): decisão pendente entre
   manter ou remover, para seguir a spec "identificada por título" ao pé da
   letra.
8. **`line_diff_engine.dart`** continua sem uso (candidato a remoção).

---

## Próxima sprint

**Sprint 3 — Tags:** gesto de arrastar (swipe) para definir/substituir a tag
da mensagem, CRUD de Tag e exibição da seta colorida. O ponto de extensão no
menu (`_showMessageActions`) e a FK `Messages.tagId` (`ON DELETE SET NULL`)
já estão prontos.