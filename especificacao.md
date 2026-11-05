# Especificação da Aplicação — Arquivo

**Versão:** 5.2
**Plataforma:** Mobile (Flutter)

> **Nota de versão (5.0 → 5.1) — decisões confirmadas:** (1) cada Mensagem
> possui **no máximo uma Tag** (não múltiplas); (2) a criptografia protege
> apenas o **acesso à Conversa** (tela de bloqueio/desbloqueio), sem
> distinção de cifragem por tipo de conteúdo; (3) a busca é **restrita ao
> interior de uma Conversa** — a única busca que atravessa Conversas é por
> **nome/título da Conversa**, na tela inicial; (4) todo o conteúdo herdado
> da v4.0 é **confirmado como requisito definitivo**. As seções abaixo já
> refletem essas decisões.
>
> **Nota de versão (5.1 → 5.2) — Sprint 7 entregue:** (1) anexação de
> arquivos passa a aceitar **vários arquivos por ação** (galeria e seletor
> de arquivos; câmera e gravador continuam unitários) — RF02.3 alterado;
> (2) **seleção múltipla de mensagens na própria Conversa** com ações em
> lote — RF09 novo; (3) **importação em lote** — RF10 novo; (4) **encaminhar
> para outra Conversa** e **compartilhar para outros aplicativos** — RF11
> novo; (5) **receber compartilhamento** de outros apps via share sheet do
> Android — RF12 novo; (6) RF08 acrescenta que **encaminhar/compartilhar a
> partir de conversa protegida expõe o conteúdo em claro no destino**
> (com aviso prévio); (7) RNF01 acrescenta que **o app de release não declara
> INTERNET**. O modelo de dados **não muda**: schema continua v4; nenhuma
> coluna/tabela nova. Foram acrescentados invariantes 15–28 (ver seção
> "Modelo de dados"). Toda a infraestrutura de segurança da v5.1 é mantida
> (cifra por Conversa, PBKDF2 em isolate, cache LRU de plaintext, re-bloqueio
> em background). É introduzido o **AppLockShield** — um escudo com janela de
> graça que impede o re-bloqueio automático de disparar no meio de um picker
> de mídia ou de uma share sheet, mantendo o re-bloqueio normal quando o app
> fica em segundo plano "parado".


> **Nota de versão (5.2 → 5.3) — Sprint 8 entregue:** a proteção por senha
> de uma Conversa (RF08) ganha uma **segunda porta**: biometria do
> aparelho. A Conversa passa a poder ser protegida por senha **e/ou**
> biometria, bastando **uma** correta para liberar o acesso. Ativar a
> biometria exige a senha (a chave derivada é guardada em
> `flutter_secure_storage`, protegida pelo Keystore). A senha continua
> funcionando em qualquer cenário. **Nenhuma alteração de schema**
> (continua v4); a chave enrolada é guardada fora do banco. Foram
> acrescentados os invariantes 29–31 (ver "Modelo de dados"). O app de
> release continua **sem** `INTERNET` (RNF01 / invariante 27), agora com
> `USE_BIOMETRIC` no manifest.
---

## Visão geral

Aplicativo mobile para arquivar texto e mídia de forma organizada, com a
interface de uma conversa de chat. O usuário digita texto ou anexa um
arquivo (foto, vídeo, áudio ou documento) e ele aparece na conversa como uma
mensagem/bloco de mídia, com data de inclusão ao lado. Cada mensagem ou
arquivo pode receber uma **tag** (etiqueta colorida) por meio de um gesto de
arrastar, usada para agrupar e localizar conteúdo depois. O aplicativo
organiza o conteúdo em **Conversas** (equivalente à antiga Página), permite
o CRUD completo de cada componente do sistema (Conversa, Mensagem, Tag) e
funciona inteiramente offline.

A partir da v5.2, o app também permite: **selecionar várias mensagens** na
própria conversa (ou na tela de resultados de busca) e agir em lote (copiar,
excluir, definir tag, editar data, encaminhar, compartilhar); **importar
múltiplos arquivos de uma vez** (galeria com fotos+vídeos, documentos,
áudio); **encaminhar** mensagens para outra Conversa (com opção de manter
data original e/ou levar a tag, e com aviso de rebaixamento de segurança se
a origem for protegida e o destino não); **compartilhar para outros apps**
via share sheet do Android; e **receber compartilhamento** de outros apps,
escolhendo a Conversa de destino.

---

## Requisitos funcionais

### RF01 — CRUD de Conversa
O usuário pode criar, listar, renomear e excluir uma **Conversa** — um
espaço de conteúdo estruturado como uma sequência de **Mensagens** (texto
ou arquivo), exibidas como uma linha do tempo de balões, como em um app de
mensagens.

### RF02 — CRUD de Mensagem
Cada Mensagem pertence a exatamente uma Conversa e é de um dos tipos:
`texto`, `imagem`, `vídeo`, `áudio` ou `documento`.

**RF02.1 — Rascunho persistente** *(herdado da v4.0)*: o texto ainda em
composição no campo de digitação é salvo automaticamente, em um campo de
rascunho próprio da Conversa, para não se perder ao fechar o app ou sair da
tela antes do envio.

**RF02.2 — Envio de mensagem de texto:** ao confirmar o envio, o conteúdo do
rascunho vira **uma única Mensagem** do tipo `texto` (podendo conter várias
linhas internas), que recebe a data do momento do envio; o rascunho é
esvaziado. A data nunca é atribuída durante a digitação — apenas na
confirmação do envio.

**RF02.3 — Anexação de arquivo/mídia** *(alterado em 5.2)*: o usuário
seleciona um tipo de arquivo e o anexo é adicionado à conversa como uma nova
Mensagem, recebendo a data do momento da inclusão.

- **Anexos unitários**: câmera (tirar foto / gravar vídeo) e gravador de
  áudio geram **um** anexo por ação.
- **Anexos múltiplos**: o seletor de **galeria** (fotos e vídeos juntos), o
  seletor de **áudio do dispositivo** e o seletor de **documentos** aceitam
  **vários arquivos de uma vez**. Cada arquivo vira uma Mensagem própria
  (ver RF10).
- São armazenados metadados do arquivo: nome original, nome de exibição
  (editável), tipo/MIME, tamanho e caminho local do arquivo físico.

**RF02.4 — Edição de mensagem:** o conteúdo textual de uma Mensagem de texto
já enviada pode ser reescrito **sem alterar sua data original**. Para
Mensagens de arquivo, é possível editar o nome de exibição sem alterar a
data; a substituição do próprio arquivo (nova versão do anexo) também não
altera a data — apenas exclusão seguida de novo envio gera uma data nova
(mesma regra de imutabilidade de data da v4.0, generalizada de Linha para
Mensagem).

**RF02.5 — Exclusão de mensagem:** remove o registro da Mensagem e, quando
aplicável, o arquivo físico correspondente do armazenamento local.

**RF02.6 — Edição manual de data** *(herdado da v4.0)*: o usuário pode
sobrescrever manualmente a data de qualquer Mensagem, a qualquer momento,
independente do fluxo automático.

### RF03 — Datação automática por Mensagem
Cada Mensagem recebe uma **data de criação automática** (apenas o dia, sem
horário), atribuída no momento em que é enviada/anexada. Regras:
- Editar o conteúdo (texto ou metadado de arquivo) de uma Mensagem já
  enviada não altera sua data.
- A data só muda quando a Mensagem é excluída e uma nova é enviada em seu
  lugar, ou quando a data é sobrescrita manualmente (RF02.6) ou, no
  encaminhamento, quando o usuário opta por **não** manter a data original
  (RF11).
- Cada Mensagem é uma entidade própria com `id` estável desde o envio.

### RF04 — Sistema de Tags (etiquetas)
Ao arrastar uma Mensagem (texto ou arquivo) para o lado, o usuário aciona a
ação de **definir a tag** dessa mensagem.

- Uma **Tag** é composta por uma cor e um texto/rótulo curto, exibida como
  uma seta colorida junto à mensagem marcada.
- Serve exclusivamente para **identificação e busca** — não altera o
  conteúdo da mensagem.
- **Cada Mensagem possui no máximo uma Tag por vez.** Arrastar novamente uma
  mensagem que já tem tag **substitui** a tag anterior pela nova selecionada
  (ou remove a tag, caso o usuário escolha "sem tag").
- CRUD completo de Tag: criar, renomear, alterar cor e excluir (excluir uma
  Tag remove a tag das mensagens que a usavam, mas não as mensagens em si).
- **Escopo por Conversa:** cada Tag pertence a **uma Conversa** e só é
  visível e selecionável para as Mensagens dessa Conversa. O nome é único
  dentro da Conversa (normalizado em maiúsculas); o mesmo nome pode existir
  em Conversas diferentes como Tags independentes. Excluir uma Conversa
  exclui suas Tags.
- **Aplicação em lote (v5.2)**: o usuário pode definir (ou remover) a tag de
  várias Mensagens selecionadas de uma vez, via RF09.

### RF05 — Busca e filtragem dentro da Conversa
Dentro de uma Conversa aberta, o usuário pode localizar Mensagens por:
- **Texto**: palavra ou frase no conteúdo da mensagem de texto, ou no nome
  do arquivo (original ou de exibição).
- **Data**: data exata ou intervalo de datas.
- **Tipo de arquivo**: texto, imagem, vídeo, áudio ou documento.
- **Tag**: mensagens associadas à etiqueta selecionada.

Os filtros são combináveis (ex.: "arquivos do tipo imagem, com a tag
'Recibos', entre duas datas"). **Este é o único nível em que a busca por
conteúdo (texto/data/tipo/tag) existe** — não há busca de conteúdo que
atravesse várias Conversas.

Na tela de resultados (4.5/4.6), o usuário pode **selecionar múltiplas
mensagens** e agir em lote (definir tag, editar data, excluir) — já
existente desde a Sprint 4. A v5.2 acrescenta a **mesma capacidade em lote
dentro da `ChatScreen`** (ver RF09).

### RF06 — Tela inicial e busca de Conversa
Ao abrir o aplicativo, a primeira tela exibe a lista de todas as Conversas
existentes, cada uma identificada por título.

**RF06.1 — Busca por nome da Conversa:** nesta tela, o usuário pode buscar
Conversas pelo título. Essa é a **única forma de busca que atravessa
Conversas** — ela filtra apenas quais Conversas aparecem na lista, e não dá
acesso a conteúdo (mensagens/arquivos) de dentro delas sem antes abri-las.

### RF07 — Armazenamento interno
O conteúdo é armazenado em um **banco de dados local próprio** (metadados de
Conversa, Mensagem, Tag, associações e rascunho), enquanto os **arquivos
binários** (fotos, vídeos, áudios, documentos) ficam no sistema de arquivos
do dispositivo, referenciados por caminho/URI no banco — evitando duplicar
bytes de mídia dentro do banco de dados.

Temporários de compartilhamento (saída) ficam em `share_tmp/` (subpasta do
diretório de documentos) e são **apagados ao fim de cada fluxo** e **varridos
na abertura do app** (invariante 19).

### RF08 — Criptografia de acesso à Conversa *(herdado da v4.0; alterado em 5.2)*
O usuário pode ativar uma senha para uma Conversa. A criptografia protege
**apenas o acesso a essa Conversa como um todo** — funciona como uma tela
de bloqueio/desbloqueio: sem a senha correta, nem as Mensagens de texto nem
os arquivos anexados daquela Conversa ficam visíveis ou acessíveis, na
lista de Conversas ou dentro dela. Não há distinção de cifragem por tipo de
conteúdo (texto vs. mídia) — a senha é um portão único para a Conversa
inteira, e não um mecanismo de cifragem seletiva por Mensagem.

**Novo em 5.2 — Exportação de conteúdo protegido:** encaminhar mensagens de
uma Conversa protegida para uma Conversa **não protegida**, ou compartilhar
mensagens de uma Conversa protegida para **outro aplicativo** (RF11),
expõe os textos e nomes de arquivo em claro fora do controle de cifra do
Arquivo. O app **avisa explicitamente o usuário** antes de prosseguir
(rebaixamento de segurança). As mídias continuam em claro no filesystem
(D7); o aviso cobre o rebaixamento de metadados que estavam cifrados.
**Novo em 5.3 — Biometria:** além da senha, a Conversa pode ser liberada
pela biometria do aparelho. Ativar a biometria exige a senha na sessão
(prova de posse) e grava a chave derivada em armazenamento seguro do
sistema, protegido pelo Keystore. A biometria **não substitui** a senha:
é uma porta **adicional**. Abrir a Conversa protegida com biometria ativa
dispara o sensor nativo **automaticamente** (sem tela intermediária de
escolha); o usuário pode optar por "Usar senha" a qualquer momento.
Desativar a biometria só remove o cofre paralelo; não toca em
`senhaHash`/`salt`/`protegidoPorSenha`. Remover a senha remove **também**
o enrolamento biométrico (a chave perde sentido).

### RF09 (novo em 5.2) — Seleção de mensagens
O usuário pode entrar em **modo de seleção** dentro de uma Conversa:

- **Entrada pelo gesto**: pressionar e segurar uma mensagem (long-press
  **sem arrastar**) entra em seleção com aquela mensagem marcada. Se o
  usuário **arrastar** durante o long-press (>12 px), a ação continua sendo
  **reordenar** (não é seleção) — os dois gestos convivem.
- **Em seleção**: toque numa mensagem alterna a marcação; desmarcar a
  última mensagem selecionada sai do modo.
- **Ações disponíveis** ficam no **botão `⋮` do AppBar da Conversa**, que
  muda de ícone (`more_vert` → `checklist`, com pulso visual) e de menu
  durante a seleção:
  - **Copiar** — copia o **texto** das mensagens de texto selecionadas para
    a área de transferência, em ordem de `position`, separadas por linha em
    branco. Mídia é ignorada com aviso.
  - **Compartilhar** — RF11.
  - **Encaminhar** — RF11.
  - **Definir tag** — aplica em lote via `TagRepository` (RF04).
  - **Editar data** — aplica em lote via `setMessageDateMany`.
  - **Excluir** — exclui em lote via `deleteMessagesMany`.
  - Com **exatamente 1** mensagem selecionada: **Editar texto** (se tipo
    texto), **Renomear arquivo**, **Substituir arquivo** (se anexo).
  - **Selecionar até aqui** — marca o intervalo entre a mensagem "âncora"
    (a primeira que entrou em seleção) e a última marcada na janela visível.
    Se a âncora não está na janela carregada, o app avisa e sugere "Selecionar
    tudo".
  - **Selecionar tudo** — marca **todas** as mensagens reais da Conversa,
    inclusive fora da janela paginada.
- **Em seleção**, gestos conflitantes são desativados: swipe (tag/detalhes),
  reordenar, tap em mídia (não abre) e tap em texto (não edita).
- **Sair da seleção**: botão voltar do Android, ação de conteúdo (copiar,
  compartilhar, encaminhar, tag, data, excluir), ou desmarcar tudo. A
  seleção **também é descartada automaticamente** quando a Conversa é
  bloqueada (re-bloqueio em background — invariante 17).

### RF10 (novo em 5.2) — Importação em lote
A importação de múltiplos arquivos (RF02.3) gera **uma Mensagem por
arquivo**, todas com a data do momento da inclusão, na **ordem de seleção**
do picker.

- A importação processa em **lotes de 10 arquivos**, com **progresso
  visível** ("N de M") e **botão Cancelar**.
- Cancelar interrompe no próximo lote: os lotes já enviados **permanecem**;
  o restante é descartado com aviso.
- Falha em um lote: os lotes anteriores **permanecem**; o lote com falha
  não entra (atomicidade interna do `appendMessages`); o restante não é
  tentado, com aviso.

### RF11 (novo em 5.2) — Encaminhar e compartilhar
**11a — Encaminhar para outra Conversa do próprio app:**
- O usuário escolhe o destino numa tela de seleção com busca por título
  (mesmo padrão da Home); a Conversa de origem aparece desabilitada; pode
  criar uma Conversa nova na hora.
- Se o destino for protegido e ainda não desbloqueado, o app pede a senha
  antes de prosseguir.
- Opções por encaminhamento:
  - **Manter data original** (desligado por padrão → data de hoje).
  - **Levar tag** (desligado por padrão; recria a tag no destino por nome
    normalizado + cor).
- Cada mensagem encaminhada recebe **novo `id`** e **novo arquivo físico**
  no destino — excluir a Conversa de origem depois **não afeta** as cópias
  encaminhadas (invariante 15).
- Mensagens cujo arquivo físico esteja ausente são **puladas** e contadas
  separadamente ("N ignoradas: arquivo indisponível"). O restante é
  encaminhado.
- Ao final, o app mostra um resumo e oferece **"Abrir"** para a Conversa de
  destino.

**11b — Compartilhar para outros aplicativos:**
- O usuário compartilha as mensagens selecionadas via **share sheet do
  Android** (WhatsApp, Telegram, Instagram etc.). Os arquivos vão com o
  **nome de exibição** (não o `<uuid>.ext` do disco). Os textos das
  mensagens de texto são concatenados em ordem de `position` e enviados no
  parâmetro de texto do share sheet.
- Aviso de rebaixamento de segurança quando a origem é protegida (ver
  RF08).
- Nada fica para trás: os temporários de saída são apagados no fim do fluxo
  e varridos na abertura do app (invariante 19).
- Nenhuma conexão de rede é aberta pelo app: o share é uma comunicação
  entre apps no mesmo aparelho, via `Intent` do Android.

### RF12 (novo em 5.2) — Receber compartilhamento
O Arquivo aparece na **share sheet do Android** de outros apps
(`ACTION_SEND` e `ACTION_SEND_MULTIPLE`, cobrindo texto, imagem, vídeo,
áudio, documentos e `*/*`).

- Ao receber um payload:
  - Texto (se houver) vira uma **mensagem de texto primeiro**; os arquivos
    viram anexos **depois** (ordem de seleção do app de origem).
  - O app pede a **Conversa de destino** (mesmo picker do RF11a, com busca
    e "Nova conversa"). Se o destino for protegido e não desbloqueado, pede
    a senha.
  - As mensagens entram pela mesma primitiva de inserção em lote
    (`appendMessages`), com progresso e cancelamento análogos ao RF10.
  - Ao final, o app **abre a Conversa de destino**.
- **Cancelar** o picker descarta o payload e limpa o cache do plugin.
- **App em segundo plano** com o picker aberto: o payload é **descartado**
  (não se mantém conteúdo de terceiros em memória indefinidamente).
- **Morte do processo** com payload pendente: aceita-se a perda; o usuário
  refaz o compartilhamento.
- Nenhuma permissão nova de runtime é exigida. O app de release **não**
  declara `INTERNET` (RNF01).

---

## Requisitos não funcionais

### RNF01 — Offline-first *(alterado em 5.2)*
O aplicativo funciona totalmente e prioritariamente offline, sem depender de
conexão com internet para nenhuma funcionalidade essencial, incluindo
captura/seleção de mídia e leitura de arquivos já anexados.

**Novo em 5.2 — compartilhamento:** a recepção e o envio de
compartilhamento entre apps no mesmo aparelho ocorrem via `Intent` do
Android; o Arquivo **nunca abre conexão**. O **manifest de release** não
declara `INTERNET` (o template Flutter inclui `INTERNET` em debug/profile
para hot reload — aceitável, mas o release não). Verificar com
`aapt dump permissions` no APK de release.

### RNF02 — Simplicidade e performance de interface
Interface no padrão de um app de mensagens (lista de balões + campo de
composição fixo com atalho para anexar arquivo).

**Novo em 5.2:** o menu `⋮` do AppBar **muda de ícone e de menu durante a
seleção** (de `more_vert` para `checklist`, com uma breve animação de pulso)
para sinalizar a sobrecarga de função, sem adicionar um botão extra por
balão.

### RNF03 — Performance com mídia
Atenção especial ao volume e peso de arquivos de mídia:
- Carregamento assíncrono e lazy de miniaturas (thumbnails) de imagem/vídeo.
- Scroll da conversa não deve travar durante carregamento de mídia nem
  durante digitação no campo de composição.
- Arquivos grandes nunca trafegam pelo banco de dados relacional — apenas
  seus metadados e caminho local.

**Novo em 5.2:** operações em lote sobre ids (busca por id,
tag/data/exclusão em lote) consultam o banco em **blocos de 500**, para
respeitar o limite de variáveis do SQLite (invariante 20). A seleção
guarda **ids** (não objetos), e o `ChatScreen` usa **um único** stream de
janela (Sprint 6), então seleções grandes independem da janela carregada.

---

## Modelo de dados

```
Conversa (antiga Página)
- id
- titulo
- criado_em
- atualizado_em
- protegido_por_senha (bool)
- senha_hash / salt
- rascunho (texto ainda não enviado, sem data associada)

Mensagem (antiga Linha, generalizada)
- id
- conversa_id
- tag_id (nullable — no máximo uma Tag por Mensagem)
- position (posição de envio dentro da conversa; ESPARSA — gaps de 1000)
- tipo (enum: texto | imagem | video | audio | documento)
- conteudo_texto (nullable — usado quando tipo = texto)
- arquivo_path (nullable — caminho local RELATIVO do arquivo físico)
- arquivo_nome_original (nullable)
- arquivo_nome_exibicao (nullable, editável)
- arquivo_mime_type (nullable)
- arquivo_tamanho_bytes (nullable)
- data (apenas dia, sem hora — atribuída no momento do envio)
- data_editada_manualmente (bool)

Tag
- id
- conversa_id (FK — a Tag pertence a uma Conversa)
- nome
- cor (hex)
```

`Mensagem.tag_id` é uma FK simples (1:N — uma Tag pode estar em várias
Mensagens, mas cada Mensagem aponta para no máximo uma Tag), o que dispensa
tabela associativa.

O conteúdo de uma Conversa é reconstruído ordenando as Mensagens por
`position`. Cada Mensagem é criada, editada ou excluída por operação direta
sobre seu `id`. O rascunho continua persistido separadamente, sem afetar as
Mensagens já enviadas.

**Nenhuma alteração de schema em 5.2.** O schema drift continua **v4**. As
novas operações (inserção em lote, encaminhamento, importação, recepção de
compartilhamento) usam as tabelas existentes.

### Invariantes (v5.2)

Os invariantes 1–14 da v5.1 continuam válidos. A v5.2 acrescenta os
seguintes (numeração contínua):

15. Encaminhar gera **novo `id`** e **novo arquivo físico** por mensagem;
    nenhum arquivo é referenciado por mais de uma Mensagem.
16. Ações em lote seguem a ordem de `position`, nunca a ordem de seleção
    (exceção: importação em lote, que segue a ordem de seleção do picker).
17. A seleção é descartada quando a Conversa bloqueia.
18. `appendMessages` é atômico por chamada: ou todas as mensagens entram, ou
    nenhuma e nenhum arquivo órfão fica em disco.
19. Nenhum temporário de compartilhamento (saída ou entrada) sobrevive ao
    fluxo: apagado no `finally` e varrido na abertura do app.
20. Operações `*Many` com `IN (...)` processam em **blocos de 500** (limite
    de variáveis do SQLite).
21. O `AppLockShield` (escudo de auto-bloqueio, novo em 5.2) **não
    substitui** o re-bloqueio em background; apenas o **adia** enquanto há
    ação legítima em andamento. Se o app ficar em `paused` com o escudo
    armado além da **janela de graça (2 min)**, o escudo dispara o bloqueio.
22. Pickers de mídia, câmera, gravador e share sheet rodam **dentro do
    escudo**; consumidores do escudo (`LockOnBackground`, `ChatScreen`)
    consultam **`isProtecting`** (não `armed`) antes de bloquear —
    `isProtecting` cobre a corrida "Future retorna antes do `paused`".
23. Toda mensagem (de texto ou anexo) criada por `appendMessages` (seja por
    importação em lote, encaminhamento ou recepção de compartilhamento)
    passa pelo **mesmo caminho de cifragem** de uma mensagem enviada
    individualmente: em Conversa protegida, os metadados cifráveis são
    cifrados via `_encodeForStorage`; bytes de mídia continuam em claro
    (D7).
24. O **`⋮` do AppBar** é o ponto único de ações em lote na Conversa: em
    seleção, ele sobrepõe o menu normal (Pesquisar/Gerenciar tags). Fora da
    seleção, o menu normal é restaurado.
25. Receber compartilhamento de outro app **não** cria registro
    intermediário: o payload (texto + arquivos) é materializado direto em
    Mensagens do destino. Se o usuário cancelar, nada é gravado.
26. Encaminhar e receber compartilhamento **não abrem conexão de rede**.
    Todos os bytes (entrada e saída) circulam apenas no filesystem local.
27. O **manifest de release** não declara `INTERNET`. Compartilhar com
    outros apps é comunicação entre apps do aparelho via `Intent`.
28. Excluir uma Conversa **não afeta** mensagens encaminhadas para outras
    Conversas (cópia física independente, invariante 15).

    29. Ativar biometria exige a chave na sessão (`unlockedKeyOrNull`);
    nunca guarda a chave sem que o usuário tenha provado a senha nesta
    execução.
30. Senha e biometria são portas **independentes**; remover uma não
    invalida a outra. `unprotectConversation` remove **também** o
    enrolamento biométrico (a chave perde sentido).
31. Desativar biometria = `BiometricUnlock.disable` (só apaga o cofre
    paralelo); não toca em `senhaHash`/`salt`/`protegidoPorSenha` nem
    recifra nada.

---

## Metodologia de desenvolvimento

| Sprint | Entrega |
|---|---|
| 0 — Fundação | Migração de schema (Linha → Mensagem), tela inicial de Conversas, CRUD de Conversa |
| 1 — Chat de texto | Editor estilo mensageria, rascunho persistente, envio de mensagem de texto como unidade única, datação automática, edição de conteúdo sem alterar data, edição manual de data |
| 2 — Anexos de mídia | Seleção/captura de imagem, vídeo, áudio e documento; armazenamento de arquivo no filesystem + metadados no banco; renderização de miniaturas |
| 3 — Tags | Gesto de arrastar (swipe) para definir/substituir a tag da mensagem; CRUD de Tag; exibição da seta colorida na mensagem |
| 4 — Busca e filtros | Busca de Conversa por nome (tela inicial); busca por texto, data, tipo de arquivo e tag dentro da Conversa, combináveis |
| 5 — Criptografia | Senha de acesso por Conversa (bloqueio/desbloqueio da Conversa inteira) |
| 6 — Polimento | Performance com mídia pesada, robustez offline, paginação, `position` esparsa, cache de plaintext, re-bloqueio em background (Z1) |
| 7 — Seleção, múltiplas mídias e compartilhamento | Seleção de mensagens na Conversa com ações em lote; importação de múltiplas mídias; encaminhar; compartilhar para outros apps; receber compartilhamento; `AppLockShield` |
| 8 — Biometria | Segunda porta de desbloqueio: biometria do aparelho
  como alternativa à senha, com `runUnlockFlow` unificando os fluxos
  (biometria primeiro quando há enrolamento); migração de
  `showUnlockDialog` → `showPasswordUnlockDialog` + `PasswordUnlockResult`
  (sealed); bugfix do `switch` no menu ⋮ da Home que disparava
  `onChangePassword` + `onBiometric` juntos. |

---

## Stack técnica sugerida

- **State management:** Riverpod *(mantido)*
- **Banco de dados local:** SQLite via `drift` *(mantido)*
- **Armazenamento de arquivos:** sistema de arquivos local via
  `path_provider`, referenciado por caminho no banco; temporários de
  compartilhamento em `share_tmp/` (novo em 5.2)
- **Seleção/captura de mídia:** `image_picker` (foto/vídeo/câmera; múltipla
  seleção na galeria a partir de 5.2), `file_picker` (documentos e áudio,
  múltiplos a partir de 5.2), `record`/similar (áudio)
- **Gesto de arrastar para tag:** `flutter_slidable` (ou `Dismissible`
  customizado) sobre cada balão de mensagem *(mantido)*
- **Gesto de reordenar:** long-press + arrasto (implementação própria, O(1)
  com `position` esparsa — Sprint 6)
- **Seleção múltipla + ações em lote:** `⋮` do AppBar com sobrecarga
  (novo em 5.2); barra de seleção do `SearchResultsScreen` continua
  funcionando
- **Compartilhar para fora:** `share_plus` (novo em 5.2)
- **Receber compartilhamento:** `receive_sharing_intent` (Android; novo em
  5.2) — fixado em 1.8.0; 1.9+ exige SDK 37 e Kotlin DSL (ver seção de
  compatibilidade de build abaixo)
- **Escudo de auto-bloqueio:** `AppLockShield` (novo em 5.2) — timer de
  graça de 2 min, `WidgetsBindingObserver`
- **Criptografia:** `cryptography`/`encrypt` (AES-256-GCM) + derivação de
  chave via PBKDF2 (155k iterações, em isolate) + salt via
  `flutter_secure_storage` *(mantido)*
- **Diff de texto** *(herdado, sem uso no fluxo principal)*: o utilitário
  `line_diff_engine.dart` continua sem papel na datação; candidato a
  remoção.
- **Criptografia:** `cryptography`/`encrypt` (AES-256-GCM) + derivação de
  chave via PBKDF2 (155k iterações, em isolate) + salt via
  `flutter_secure_storage` *(mantido)*
- **Biometria (novo em 5.3):** `local_auth` (autenticação nativa) +
  `flutter_secure_storage` (guarda a chave derivada, cifrada pelo
  Keystore do sistema). Ativação exige a senha na sessão; senha e
  biometria são portas independentes.
---

## Estrutura de diretórios

```text
lib/
├── main.dart
├── app.dart                      # MaterialApp, theme, routes;
│                                 # home: LockOnBackground >
│                                 #   LostCaptureGate > ShareReceiverGate >
│                                 #   HomeScreen
│
├── database/
│   ├── app_database.dart         # drift instance, migrations,
│   │                             # AppDatabase.forTesting (novo em 5.2)
│   └── tables.dart               # Conversations, Messages (com tag_id), Tags
│
├── models/
│   ├── conversation.dart
│   ├── message.dart
│   └── tag.dart
│
├── repositories/
│   ├── conversation_repository.dart   # Conversa + Mensagem + appendMessages +
│   │                                  # forwardMessages + getMessagesByIds +
│   │                                  # getMessageIds + *Many com blocagem
│   ├── new_message.dart               # novo em 5.2 — formato de entrada do
│   │                                  # appendMessages
│   └── tag_repository.dart
│
├── storage/
│   └── media_storage.dart        # salvar/ler/excluir arquivos no filesystem
│
├── security/
│   ├── password_crypto.dart      # AES-256-GCM, PBKDF2
│   └── app_lock_shield.dart      # novo em 5.2
│
├── services/
│   ├── attachment_service.dart   # pickers (unitários e múltiplos)
│   ├── share_service.dart        # novo em 5.2 — share sheet + share_tmp
│   └── share_receiver.dart       # novo em 5.2 — recepção de SEND
│
├── search/
│   ├── message_filter.dart
│   └── message_search.dart
│
├── providers/
│   ├── conversation_providers.dart
│   ├── security_providers.dart   # novo em 5.2 — appLockShieldProvider
│   └── tag_providers.dart
│
├── diff/
│   └── line_diff_engine.dart     # utilitário legado (uso futuro, se houver)
│
├── screens/
│   ├── home_screen.dart          # lista de Conversas
│   ├── chat_screen.dart          # conversa (antiga editor_screen)
│   ├── tags_screen.dart
│   ├── search_results_screen.dart
│   └── destination_picker_screen.dart  # novo em 5.2 — escolha de destino
│
├── widgets/
│   ├── message_bubble.dart       # balão (com selectionMode a partir de 5.2)
│   ├── message_details_sheet.dart
│   ├── tag_chip.dart
│   ├── tag_ribbon.dart
│   ├── tag_picker_sheet.dart
│   ├── tag_picker_many_sheet.dart
│   ├── tag_editor_dialog.dart
│   ├── attachment_picker_sheet.dart
│   ├── audio_recorder_dialog.dart
│   ├── search_options_sheet.dart
│   ├── highlighted_text.dart
│   ├── unlock_dialog.dart
│   ├── password_setup_dialog.dart
│   ├── password_change_dialog.dart
│   ├── lock_on_background.dart   # Z1 (Sprint 6), consulta AppLockShield
│   ├── lost_capture_gate.dart    # recuperação de captura; + cleanupOrphans
│   └── share_receiver_gate.dart  # novo em 5.2 — recebe SEND
│
└── theme/
    └── app_theme.dart            # (a spec cita; diretório real não tem —
                                  #  ver pendências do mapa.txt)
```

---

## Compatibilidade de build (Android)

O `receive_sharing_intent` (v1.8.0) declara JVM target 1.8 no próprio
`build.gradle`, conflitando com o Kotlin 17/21 do projeto. Foi necessário:

- `android/build.gradle.kts` (raiz): forçar `JVM_1_8` **só** para
  `receive_sharing_intent` e `JVM_17` para o resto, via
  `tasks.withType<KotlinCompile>().configureEach { compilerOptions { ... } }`.
- `android/gradle.properties`:
  `kotlin.jvm.target.validation.mode=warning` (rede de segurança).
- `AndroidManifest.xml`: `android:launchMode="singleTask"` (o plugin espera
  instância única para entregar o intent novo quando o app está aberto/em
  segundo plano) e `intent-filter` para `ACTION_SEND`/`ACTION_SEND_MULTIPLE`.
- `share_receiver.dart`: `ReceiveSharingIntent.instance.reset()` após
  `getInitialPayload()` (evita reentregar o mesmo payload na próxima
  abertura).

Detalhes em `BUILD_ANDROID_CHANGES.md`. Essas decisões são de build e
**não** fazem parte do escopo funcional da spec; ficam registradas aqui só
para rastreabilidade.

---

## Pendências e limitações conhecidas (v5.2)

- Sem "esqueci a senha" (offline) e sem reset mágico.
- Mídias em **claro** no filesystem (D7) — agravado ao compartilhar para
  fora.
- Título da Conversa em claro (necessário para RF06.1).
- Compartilhamento para fora: comportamento de texto/legenda e limites de
  mídia variam por app de destino.
- Recebimento: o Arquivo aparece na share sheet do próprio Arquivo (excluir
  exigiria `EXTRA_EXCLUDE_COMPONENTS`, API 24+ — fora do escopo).
- **Morte do processo** com payload de recepção pendente: aceita-se a
  perda; o usuário refaz o compartilhamento. Temporários de saída são
  varridos na abertura.
- **Checagem de espaço livre** antes de importar/encaminhar: prevista no
  plano, não implementada (exige dependência nova ou `MethodChannel`).
- **Copiar mídia** para a área de transferência: fora do escopo (copiar é
  só texto — S7-6).
- **"Mover"** (encaminhar + excluir origem) e **Sharing Shortcuts**:
  evoluções futuras.
- **iOS** (Share Extension): fora do escopo.
- **Exceção por nome** no `build.gradle.kts` (`receive_sharing_intent` →
  JVM 1.8): manutenção ativa — se o plugin migrar para Java 17, remover a
  exceção.
  - **Troca de senha × biometria (v5.3):** trocar a senha re-cifra os
  metadados com a chave nova; o enrolamento biométrico continua com a
  chave antiga e fica **inválido** até o usuário reconfigurar. Efeito
  esperado: próxima abertura com biometria cai em senha. Correção
  planejada para a v5.3.1 (re-enrolar automaticamente após a troca).
- **`destination_picker_screen` (v5.3):** o sensor biométrico abre
  **sobre** o picker de destino. Funcional; ajuste de UX fica para a
  v5.3.1 se incomodar.
- **`UnlockOutcome.wrongPassword` (v5.3):** valor reservado; o fluxo
  nunca o retorna. Candidato a remoção na v5.3.1.