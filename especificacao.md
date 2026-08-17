# Especificação da Aplicação — Bloco de Notas Seguro

**Versão:** 2.0 (atualizada após discussão de arquitetura)
**Plataforma:** Mobile (Flutter)

## Visão geral

Bloco de notas simples. Aplicação mobile de organização de texto de forma segura, com foco em funcionamento offline, simplicidade e rastreamento automático de quando cada trecho de texto foi escrito.

---

## Requisitos funcionais

### RF01 — CRUD de Página
O usuário pode criar, ler, atualizar e excluir uma **Página** (unidade de texto livre, editada em um campo de texto contínuo, multilinha).

### RF02 — Busca dentro da Página
O usuário pode pesquisar por uma palavra ou frase específica dentro do conteúdo de uma página.

### RF03 — Datação automática por linha
Cada linha de texto de uma página recebe uma **data de criação automática** (apenas o dia, sem horário), atribuída no momento em que o conteúdo da linha é inserido.

Regras de comportamento:
- **Edição de conteúdo dentro de uma linha já existente não altera sua data** — mesmo que a edição ocorra no meio de um parágrafo já escrito.
- **A data só é atualizada automaticamente quando a linha é totalmente apagada e depois recriada** (deixa de existir e um novo conteúdo surge naquela posição).
- **O usuário pode sobrescrever manualmente a data de qualquer linha**, a qualquer momento, independente do comportamento automático.
- A identificação de "mesma linha entre uma edição e outra" é resolvida por um algoritmo de diff (comparação estrutural linha a linha entre o estado anterior e o novo estado do texto), e não por uma comparação simples de índice/posição.

### RF04 — CRUD de Bloco
O usuário pode criar, ler, atualizar e excluir um **Bloco** — uma pasta que agrupa Páginas de uma mesma categoria.

### RF05 — Tela inicial
Ao abrir o aplicativo, a primeira tela exibe a lista de Páginas e Blocos existentes, cada um identificado por um título.

### RF06 — Armazenamento interno vs. formato de intercâmbio
- O conteúdo das Páginas é armazenado internamente em um **banco de dados local próprio** (não em arquivos `.txt` soltos), permitindo guardar metadado por linha (data de criação, flag de edição manual de data, etc.).
- O formato `.txt` é usado **exclusivamente como formato de importação e exportação** — não como formato de armazenamento interno.

### RF07 — Criptografia
O usuário pode ativar criptografia para uma Página ou para um Bloco inteiro, protegida por uma senha definida por ele. O conteúdo protegido fica cifrado no armazenamento local (banco de dados interno), sendo decifrado apenas mediante senha correta.

### RF08 — Importação e exportação
O usuário pode exportar uma Página (ou o conjunto de Páginas de um Bloco) como arquivo `.txt` puro, e importar arquivos `.txt` externos, que são convertidos em novas Páginas (cada linha do arquivo importado recebe a data do momento da importação).

---

## Requisitos não funcionais

### RNF01 — Offline-first
O aplicativo funciona totalmente e prioritariamente offline, sem depender de conexão com internet para nenhuma funcionalidade essencial.

### RNF02 — Simplicidade e performance
Interface simples e intuitiva. Aplicativo rápido e leve, com atenção especial à performance da rotina de diff/datação em páginas com grande volume de texto (processamento assíncrono, sem travar a digitação).

---

## Modelo de dados (proposta)

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

Linha
- id
- pagina_id
- ordem (posição atual na página)
- texto
- data (apenas dia, sem hora)
- data_editada_manualmente (bool)
```

O texto exibido no editor é reconstruído concatenando as `Linha.texto` na ordem. Ao salvar, o novo texto é comparado (diff linha a linha) contra o estado anterior para decidir quais linhas mantêm data, quais recebem nova data e quais foram removidas.

**Limitação conhecida e aceita:** em casos de linhas duplicadas (mesmo conteúdo repetido em posições diferentes do texto), o diff resolve o pareamento por proximidade posicional, podendo eventualmente atribuir a data à cópia "errada". Não é um problema crítico e pode ser revisitado se necessário.

---

## Metodologia de desenvolvimento

Desenvolvimento incremental por sprints, priorizando funcionalidades que podem ser implementadas e testadas de forma independente antes de somar complexidade (como criptografia, que intercepta leitura/escrita em todo o sistema).

| Sprint | Entrega |
|---|---|
| 0 — Fundação | Banco de dados local, modelo Bloco/Página/Linha, tela inicial, CRUD de Bloco e Página |
| 1 — Editor e datação | Editor de texto contínuo, engine de diff linha a linha, persistência de data automática, edição manual de data |
| 2 — Busca | Busca por palavra/frase dentro da página |
| 3 — Import/Export | Exportação e importação de `.txt` |
| 4 — Criptografia | Senha por Página/Bloco, cifragem em repouso, fluxo de desbloqueio |
| 5 — Polimento | Performance, robustez offline, ajustes de UX |

---

## Stack técnica sugerida

- **State management:** Riverpod
- **Banco de dados local:** SQLite via `drift`
- **Diff de texto:** `diff_match_patch` (modo linha) ou implementação própria baseada em Myers diff
- **Criptografia:** `cryptography`/`encrypt` (AES-256-GCM) + derivação de chave via PBKDF2/Argon2, com salt gerenciado via `flutter_secure_storage`
- **Import/Export:** `file_picker` + `share_plus`