# Especificação da Aplicação — Bloco de Notas Seguro

**Versão:** 3.0
**Plataforma:** Mobile (Flutter)

> **Nota de versão (2.0 → 3.0):** esta versão não altera a nomenclatura das
> entidades (continuam **Bloco**, **Página** e **Linha**, consistente com o
> código já implementado). O que muda é o **modelo de interação** do editor:
> em vez de um campo de texto corrido único editado livremente, a Página
> passa a funcionar como um canal de mensagens — o usuário compõe e "envia"
> trechos de texto (Enter/botão de envio), que passam a existir como Linhas
> imutáveis em sua data, editáveis em conteúdo sem perder essa data.
>
> **Remoção temporária (import/export):** o requisito de importação e
> exportação em `.txt` (antigo RF08) foi **removido desta versão** e sai do
> escopo por ora. A abordagem para esse recurso será repensada do zero mais
> adiante, possivelmente com um formato ou fluxo diferente do originalmente
> proposto — não é uma remoção definitiva, apenas um adiamento consciente.

## Visão geral

Bloco de notas simples. Aplicação mobile de organização de texto de forma
segura, com foco em funcionamento offline, simplicidade e rastreamento
automático de quando cada trecho de texto foi escrito. Cada **Página**
funciona como um canal de mensagens de texto: o usuário envia entradas
(Linhas) que ficam registradas com data automática e podem ser editadas
posteriormente sem alterar essa data — de forma similar a um aplicativo de
mensageria, porém local e persistente.

---

## Requisitos funcionais

### RF01 — CRUD de Página
O usuário pode criar, ler, atualizar e excluir uma **Página** — um espaço de
conteúdo textual estruturado como uma sequência de **Linhas**, cada uma
exibida como um balão de texto com sua data ao lado.

**RF01.1 — Rascunho persistente:** o texto ainda em composição (não enviado)
é salvo automaticamente em tempo de digitação, em um campo de rascunho
próprio da Página. Isso garante que o usuário possa fechar o aplicativo, ou
sair da tela, sem perder o que estava escrevendo — mesmo sem ter confirmado
o envio (apertado "Enter"/botão de envio).

**RF01.2 — Envio:** ao confirmar o envio (Enter ou botão de enviar), o
conteúdo do rascunho é convertido em uma ou mais Linhas novas (uma por
quebra de linha presente no rascunho), cada uma recebendo a data do momento
do envio, e o rascunho é esvaziado.

### RF02 — Busca dentro da Página
O usuário pode pesquisar por uma palavra ou frase específica dentro do
conteúdo das Linhas de uma página.

### RF03 — Datação automática por Linha
Cada **Linha** de uma página recebe uma **data de criação automática**
(apenas o dia, sem horário), atribuída no momento em que ela é **enviada**.

Regras de comportamento:
- **Editar o conteúdo de uma Linha já enviada não altera sua data** — mesmo
  que a edição reescreva o texto inteiro daquela Linha.
- **A data só muda quando a Linha é excluída e uma nova Linha é enviada em
  seu lugar** — exclusão e criação são ações explícitas e distintas do
  usuário, não mais inferidas por comparação de texto.
- **O usuário pode sobrescrever manualmente a data de qualquer Linha**, a
  qualquer momento, independente do fluxo automático.
- **Mudança de mecanismo em relação à v2.0:** como cada Linha é uma entidade
  própria (com `id` estável desde o envio), a identificação de "mesma Linha
  entre uma edição e outra" deixa de depender de um algoritmo de
  diff/similaridade de texto — a edição é uma operação direta sobre o `id`
  daquela Linha. O algoritmo de diff linha a linha (LCS + similaridade
  textual) desenvolvido para a v2.0 permanece no projeto como utilitário de
  apoio, usado apenas em cenários de composição/colagem de texto
  multi-linha — não é mais o mecanismo central de datação.

### RF04 — CRUD de Bloco
O usuário pode criar, ler, atualizar e excluir um **Bloco** — uma pasta que
agrupa Páginas de uma mesma categoria.

### RF05 — Tela inicial
Ao abrir o aplicativo, a primeira tela exibe a lista de Páginas e Blocos
existentes, cada um identificado por um título.

### RF06 — Armazenamento interno
O conteúdo das Páginas é armazenado internamente em um **banco de dados
local próprio**, permitindo guardar metadado por Linha (data de criação,
flag de edição manual de data, etc.) e o rascunho em composição.

### RF07 — Criptografia
O usuário pode ativar criptografia para uma Página ou para um Bloco inteiro,
protegida por uma senha definida por ele. O conteúdo protegido (incluindo
Linhas e rascunho) fica cifrado no armazenamento local, sendo decifrado
apenas mediante senha correta.

> **RF08 — Importação e exportação: removido nesta versão.** Será
> redefinido futuramente com uma abordagem diferente da originalmente
> proposta (ver nota de versão no topo do documento).

---

## Requisitos não funcionais

### RNF01 — Offline-first
O aplicativo funciona totalmente e prioritariamente offline, sem depender de
conexão com internet para nenhuma funcionalidade essencial.

### RNF02 — Simplicidade e performance
Interface simples e intuitiva, no padrão de um app de mensagens (lista de
balões + campo de composição fixo). Atenção à performance de renderização em
páginas com grande volume de Linhas (carregamento/scroll assíncrono, sem
travar a digitação no campo de composição).

---

## Modelo de dados

```
Bloco
- id
- nome
- criado_em
- protegido_por_senha (bool)
- senha_hash / salt

Pagina
- id
- bloco_id (nullable — página pode existir fora de um bloco)
- titulo
- criado_em
- atualizado_em
- protegido_por_senha (bool)
- senha_hash / salt (própria ou herdada do bloco)
- rascunho (texto ainda não enviado, sem data associada)

Linha
- id
- pagina_id
- ordem (posição de envio dentro da página)
- texto
- data (apenas dia, sem hora — atribuída no momento do envio)
- data_editada_manualmente (bool)
```

O conteúdo de uma Página é reconstruído concatenando o texto das Linhas na
ordem de envio. Diferente da v2.0, **não há mais comparação de todo o texto
a cada salvamento**: cada Linha é criada, editada ou excluída por operação
direta sobre seu `id`. O rascunho é persistido separadamente, continuamente,
sem afetar as Linhas já enviadas.

**Nota sobre a limitação de linhas duplicadas (v2.0):** a limitação
conhecida de pareamento por proximidade posicional em conteúdo duplicado
deixa de se aplicar ao fluxo principal de digitação, já que cada Linha tem
identidade própria desde o envio. Ela permanece relevante apenas se o
utilitário de diff for reaproveitado futuramente em outros cenários (ex.:
colagem de texto multi-linha).

---

## Metodologia de desenvolvimento

Desenvolvimento incremental por sprints, priorizando funcionalidades que
podem ser implementadas e testadas de forma independente antes de somar
complexidade (como criptografia, que intercepta leitura/escrita em todo o
sistema).

| Sprint | Entrega |
|---|---|
| 0 — Fundação | Banco de dados local, modelo Bloco/Página/Linha, tela inicial, CRUD de Bloco e Página |
| 1 — Editor e datação | Editor estilo mensageria (composição + envio), rascunho persistente em tempo de digitação, datação automática no envio, edição de conteúdo sem alterar data, edição manual de data |
| 2 — Busca | Busca por palavra/frase dentro das Linhas de uma página |
| 3 — Import/Export | *Removido desta versão — será redefinido futuramente* |
| 4 — Criptografia | Senha por Página/Bloco, cifragem em repouso, fluxo de desbloqueio |
| 5 — Polimento | Performance, robustez offline, ajustes de UX |

---

## Stack técnica sugerida

- **State management:** Riverpod
- **Banco de dados local:** SQLite via `drift`
- **Diff de texto:** implementação própria baseada em LCS/Myers diff —
  mantida como utilitário de apoio para importação/colagem multi-linha, não
  mais crítica para o fluxo principal de digitação (ver RF03)
- **Criptografia:** `cryptography`/`encrypt` (AES-256-GCM) + derivação de
  chave via PBKDF2/Argon2, com salt gerenciado via `flutter_secure_storage`

---

## Estrutura de diretórios

```text
lib/
├── main.dart
├── app.dart                      # MaterialApp, theme, routes
│
├── database/
│   ├── app_database.dart         # drift instance, migrations
│   └── tables.dart               # Blocks, Pages, Lines tables
│
├── models/
│   ├── block.dart
│   ├── page.dart
│   └── line.dart
│
├── repositories/
│   ├── block_repository.dart
│   └── page_repository.dart      # cobre Page + Line (linha não existe sem página)
│
├── providers/
│   ├── block_providers.dart
│   └── page_providers.dart
│
├── diff/
│   └── line_diff_engine.dart     # utilitário de apoio (importação/colagem)
│
├── screens/
│   ├── home_screen.dart
│   ├── block_form_screen.dart
│   └── editor_screen.dart
│
├── widgets/                      # componentes reaproveitados entre telas
│   └── ...
│
└── theme/
    └── app_theme.dart
```