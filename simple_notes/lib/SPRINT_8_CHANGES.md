# Sprint 8 — Biometria como segunda porta de desbloqueio

## Escopo
- Ativar/desativar biometria por conversa protegida.
- Abertura de conversa protegida: **biometria primeiro** (se houver
  enrolamento), senha como fallback. Nunca dois diálogos empilhados.
- Fluxo "Configurar biometria" a partir do rodapé do diálogo de senha.
- Migração total para o novo contrato `PasswordUnlockResult` (sealed):
  `home_screen.dart` e `destination_picker_screen.dart`.

## Estratégia
- **A — senha embrulhada**: a chave derivada por senha (32 bytes) é
  guardada cifrada pelo `flutter_secure_storage` (Keystore-backed) e só
  é liberada após `local_auth.authenticate`. A senha continua funcionando
  (a chave é rederivável). `senhaHash`/`salt`/`protegidoPorSenha` **não
  mudam**; schema continua **v4**.

## Dependências
- `local_auth: ^2.3.0`
- `flutter_secure_storage: ^9.2.2`

## Build
- `android/app/src/main/kotlin/com/example/simple_notes/MainActivity.kt`:
  `FlutterActivity` → `FlutterFragmentActivity` (exigido pelo `local_auth`
  no Android).
- `android/app/src/main/AndroidManifest.xml`:
  `<uses-permission android:name="android.permission.USE_BIOMETRIC" />`,
  logo abaixo das permissões existentes (`CAMERA`, `RECORD_AUDIO`,
  `READ_MEDIA_*`), antes de `<application>`.
- **Não** adiciona `INTERNET`. RNF01 / invariante 27 preservados.

## Arquivos — mapa canônico

> **Atenção**: dois arquivos em `lib/widgets/` têm nomes parecidos e
> contêm coisas **diferentes**. O mapa abaixo é a fonte da verdade.

| Arquivo | Contém | Símbolos públicos |
|---|---|---|
| `lib/widgets/unlock_dialog.dart` | Diálogo de **senha** | `showPasswordUnlockDialog`, `PasswordUnlockResult`, `PasswordUnlockResultPassword`, `PasswordUnlockResultUseBiometric`, `PasswordUnlockResultSetupBiometric` |
| `lib/widgets/biometric_unlock_dialog.dart` | Diálogo de **biometria** | `showBiometricUnlockDialog`, `BiometricDialogResult` (`success`/`usePassword`/`cancelled`) |
| `lib/security/unlock_flow.dart` | Orquestrador dos dois | `runUnlockFlow`, `UnlockPurpose`, `UnlockOutcome` |
| `lib/security/biometric_unlock.dart` | Cofre + `local_auth` | `BiometricUnlock` |
| `lib/security/biometric_storage_keys.dart` | Nomes de chaves no secure storage | `BiometricStorageKeys` |

### Arquivos alterados ou criados

- **Novo** `lib/security/biometric_storage_keys.dart` — prefixos das
  chaves guardadas no `flutter_secure_storage`
  (`biometric_key__<conversationId>` e `biometric_meta__<conversationId>`).
- **Novo** `lib/security/biometric_unlock.dart` — `BiometricUnlock`:
  `isAvailable`, `hasEnrollment`, `enable`, `disable`, `disableAll`,
  `unlock`. Usa `local_auth` com `biometricOnly: true`, `stickyAuth: true`,
  `useErrorDialogs: true`. Storage com
  `AndroidOptions(encryptedSharedPreferences: true)`.
- **Novo** `lib/security/unlock_flow.dart` — `runUnlockFlow`,
  `UnlockPurpose { openConversation, manageBiometrics }`,
  `UnlockOutcome { unlockedByBiometric, unlockedByPassword, cancelled,
  wrongPassword }`. Senha errada **reabre o diálogo internamente** (nunca
  retorna `wrongPassword` hoje; valor reservado).
- **Reescrito** `lib/widgets/unlock_dialog.dart` — antes
  `showUnlockDialog` retornava `String?`; agora
  `showPasswordUnlockDialog` retorna `PasswordUnlockResult?` (sealed) e
  mostra rodapé condicional com "Desbloquear com biometria" (se já tem
  enrolamento) **ou** "Configurar biometria nesta conversa" (se ainda não
  tem, o aparelho suporta, e `allowSetupBiometric` é true).
- **Reescrito** `lib/widgets/biometric_unlock_dialog.dart` — antes
  `BiometricUnlockChoice`; agora `BiometricDialogResult` (`success`/
  `usePassword`/`cancelled`). Dispara `local_auth` **no `initState`**
  (post-frame), sem o usuário precisar tocar em "Tentar".
- **Alterado** `lib/providers/security_providers.dart` —
  `biometricUnlockProvider` (novo `Provider<BiometricUnlock>`).
- **Alterado** `lib/repositories/conversation_repository.dart` —
  dois métodos novos, logo abaixo de `verifyConversationPassword`:
  `unlockWithKey(convId, key)` (põe a chave na sessão após biometria
  validar) e `unlockedKeyOrNull(convId)` (lê a chave da sessão, para
  "Ativar biometria" aproveitar a senha já digitada). Nada mais muda
  neste arquivo.
- **Alterado** `lib/screens/home_screen.dart` —
  - `_openConversation` chama `runUnlockFlow` (biometria primeiro se
    houver);
  - `_unprotectConversation` usa `showPasswordUnlockDialog` e, ao remover
    a senha, **também** chama `bio.disable(convId)` (a chave enrolada
    perde sentido sem `senhaHash`/`salt`);
  - `_onBiometricPressed` (novo): anti-reentrância via `_biometricBusy`,
    garante chave na sessão via `runUnlockFlow(purpose: manageBiometrics)`,
    ativa (`bio.enable`) ou desativa (`bio.disable`, com confirmação);
  - **BUGFIX**: no `_ConversationTile`, o `switch` do `onSelected` tinha
    `case 'change':` **vazio** (fall-through implícito para o próximo
    `case`), disparando `onChangePassword` **e** `onBiometric` juntos.
    Cada `case` agora tem seu próprio bloco. Era a causa do "diálogo de
    troca de senha fica aberto ao fundo".
- **Alterado** `lib/screens/destination_picker_screen.dart` —
  `_pick` chama `runUnlockFlow` para destino protegido; `_picking`
  (anti-reentrância) adicionado. `ForwardOptions` e
  `showForwardOptionsDialog` **inalterados**.

### Arquivos intocados
- `lib/database/tables.dart`, `lib/database/app_database.dart` — schema
  continua **v4**.
- `lib/security/password_crypto.dart` — nenhuma primitiva muda.
- `lib/security/app_lock_shield.dart`, `lib/widgets/lock_on_background.dart`
  — comportamento de re-bloqueio preservado.
- `lib/widgets/password_change_dialog.dart`,
  `lib/widgets/password_setup_dialog.dart` — sem mudança.
- `lib/services/share_*` — inalterados.
- `lib/screens/chat_screen.dart` — inalterado (a biometria só atua na
  abertura; dentro da conversa nada muda).

## Invariantes preservados
- 10–14 (cifragem): o **quê** é cifrado não muda; só o **como** a chave
  entra em `_unlockedKeys`.
- 11 (`_unlockedKeys` só em memória): a chave guardada no secure storage
  é a **mesma** chave derivada, cifrada em repouso pelo Keystore; nunca
  fica em claro no disco.
- 16/17/21/22 (background/lock/shield): inalterados. `lockAll` continua
  limpando `_unlockedKeys`; a biometria recompõe a chave na próxima
  abertura.
- 23 (`appendMessages`): inalterado.
- 27 (release sem `INTERNET`): preservado.

## Novos invariantes (proposta para a spec v5.3)
- **29.** Ativar biometria exige a chave na sessão
  (`unlockedKeyOrNull`); nunca guarda a chave sem que o usuário tenha
  provado a senha nesta execução.
- **30.** Senha e biometria são portas **independentes**; remover uma
  não invalida a outra. `unprotectConversation` remove **também** o
  enrolamento biométrico (a chave perde sentido).
- **31.** Desativar biometria = `BiometricUnlock.disable` (só apaga o
  cofre paralelo); não toca em `senhaHash`/`salt`/`protegidoPorSenha`
  nem recifra nada.

## Smoke manual (validado)
1. Conversa protegida sem biometria → abre `showPasswordUnlockDialog`
   com rodapé **"Configurar biometria nesta conversa"** (se aparelho
   suporta). Senha + "Configurar" → sensor nativo abre; senha correta +
   digital OK → conversa abre, biometria fica ativa.
2. Mesma conversa, próxima abertura → biometria abre **direto**, sem
   escolha. "Usar senha" → diálogo de senha. Sucesso → abre.
3. Menu ⋮ → "Biometria" (já ativa) → "Desativar biometria" → confirma →
   desativa. Próxima abertura → cai direto na senha.
4. Menu ⋮ → "Trocar senha" → **não** abre biometria junto (bugfix).
5. Encaminhar para conversa protegida: com biometria → sensor direto;
   sem biometria → diálogo de senha.
6. App em background → `lockAll` limpa `_unlockedKeys`; ao voltar e abrir
   a conversa, biometria resolve.
7. Remover senha → enrolamento biométrico é limpo automaticamente
   (`bio.disable`).

## Alertas e pendências (para a v5.3.1)
- **Troca de senha × biometria**: `changeConversationPassword` re-cifra
  os metadados com a **nova** chave, mas o enrolamento biométrico
  continua com a **antiga**. Efeito: na próxima abertura com biometria, a
  chave antiga **não decifra** (o `decryptField` lança) → cai em senha.
  Comportamento **esperado e documentado**; o usuário precisa reconfigurar
  a biometria depois de trocar a senha. Correção planejada para a
  v5.3.1: após o sucesso de `changeConversationPassword`, se
  `bio.hasEnrollment(id)`, chamar `bio.enable(id, newKey)` com a chave da
  sessão (`repo.unlockedKeyOrNull(id)`) — exige uma confirmação
  biométrica adicional, o que é razoável logo após provar a senha.
- **`destination_picker_screen`**: `runUnlockFlow` abre o sensor **sobre**
  o picker. Funcional; ajuste de UX (fluxo de desbloqueio antes do picker)
  fica para a v5.3.1 se incomodar.
- **Desinstalação**: o `flutter_secure_storage` guarda por app, não por
  usuário. Reinstalar limpa. Sem ação.
- **iOS**: `IOSOptions(accessibility: first_unlock_this_device)` é o
  padrão do plugin. Se quiser restringir mais, ajustar no construtor de
  `BiometricUnlock`.
- **`UnlockOutcome.wrongPassword`**: valor reservado no enum; o
  `runUnlockFlow` nunca o retorna (senha errada reabre internamente). Pode
  ser removido na v5.3.1 se ninguém usar.
- **Build Android**: `MainActivity` virou `FlutterFragmentActivity`.
  Manter essa base enquanto `local_auth` for usado. Se migrar para um
  plugin que aceite `FlutterActivity`, reverter.