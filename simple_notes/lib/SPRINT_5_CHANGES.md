# Sprint 5 — Criptografia de acesso à Conversa (RF08)

**Status: CONCLUÍDA.** Este documento registra o que foi implementado ao
longo da Sprint 5 da especificação v5.1 (RF08) e as decisões tomadas.

> Os documentos `SPRINT_0_CHANGES.md` a `SPRINT_4_CHANGES.md` descrevem
> estados anteriores. Em caso de divergência, vale este arquivo.

---

## Decisões de escopo

| Decisão | Resultado |
|---|---|
| Modelo de proteção | **Flag única `Conversations.protegidoPorSenha`**: a senha ativa o gate de UI **e** a cifragem dos metadados. Não existe "só senha" nem "só cifra". |
| O que é cifrado | `Messages.conteudoTexto`, `Messages.arquivoNomeOriginal`, `Messages.arquivoNomeExibicao`, `Messages.arquivoMimeType` — colunas TEXT viram `base64(nonce‖ciphertext‖tag)`. |
| O que **não** é cifrado | `id`, `conversationId`, `position`, `tipo`, `tagId`, `data`, `dataEditadaManualmente`, `arquivoPath`, `arquivoTamanhoBytes`; **bytes de mídia** em `media/`; **título** da conversa. |
| Onde o gate acontece | **Home only** (D2): ao tocar numa conversa protegida e não desbloqueada, pede senha. A `ChatScreen` **não** re-bloqueia. |
| Duração da sessão | Enquanto o app estiver aberto. Fechar o app limpa o cache em memória. |
| Derivação | **PBKDF2-HMAC-SHA256**, 310.000 iterações, salt de 16 bytes. |
| Verificação | `sha256(chaveDerivada)` em hex, comparado em tempo constante. |
| Hash | `Conversations.senhaHash` (hex). |
| Salt | `Conversations.salt` (base64). |
| Cifra simétrica | **AES-256-GCM**, nonce de 12 bytes aleatório por campo. |
| Chave em memória | `Map<String, List<int>>` no `ConversationRepository` (`_unlockedKeys`). Nunca vai para disco. |
| Schema | **Inalterado (v4).** |
| Bytes de mídia | **Em claro** no filesystem (evolução futura). |
| "Esqueci a senha" | **Sem recuperação** (offline, sem servidor). Documentado. |

---

## Etapas executadas

| Etapa | Entrega | Status |
|---|---|---|
| 5.1 | Fundação criptográfica (`PasswordCrypto`) + testes unitários | Concluída |
| 5.2 | Cifragem/decifragem no repositório + cache de chave em memória | Concluída |
| 5.3 | UI: gate na Home, diálogos, menu ⋮ de proteção, item "Bloquear" no chat | Concluída |
| 5.4 | Correções de bugs (conversas não protegidas apareciam com `'••••••'`) | Concluída |
| 5.5 | Fechamento: documentação, limpeza, `flutter analyze` limpo | Concluída |

---

## Arquivos novos
lib/
├── security/
│ └── password_crypto.dart # PBKDF2, sha256, AES-256-GCM por campo
├── widgets/
│ ├── unlock_dialog.dart # pede senha (String?)
│ ├── password_setup_dialog.dart # define senha (String?)
│ └── password_change_dialog.dart # troca senha (record)
test/
└── security/
└── password_crypto_test.dart # 8 testes unitários

## Arquivos alterados

| Arquivo | Alteração |
|---|---|
| `pubspec.yaml` | `cryptography: ^2.7.0` |
| `lib/repositories/conversation_repository.dart` | + `_unlockedKeys`, `isUnlocked`, `lockConversation`, `lockAll`; `watchMessages` consulta `protegidoPorSenha` e decide "cru / decifra / placeholder"; + `protectConversation`, `unprotectConversation`, `changeConversationPassword`, `verifyConversationPassword` |
| `lib/screens/home_screen.dart` | `_openConversation` (gate), `_protectConversation`, `_changeConversationPassword`, `_unprotectConversation`; `_ConversationTile` com menu ⋮ condicional (Definir / Trocar / Remover senha) e cadeado |
| `lib/screens/chat_screen.dart` | Item **"Bloquear"** no menu ⋮ quando protegida + desbloqueada |

---

## Componentes

### Fundação criptográfica (`PasswordCrypto`)
- `newSaltBase64()`: salt de 16 bytes aleatórios.
- `deriveKey(password, saltBase64)`: PBKDF2-HMAC-SHA256, 310k iterações, 32 bytes.
- `hashKey(key)`: sha256 hex.
- `constantTimeEquals(a, b)`: comparação em tempo constante.
- `encryptField(plaintext, key)`: AES-256-GCM, nonce de 12 bytes; devolve `base64(nonce‖ciphertext‖tag)`.
- `decryptField(payload, key)`: inverso; lança em payload inválido ou chave errada.
- `looksEncrypted(payload)`: heurística de sanidade.

### Repositório
- **Sessão**: `_unlockedKeys` (mapa em memória), `isUnlocked`, `lockConversation`, `lockAll`.
- **`watchMessages`**: consulta `protegidoPorSenha` por emissão:
  - Não protegida → texto cru.
  - Protegida + chave → decifra.
  - Protegida + sem chave → placeholders `'••••••'` / `'••••'`.
- **`protectConversation(id, senha)`**: gera salt, deriva chave, cifra as mensagens existentes, grava `senhaHash`/`salt`/`protegidoPorSenha=true`, em transação. Deixa a conversa desbloqueada na sessão.
- **`unprotectConversation(id, senha)`**: verifica, decifra tudo, limpa `senhaHash`/`salt`/`protegidoPorSenha=false`, em transação.
- **`changeConversationPassword(id, atual, nova)`**: verifica, deriva nova, re-cifra tudo (decifra com a antiga, cifra com a nova), troca hash/salt. Mantém a sessão desbloqueada com a nova chave.
- **`verifyConversationPassword(id, senha)`**: devolve a chave (e guarda no cache) ou `null`.

### UI
- **Home**: tocar numa conversa protegida e não desbloqueada → `UnlockDialog`. Senha errada → SnackBar. Senha correta → abre.
- **Menu ⋮ da Home**: **Renomear**, **Definir senha** (se não protegida), **Trocar senha** / **Remover senha** (se protegida), **Excluir**.
- **`ChatScreen`**: menu ⋮ ganha **"Bloquear"** quando a conversa está protegida e desbloqueada. Remove a chave da sessão e volta para a Home.
- **Diálogos**: `showUnlockDialog`, `showPasswordSetupDialog` (com confirmação, mínimo 4 caracteres), `showPasswordChangeDialog` (atual + nova + confirmação).

---

## Regras de negócio preservadas (Sprint 5)

- **Ativar senha** cifra os metadados de **todas** as mensagens existentes; novas mensagens são cifradas na hora do envio (`sendDraft`/`sendAttachment` passam a cifrar — **correção pendente**, ver "Limitações").
- **Desativar** decifra tudo de volta.
- **Trocar** re-cifra tudo (idempotente).
- **Nenhuma dessas operações altera** `position`, `data`, `dataEditadaManualmente`, `tagId`, nem o `atualizadoEm` da conversa.
- **A chave nunca sai da memória.**
- **Senha nunca é gravada.**
- **Bytes de mídia permanecem em claro no filesystem** (documentado).
- **Título da conversa permanece em claro** (a Home precisa dele para a busca por título, RF06.1).
- **Conversa não protegida não é afetada** em nada.

---

## Checklist de fechamento (Sprint 5)

- [ ] `flutter analyze` sem issues
- [ ] `flutter test test/security/password_crypto_test.dart` — 8 testes passam
- [ ] Conversa **não protegida**: abre direto; texto e nomes de arquivo visíveis
- [ ] Menu ⋮ da Home: "Definir senha" só aparece em conversas não protegidas
- [ ] Definir senha: dialog pede senha + confirmação (mín. 4 chars); ao definir, ícone vira 🔒
- [ ] Tocar em conversa protegida (sessão sem chave): pede senha
- [ ] Senha errada: SnackBar "Senha incorreta", não abre
- [ ] Senha correta: abre com conteúdo **decifrado**
- [ ] Menu ⋮ do chat numa conversa protegida+desbloqueada: "Bloquear" aparece; tocar volta para Home
- [ ] Trocar senha: antiga deixa de funcionar; nova funciona
- [ ] Remover senha: pede atual; após remover, ícone volta a 💬 e abrir não pede senha
- [ ] Fechar e reabrir o app: conversa protegida volta a pedir senha
- [ ] Abrir `arquivo.sqlite` num visualizador: `conteudoTexto` de conversa protegida está em base64; de conversa não protegida está em texto puro
- [ ] `flutter run --profile`: abrir conversa protegida (com decifragem) não trava a UI

---

## Limitações conhecidas (pós-Sprint 5)

1. **Mensagens novas em conversa protegida**: `sendDraft` e `sendAttachment` **ainda gravam texto puro** — só `protectConversation` cifra o que já existe. Isso significa que, se uma conversa protegida receber uma mensagem nova, ela **não será cifrada** até um futuro `re-protect`. **Correção necessária** (ver "Próximos passos").
2. **Bytes de mídia em claro** no filesystem (D7 aceito).
3. **Título da conversa em claro** (necessário para RF06.1).
4. **"Esqueci a senha"**: sem recuperação.
5. **Re-bloqueio em background**: não implementado (D2 = Home only). Fácil de adicionar via `WidgetsBindingObserver` + `lockAll()` no `paused`.
6. **`senhaHash` é `sha256(chave)`**, sem HMAC de senha — se alguém roubar o BD, pode tentar força bruta contra a chave derivada. É aceitável offline (310k iterações por tentativa), mas **uma evolução** seria derivar com o próprio salt e comparar hash direto — o que já é o caso.

---

## Próximos passos (recomendados)

1. **Corrigir `sendDraft` / `sendAttachment`** para cifrar mensagens novas em conversas protegidas:
   - Se `conversation.protegidoPorSenha` e a chave estiver em `_unlockedKeys`, cifra `conteudoTexto`/nomes antes do `INSERT`.
   - Se a chave **não** estiver (situação anômala), lança/retorna erro — o gate deveria impedir isso.
2. **Re-bloqueio em background** (opcional, 1 linha no `app.dart`).
3. **Sprint 6** — polimento de performance, mídia pesada, robustez offline, UX.

---

## Atualizações sugeridas para a especificação

- **RF08 (detalhamento)**: a senha ativa **duas** proteções juntas — gate de UI e cifragem de metadados (`conteudoTexto`, `arquivoNomeOriginal`, `arquivoNomeExibicao`, `arquivoMimeType`). Bytes de mídia e título ficam em claro (documentado).
- **Modelo de dados**: `Conversations.protegidoPorSenha` (bool), `senhaHash` (hex sha256), `salt` (base64). Schema permanece **v4**.
- **Estrutura de diretórios**: `security/password_crypto.dart`, `widgets/unlock_dialog.dart`, `widgets/password_setup_dialog.dart`, `widgets/password_change_dialog.dart`.