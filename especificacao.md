# Especificação da Aplicação — Arquivo

**Versão:** 5.1
**Plataforma:** Mobile (Flutter)

> **Nota de versão (4.0 → 5.0):** o escopo do produto muda de um **bloco de
> notas** para um **arquivador de conteúdo em formato de conversa**. A
> entidade **Linha** (texto puro) é generalizada para **Mensagem**, que
> passa a poder conter **texto ou um arquivo/mídia anexado** (foto, vídeo,
> áudio, documento). A entidade **Página** é mantida na estrutura de dados,
> mas passa a representar uma **Conversa** — um "chat consigo mesmo", nos
> moldes de um aplicativo de mensageria como o WhatsApp, porém local e
> persistente. É introduzido o conceito de **Tag**: uma etiqueta colorida
> aplicada a uma Mensagem por gesto de arrastar (swipe), usada
> exclusivamente para identificação e busca. Busca e filtros são ampliados
> para cobrir data, nome e tipo de arquivo.
>
> **Nota de versão (5.0 → 5.1) — decisões confirmadas:** (1) cada Mensagem
> possui **no máximo uma Tag** (não múltiplas); (2) a criptografia protege
> apenas o **acesso à Conversa** (tela de bloqueio/desbloqueio), sem
> distinção de cifragem por tipo de conteúdo; (3) a busca é **restrita ao
> interior de uma Conversa** — a única busca que atravessa Conversas é por
> **nome/título da Conversa**, na tela inicial; (4) todo o conteúdo herdado
> da v4.0 (datação imutável, rascunho persistente, armazenamento local,
> offline-first) é **confirmado como requisito definitivo**, não mais como
> item sujeito a revisão. As seções abaixo já refletem essas decisões; os
> pontos que antes estavam "em aberto" foram removidos do fim do documento.
>
> **O que é herdado da v4.0 (confirmado como definitivo):** datação
> automática imutável por edição de conteúdo, possibilidade de sobrescrita
> manual de data, rascunho persistente em tempo de composição, armazenamento
> local próprio, funcionamento 100% offline e criptografia por Conversa.
>
> **O que muda de comportamento em relação à v4.0:** no bloco de notas, uma
> quebra de linha no rascunho virava uma Linha nova por quebra
> (comportamento de editor de texto). No Arquivo, cada ação de envio gera
> **uma única Mensagem** (que pode conter múltiplas linhas internas de
> texto), alinhado ao comportamento real de um app de chat — o usuário
> "envia uma mensagem", não "publica um parágrafo por linha".

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

**RF02.3 — Anexação de arquivo/mídia:** o usuário seleciona um tipo de
arquivo (câmera/galeria para foto e vídeo, gravador para áudio, ou seletor
de arquivos para documentos genéricos) e o anexo é adicionado à conversa
como uma nova Mensagem, recebendo a data do momento da inclusão. São
armazenados metadados do arquivo: nome original, nome de exibição
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
  lugar.
- O usuário pode sobrescrever manualmente a data de qualquer Mensagem.
- Cada Mensagem é uma entidade própria com `id` estável desde o envio; a
  identificação de "mesma Mensagem entre uma edição e outra" é uma operação
  direta sobre esse `id`.

### RF04 — Sistema de Tags (etiquetas)
Ao arrastar uma Mensagem (texto ou arquivo) para o lado, o usuário aciona a
ação de **definir a tag** dessa mensagem.

- Uma **Tag** é composta por uma cor e um texto/rótulo curto, exibida como
  uma seta colorida junto à mensagem marcada.
- Serve exclusivamente para **identificação e busca** — não altera o
  conteúdo da mensagem.
- **Cada Mensagem possui no máximo uma Tag por vez.** O usuário pode criar
  uma nova tag (nome + cor) ou selecionar uma já existente; arrastar
  novamente uma mensagem que já tem tag **substitui** a tag anterior pela
  nova selecionada (ou remove a tag, caso o usuário escolha "sem tag").
- CRUD completo de Tag: criar, renomear, alterar cor e excluir (excluir uma
  Tag remove a tag das mensagens que a usavam, mas não as mensagens em si).

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

### RF08 — Criptografia de acesso à Conversa *(herdado da v4.0, escopo
confirmado)*
O usuário pode ativar uma senha para uma Conversa. A criptografia protege
**apenas o acesso a essa Conversa como um todo** — funciona como uma tela
de bloqueio/desbloqueio: sem a senha correta, nem as Mensagens de texto nem
os arquivos anexados daquela Conversa ficam visíveis ou acessíveis, na
lista de Conversas ou dentro dela. Não há distinção de cifragem por tipo de
conteúdo (texto vs. mídia) — a senha é um portão único para a Conversa
inteira, e não um mecanismo de cifragem seletiva por Mensagem.

---

## Requisitos não funcionais

### RNF01 — Offline-first
O aplicativo funciona totalmente e prioritariamente offline, sem depender de
conexão com internet para nenhuma funcionalidade essencial, incluindo
captura/seleção de mídia e leitura de arquivos já anexados.

### RNF02 — Simplicidade e performance de interface
Interface no padrão de um app de mensagens (lista de balões + campo de
composição fixo com atalho para anexar arquivo).

### RNF03 — Performance com mídia
Atenção especial ao volume e peso de arquivos de mídia:
- Carregamento assíncrono e lazy de miniaturas (thumbnails) de imagem/vídeo.
- Scroll da conversa não deve travar durante carregamento de mídia nem
  durante digitação no campo de composição.
- Arquivos grandes nunca trafegam pelo banco de dados relacional — apenas
  seus metadados e caminho local.

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
- position (posição de envio dentro da conversa)
- tipo (enum: texto | imagem | video | audio | documento)
- conteudo_texto (nullable — usado quando tipo = texto)
- arquivo_path (nullable — caminho local do arquivo físico)
- arquivo_nome_original (nullable)
- arquivo_nome_exibicao (nullable, editável)
- arquivo_mime_type (nullable)
- arquivo_tamanho_bytes (nullable)
- data (apenas dia, sem hora — atribuída no momento do envio)
- data_editada_manualmente (bool)

Tag
- id
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

---

## Metodologia de desenvolvimento

| Sprint | Entrega |
|---|---|
| 0 — Fundação | Migração de schema (Linha → Mensagem, remoção definitiva de resíduos de Bloco — ver seção de viabilidade), tela inicial de Conversas, CRUD de Conversa |
| 1 — Chat de texto | Editor estilo mensageria, rascunho persistente, envio de mensagem de texto como unidade única, datação automática, edição de conteúdo sem alterar data, edição manual de data |
| 2 — Anexos de mídia | Seleção/captura de imagem, vídeo, áudio e documento; armazenamento de arquivo no filesystem + metadados no banco; renderização de miniaturas |
| 3 — Tags | Gesto de arrastar (swipe) para definir/substituir a tag da mensagem; CRUD de Tag; exibição da seta colorida na mensagem |
| 4 — Busca e filtros | Busca de Conversa por nome (tela inicial); busca por texto, data, tipo de arquivo e tag dentro da Conversa, combináveis |
| 5 — Criptografia | Senha de acesso por Conversa (bloqueio/desbloqueio da Conversa inteira) |
| 6 — Polimento | Performance com mídia pesada, robustez offline, ajustes de UX |

---

## Stack técnica sugerida

- **State management:** Riverpod *(mantido)*
- **Banco de dados local:** SQLite via `drift` *(mantido)*
- **Armazenamento de arquivos:** sistema de arquivos local via `path_provider`,
  referenciado por caminho no banco
- **Seleção/captura de mídia:** `image_picker` (foto/vídeo/câmera),
  `file_picker` (documentos genéricos), `record`/similar (áudio)
- **Gesto de arrastar para tag:** `flutter_slidable` (ou `Dismissible`
  customizado) sobre cada balão de mensagem
- **Criptografia:** `cryptography`/`encrypt` (AES-256-GCM) + derivação de
  chave via PBKDF2/Argon2, com salt gerenciado via `flutter_secure_storage`
  *(mantido da v4.0)*
- **Diff de texto** *(herdado, sem uso no fluxo principal)*: o utilitário
  `line_diff_engine.dart` deixa de ter qualquer papel na datação (já não
  tinha na v4.0) e só se justifica se uma futura importação estruturada for
  reintroduzida — caso contrário, é candidato a remoção.
  
---

## Estrutura de diretórios

```text
lib/
├── main.dart
├── app.dart                      # MaterialApp, theme, routes
│
├── database/
│   ├── app_database.dart         # drift instance, migrations
│   └── tables.dart               # Conversations, Messages (com tag_id), Tags
│
├── models/
│   ├── conversation.dart
│   ├── message.dart
│   └── tag.dart
│
├── repositories/
│   ├── conversation_repository.dart   # cobre Conversa + Mensagem
│   └── tag_repository.dart
│
├── storage/
│   └── media_storage.dart        # salvar/ler/excluir arquivos no filesystem local
│
├── providers/
│   ├── conversation_providers.dart
│   └── tag_providers.dart
│
├── diff/
│   └── line_diff_engine.dart     # utilitário legado (uso futuro, se houver)
│
├── screens/
│   ├── home_screen.dart          # lista de Conversas
│   └── chat_screen.dart          # conversa (antiga editor_screen)
│
├── widgets/
│   ├── message_bubble.dart       # balão com suporte a swipe-to-tag
│   ├── tag_chip.dart
│   └── attachment_picker_sheet.dart
│
└── theme/
    └── app_theme.dart
```

---
