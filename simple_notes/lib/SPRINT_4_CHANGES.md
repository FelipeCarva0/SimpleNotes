# Sprint 4 — Arquivo (Arquivador) — Busca, navegação e reordenação: o que mudou

**Status: EM ANDAMENTO.** Este documento registra o que já foi implementado
e validado. As etapas 4.4 a 4.7 (busca por palavra, lista de resultados,
faixa de datas, ações em lote e fechamento) estão pendentes e são listadas
ao final.

Cobre a Sprint 4 da especificação v5.1 (RF05, RF06.1) e três mudanças de
escopo decididas durante a sprint: **data ao lado de cada mensagem**,
**detalhes da mensagem por gesto** e **reordenação de mensagens**.

> Os documentos `SPRINT_0_CHANGES.md` a `SPRINT_3_CHANGES.md` descrevem
> estados anteriores. Em caso de divergência, vale este arquivo.

---

## Decisões de escopo

| Decisão | Resultado |
|---|---|
| Natureza da busca na conversa | A lista **nunca é filtrada**: toda busca **leva ao ponto da conversa** onde a mensagem foi postada (com destaque temporário) |
| Texto | Ignora **maiúsculas e acentos** ("jose" acha "José") |
| Busca por palavra (4.4/4.5) | Duas formas: **na conversa** (palavra destacada, saltos entre ocorrências) e **lista de resultados** (toque leva ao local) |
| Busca por data (4.3/4.6) | **Simples**: vai para a primeira mensagem do dia. **Faixa**: lista das mensagens, com seleção e ações em lote |
| Filtros (4.5) | Tipo de arquivo e tag, **vários ao mesmo tempo**, combináveis entre si. "Ou" dentro de uma categoria, "e" entre categorias |
| Ações em lote (4.6) | Definir/remover tag, editar data e excluir |
| Legenda de imagem/vídeo (4.4) | Nome de exibição sob a miniatura |
| Acesso à pesquisa | Botão ⋮ no canto superior direito do chat, com **Pesquisar** e **Gerenciar tags** |
| Busca por título (Home) | Lupa na AppBar; única busca que atravessa Conversas |
| Data da mensagem | Fica **ao lado esquerdo de cada mensagem**, em uma linha, discreta; com tag, dentro da fita abaixo do título; sem tag, na mesma posição, sem fundo colorido. Separadores de dia **removidos** |
| Detalhes da mensagem | Arrastar a mensagem **ou a fita** para a **esquerda** abre a folha de detalhes |
| Reordenação | **Segurar e mover na vertical**, direto no chat. A data viaja com a mensagem |
| Schema | **Inalterado (v4).** A proposta de `criadoEm`/`editadoEm` (schema v5) foi **cancelada** |
| Plano B de reordenação (modo "Reordenar" pelo ⋮) | **Ignorado por ora** |

---

## Etapas executadas

| Etapa | Entrega | Status |
|---|---|---|
| 4.0 | Fundação em Dart puro: normalização de texto, `MessageFilter`, função de busca | Concluída |
| 4.1 | Busca por título na Home (RF06.1) | Concluída |
| 4.2 | Navegação: `ScrollablePositionedList`, "ir para a mensagem" com destaque | Concluída |
| 4.3 | Menu ⋮ com Pesquisar e busca por **data simples** | Concluída |
| A2 | Layout: data ao lado de cada mensagem, sem separadores | Concluída |
| A3 | Detalhes da mensagem por swipe para a esquerda | Concluída |
| A4.1 | `reorderMessage` no repositório | Concluída |
| A4.2 | Gesto de segurar e mover | Concluída |
| A4.3 | Rolagem automática, vibração e desfazer | Em teste |
| A4.4 | "Mover para o início/fim" no menu de ações | Em teste |
| 4.4 a 4.7 | Palavra, lista de resultados, faixa de datas, fechamento | **Pendentes** |

---

## Dependências

```yaml
dependencies:
  scrollable_positioned_list: ^0.3.8
  flutter_localizations:
    sdk: flutter
```

- `scrollable_positioned_list`: permite rolar até uma mensagem específica
  mesmo com balões de alturas diferentes (o `ListView.builder` comum não
  permite).
- `flutter_localizations`: calendário e diálogos em português (pt-BR).

---

## Arquivos novos

```
lib/
├── search/
│   ├── message_filter.dart          # MessageFilter: texto, datas, tipos, tags
│   └── message_search.dart          # searchMessages, SearchHit, firstIndexOnDate
├── utils/
│   └── text_normalize.dart          # normalizeText, findMatches, MatchRange
└── widgets/
    ├── search_options_sheet.dart    # sheet "Pesquisar" (modos de busca)
    └── message_details_sheet.dart   # folha de detalhes da mensagem
```

## Arquivos alterados

| Arquivo | Alteração |
|---|---|
| `pubspec.yaml` | `scrollable_positioned_list`, `flutter_localizations` |
| `lib/app.dart` | Locale pt-BR e delegates de localização |
| `lib/utils/format.dart` | `formatDate(DateTime)` (`dd/mm/aaaa`) |
| `lib/screens/home_screen.dart` | Reescrita como `ConsumerStatefulWidget` com busca por título |
| `lib/screens/chat_screen.dart` | Lista com `ScrollablePositionedList`; menu ⋮; busca por data; swipe duplo; detalhes; modo mover; rolagem automática; desfazer; `_showMessageActions` ampliado |
| `lib/widgets/message_bubble.dart` | `LayoutBuilder`; largura relativa à linha (70%); faixa de data/tag sempre desenhada; mídia de 220 para 200 px; o balão **não recebe mais `onLongPress`** (o gesto fica fora) |
| `lib/widgets/tag_ribbon.dart` | Agora recebe `date` e `Tag?`; altura 30; mostra data abaixo do título, com ou sem tag |
| `lib/repositories/conversation_repository.dart` | `reorderMessage(messageId, newIndex)` |

---

## Componentes

### Fundação de busca (4.0)
- `normalizeText`: minúsculas e sem acentos, **preservando o tamanho da
  string**. Essa propriedade permite usar posições achadas no texto
  normalizado para destacar a palavra no texto original.
  Limite conhecido: acentos "decompostos" (letra + acento combinado, comum
  em nomes vindos do macOS) não são tratados.
- `findMatches(text, query)`: ocorrências sem sobreposição, como `MatchRange`.
- `MessageFilter`: texto, intervalo de datas (inclusivo, mesmo dia = data
  exata), tipos (conjunto) e tags (conjunto). `copyWith` com `clearDates`.
- `searchMessages`: aplica o filtro sobre a lista completa **em memória**,
  preservando a ordem (`position`), e devolve `SearchHit` com o índice na
  lista completa e as ocorrências no texto exibido. O nome **original** do
  arquivo também conta para casar (RF05). Intervalo invertido tem as pontas
  trocadas.
- `firstIndexOnDate`: primeira mensagem **na ordem da conversa** com a data.

> Filtrar em memória (e não em SQL) é intencional: o resultado precisa da
> posição na lista completa para navegar, e o `LIKE` do SQLite não ignora
> acentos.

### Busca por título na Home (4.1)
- Lupa troca o título por um campo; filtra ao digitar, ignorando maiúsculas
  e acentos.
- Botão voltar do sistema e seta fecham a busca antes de sair da tela
  (`PopScope`).
- Botão `+` oculto durante a busca.
- Estados vazios distintos: "Nenhuma conversa ainda" e "Nenhuma conversa
  encontrada". Renomear e excluir funcionam sobre a lista filtrada.

### Navegação até a mensagem (4.2)
- Lista **invertida** (`reverse: true`): o fim da conversa é o índice 0 do
  widget, como em apps de chat. Com poucas mensagens, elas ficam coladas no
  fim da tela.
- O índice do widget é invertido (`total - 1 - índice cronológico`); a
  conversão fica concentrada no `itemBuilder` e em `_goToMessage`.
- `_goToMessage(index, total, messageId)`: rola (alinhamento 0.4) e aplica
  destaque temporário de ~1,8 s. `_flashHighlight` aplica só o destaque.
- Auto-scroll para o fim ao chegar mensagem nova continua funcionando.

### Menu ⋮ e data simples (4.3)
- Menu com **Pesquisar** e **Gerenciar tags** (o ícone de tag solto saiu da
  AppBar).
- Sheet "Pesquisar" com o modo **Ir para uma data** (os demais entram nas
  próximas etapas).
- Calendário limitado ao período da conversa (data mais antiga à mais
  recente, calculado sem assumir ordem). Dia sem mensagem: aviso "Nenhuma
  mensagem em dd/mm/aaaa". Conversa vazia: aviso, sem abrir o calendário.
- A "primeira mensagem do dia" segue a **ordem da conversa**, não a data.

### Data ao lado da mensagem (A2 e ajuste)
- Cada mensagem mostra a própria data (`dd/mm/aaaa`) no canto esquerdo da
  linha, em letra pequena (9) e discreta.
- **Com tag:** fita de 30 px de ponta a ponta, título em cima e data logo
  abaixo, dentro da fita.
- **Sem tag:** a data fica na **mesma posição**, sem fundo colorido.
  Por isso a data não "pula" ao definir ou remover a tag, nem enquanto as
  tags carregam.
- Separadores de dia removidos (não funcionam com reordenação).
- Balão com largura máxima de 70% da linha; miniaturas de 200 px, para
  caberem inteiras também em mensagens com tag.

### Detalhes da mensagem (A3)
- `Dismissible` horizontal: direita abre a tag, **esquerda abre os
  detalhes** (a fita é parte da linha, então arrastá-la funciona igual).
- Folha com: tipo, data (com aviso se editada manualmente), tag, posição
  ("Mensagem X de N") e, para texto, caracteres e palavras; para anexos,
  nome, nome original, formato (MIME) e tamanho, mais o botão **Abrir
  arquivo**.
- Sem data/hora de criação nem última alteração (exigiriam coluna nova).
- O toque no balão não mudou: texto abre a edição, anexos abrem o arquivo.

### Reordenação (A4.1 a A4.4)
- `reorderMessage(messageId, newIndex)`: move a mensagem para a posição
  final `newIndex` (0 = primeira), renumera `position` de 0 a N-1 em
  transação e atualiza só as linhas que mudaram. Devolve o índice anterior
  (usado pelo Desfazer) ou `null` se nada mudou. Índice fora do intervalo é
  ajustado. **Escreve apenas `position`**: `data`, `dataEditadaManualmente`,
  `tagId` e `atualizadoEm` da conversa permanecem intactos.
- **Gesto:** segurar parado e soltar abre o menu de ações (agora **ao
  soltar**); segurar e mover mais de 12 px entra no modo mover: a original
  esmaece, um cartão compacto (ícone do tipo, trecho de uma linha, cor da
  tag) segue o dedo e uma linha mostra onde vai cair. Soltar grava e
  destaca a mensagem.
- **Cálculo da posição de queda:** cada linha se registra num `_ItemProbe`
  (evita `GlobalKey` por item, pois a lista pode montar a mesma linha duas
  vezes em saltos animados). O índice final é o número de outras mensagens
  com o centro acima do dedo.
- **Rolagem automática** (A4.3): a 72 px do topo ou do fim da lista, rola
  em passos de até 22 px a cada 40 ms, mais rápido perto da borda. A linha
  de inserção é recalculada a cada passo.
- **Linha em movimento mantida viva** (`AutomaticKeepAliveClientMixin`),
  para não ser desmontada durante a rolagem longa (o que cancelaria o
  gesto). O cálculo de queda ignora a própria linha movida.
- **Vibração** a cada novo ponto de inserção.
- **Desfazer:** aviso "Mensagem movida" por 5 s com botão Desfazer, que
  move de volta ao índice original.
- **Sem arrastar** (A4.4): itens **Mover para o início** e **Mover para o
  fim** no menu de ações (ocultos quando a mensagem já está nessa posição),
  com rolagem até a mensagem, destaque e Desfazer. O menu ganhou rolagem
  (`SingleChildScrollView`).

---

## Regras de negócio preservadas

- A busca **nunca altera a conversa** nem filtra a lista exibida.
- Reordenar **não altera** `data`, `dataEditadaManualmente`, `tagId` nem
  `atualizadoEm`. A data e a tag viajam com a mensagem.
- Depois de mover, as datas podem ficar fora de sequência na tela (esperado).
  "Primeira mensagem do dia" segue a ordem atual da conversa.
- A busca por título (Home) só filtra a lista de conversas e não dá acesso a
  conteúdo.
- Toque, long-press e os dois swipes continuam sem conflito entre si.

---

## Checklist de fechamento parcial (etapas já implementadas)

- [ ] `flutter analyze` sem issues
- [ ] Home: busca por título com e sem acento e sem diferenciar maiúsculas
- [ ] Home: voltar fecha a busca; `+` some durante a busca
- [ ] Chat abre no fim; poucas mensagens ficam coladas no fim da tela
- [ ] Data simples leva à primeira mensagem do dia; dia vazio mostra aviso
- [ ] Data em uma linha à esquerda; com tag, dentro da fita, na mesma posição
- [ ] Miniaturas inteiras no balão, com e sem tag
- [ ] Swipe para a direita (tag) e para a esquerda (detalhes), também pela fita
- [ ] Detalhes corretos para os cinco tipos; "Abrir arquivo" funciona
- [ ] Segurar e soltar abre o menu; segurar e mover reordena
- [ ] Rolagem automática nas duas direções e vibração a cada ponto
- [ ] Desfazer devolve a posição original
- [ ] Mover para o início/fim, com itens ocultos nas extremidades
- [ ] Data e tag acompanham a mensagem movida
- [ ] Ordem mantida após fechar e reabrir o app
- [ ] `flutter run --profile`: scroll fluido com muitas mensagens e mídias

---

## Limitações conhecidas e pendências

1. **Etapas 4.4 a 4.7 pendentes:** busca por palavra (destaque, contador,
   setas), lista de resultados única (palavra, tipo, tag), data por faixa
   com seleção e ações em lote, legenda de imagem/vídeo e fechamento.
2. **Código de busca ainda sem uso:** `MessageFilter`, `searchMessages`,
   `SearchHit` e `findMatches` foram criados na 4.0 e só serão ligados à
   interface nas etapas 4.4 a 4.6. Hoje só `normalizeText` (Home) e
   `firstIndexOnDate` (data simples) estão em uso.
3. **Nome `TagRibbon` desatualizado:** a classe agora é a "faixa de
   metadados" da mensagem (data, com ou sem tag). Renomear é opcional.
4. **`MessageBubble.onLongPress`** continua existindo como parâmetro, mas o
   long-press agora é tratado fora do balão (no `GestureDetector` da linha).
   Pode ser removido.
5. **Menu de ações abre ao soltar**, não durante a segurada (consequência do
   gesto de mover).
6. **Desfazer** volta ao índice original; se mensagens forem excluídas nos 5
   segundos seguintes, a posição pode diferir um pouco.
7. **Constantes a calibrar no aparelho:** limite de 12 px para entrar no
   modo mover, zona de borda de 72 px e passo máximo de 22 px da rolagem
   automática, altura do cartão (48), altura da fita (30) e fonte da data (9).
8. **Sem "última alteração" nem hora de criação** na folha de detalhes (exigem
   coluna nova; a proposta de schema v5 foi cancelada). Fica como evolução.
9. **Data em duas linhas descartada:** a coluna fixa de data (`_DateColumn`)
   foi substituída pela data dentro da faixa.
10. **Pendências herdadas:** progresso real de cópia, varredura de órfãos em
    `media/`, player interno, seleção múltipla de anexos, subtítulo de data na
    home (`atualizadoEm`), remoção de `line_diff_engine.dart`, `TagChip.compact`
    sem uso.

---

## Atualizações sugeridas para a especificação

Itens que ainda **não estão** na spec v5.1 e que valem ser registrados:

- **RF04:** escopo da Tag por Conversa (`conversa_id` no modelo, nome único
  dentro da Conversa, excluir a Conversa exclui suas Tags).
- **RF02 (novo):** reordenação de mensagens por gesto de segurar e mover e
  por "mover para o início/fim", com desfazer; a data e a tag viajam com a
  mensagem; `position` é a única coluna alterada.
- **RF02 (novo):** folha de **detalhes da mensagem** por gesto de arrastar
  para a esquerda.
- **RF03:** a data é exibida **ao lado de cada mensagem** (sem separadores de
  dia).
- **RF05:** busca por palavra (na conversa e em lista de resultados), por data
  simples e por faixa, e filtros múltiplos de tipo e tag; a busca **leva ao
  local da mensagem** em vez de filtrar a conversa; ações em lote sobre
  resultados de faixa de datas.
- **Estrutura de diretórios:** `search/`, `utils/text_normalize.dart`,
  `widgets/search_options_sheet.dart`, `widgets/message_details_sheet.dart`.

---

## Próximos passos

1. Validar o checklist acima no aparelho.
2. **4.4:** busca por palavra na conversa (destaque, contador, setas) e
   legenda de imagem/vídeo.
3. **4.5:** lista de resultados única e filtros de tipo e tag.
4. **4.6:** data por faixa, seleção e ações em lote.
5. **4.7:** fechamento, performance em profile e atualização deste documento.