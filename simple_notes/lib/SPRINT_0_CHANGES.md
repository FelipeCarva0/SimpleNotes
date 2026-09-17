# Sprint 0 — Arquivo (Arquivador) — o que mudou

Este pacote contém os arquivos **novos/alterados** de `lib/` para satisfazer
a Sprint 0 da especificação v5.1 (Fundação: migração de schema, tela
inicial de Conversas, CRUD de Conversa). Extraia sobre o seu `lib/` atual
substituindo os arquivos de mesmo nome.

## Arquivos para EXCLUIR do projeto atual
Foram substituídos e não devem continuar existindo (a Sprint 0 já elimina a
dívida técnica de Bloco por completo, não só na spec):

- `lib/models/block.dart`
- `lib/models/page.dart` → agora `lib/models/conversation.dart`
- `lib/models/line.dart` → agora `lib/models/message.dart`
- `lib/providers/block_providers.dart`
- `lib/providers/page_providers.dart` → agora `lib/providers/conversation_providers.dart`
- `lib/repositories/block_repository.dart`
- `lib/repositories/page_repository.dart` → agora `lib/repositories/conversation_repository.dart`
- `lib/screens/editor_screen.dart` → agora `lib/screens/chat_screen.dart`
- `lib/database/app_database.g.dart` — **apagar e regenerar** (ver abaixo)

## Arquivos deste pacote
```
lib/
├── main.dart                          # alterado (ArquivoApp)
├── app.dart                           # alterado (ArquivoApp, título "Arquivo")
├── database/
│   ├── tables.dart                    # reescrito: Conversations, Messages, Tags (sem Blocks)
│   └── app_database.dart              # reescrito: schemaVersion 3 + migração
├── models/
│   ├── conversation.dart              # novo (substitui page.dart)
│   ├── message.dart                   # novo (substitui line.dart; usado a partir da Sprint 1)
│   └── tag.dart                       # novo (usado a partir da Sprint 3)
├── repositories/
│   └── conversation_repository.dart   # novo (substitui page_repository.dart; CRUD de Conversa)
├── providers/
│   └── conversation_providers.dart    # novo (substitui page_providers.dart + block_providers.dart)
├── screens/
│   ├── home_screen.dart               # reescrito: só lista Conversas, sem Blocos
│   └── chat_screen.dart               # novo (substitui editor_screen.dart; stub até a Sprint 1)
└── diff/
    └── line_diff_engine.dart          # inalterado (utilitário legado, ver spec)
```

## Passo obrigatório após copiar os arquivos
O `app_database.g.dart` é gerado automaticamente pelo drift a partir de
`tables.dart` — não faz parte deste pacote porque é derivado, não escrito à
mão. Depois de copiar os arquivos, rode na raiz do projeto Flutter:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## Decisões técnicas registradas nesta Sprint
1. **Tag 1:N, sem tabela associativa** — `Messages.tagId` é uma FK simples
   nullable, com `onDelete: KeyAction.setNull` (excluir uma Tag não excluir
   as mensagens, só limpa o vínculo). Reflete a decisão de "no máximo uma
   Tag por Mensagem".
2. **Migração v2 → v3 destrutiva, por decisão explícita** — como o app
   ainda não está em produção, a migração dropa `blocks`, `lines` e `pages`
   e recria `conversations`/`messages`/`tags` do zero, em vez de fazer
   `RENAME`/`ALTER` coluna a coluna. Isso fecha, na prática, a dívida
   técnica da tabela `Blocks` que a spec v4.0 já tinha descontinuado mas o
   código nunca removeu. **Se este código só for aplicado depois de o app
   já ter usuários com dados reais**, essa migração precisa ser reescrita
   para preservar conteúdo.
3. **Nome do arquivo do banco** trocou de `secure_notes.sqlite` para
   `arquivo.sqlite` — coerente com a migração já ser destrutiva.
4. **Escopo desta Sprint**: só CRUD de Conversa + fundação de schema. As
   tabelas `Messages` e `Tags` já existem (para não exigir outra migração
   na Sprint 1/3), mas as operações sobre elas (rascunho, envio, edição,
   swipe-to-tag) ainda não têm repositório — isso é intencional, é o
   próximo passo (Sprint 1 e Sprint 3 da metodologia).
