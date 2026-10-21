# Spec — home com carrosséis (AP-31 / AP-32 / AP-33 / AP-34)

> Itens do Jira: **AP-31** (US "home com carrosséis") e as subtarefas **AP-33** (consumo e
> estados), **AP-32** (layout) e **AP-34** (cache de pôster). Regras gerais:
> [`constitution.md`](../constitution.md).

## Objetivo

A home deixa de ser prova de fiação ("Backend respondeu: ok") e passa a ser a porta de
entrada do produto: dois carrosséis com títulos reais do TMDB, vindos pelo proxy do backend,
com a atribuição do TMDB visível.

## Escopo

- model do item de TMDB + wrapper de resposta (`resultados`)
- `emAlta()` e `populares()` no `RestClient`
- `TituloRepository` (contrato) + `TituloRepositoryImpl`
- `HomeViewModel` com **dois estados independentes** (em alta e populares): carregando, erro
  e lista, cada um com o seu load
- `CarouselSection` (título da seção + lista horizontal) e `PosterCard` (pôster, título em
  2 linhas, ano)
- dedupe entre os carrosséis: o segundo não repete o que o primeiro mostrou
- pôster em `CachedNetworkImage` (o `cached_network_image` já está no `pubspec` desde o PR #6)
- rodapé com a atribuição do TMDB
- testes de repository e de ViewModel; widget test é opcional neste projeto

## Fora de escopo

buscar (AP-43), detalhe (AP-46), filtro por tipo (AP-35), marcar no acervo (AP-49),
paginação, "ver mais", animações de entrada, tema/paleta.

## Contrato (conferido em `specs/contrato-api.md` do backend)

```json
{ "resultados": [ { "id": 123, "tipo": "movie", "titulo": "...", "ano": "2025", "posterPath": "/x.jpg" } ] }
```

- `GET /api/v1/em-alta` e `GET /api/v1/populares`, até 10 itens, filmes e séries
  **intercalados**, cache de 60 s no servidor
- `id` aqui chama `id` (não `tmdbId`, como no acervo) e `ano` é string
- `posterPath` pode vir nulo: a tela mostra um card cinza com ícone, nunca quebra
- a imagem é montada com `https://image.tmdb.org/t/p/w342` + `posterPath` (a chave da API
  não entra em URL de imagem)
- o token vai por interceptor; nenhum método recebe token

## Decisões

| tema | decisão | por quê |
|---|---|---|
| ordem | **AP-33 → AP-32 → AP-34** | o card manda: fazer layout antes do dado obriga a refazer a tela com dado falso |
| estado | **dois blocos independentes no mesmo `HomeViewModel`** (`emAlta` e `populares`) | se um carrossel falhar, o outro continua; erro de um não derruba a home |
| forma do estado | classe pequena imutável `SecaoTitulos(carregando, erro, itens)` | evita 6 campos soltos no VM e deixa o `switch` do Result no mesmo lugar |
| dedupe | o segundo carrossel pula ids já mostrados no primeiro | o TMDB repete título entre "em alta" e "populares" |
| imagem | `CachedNetworkImage` desde o começo | o AP-34 já está no mesmo PR; trocar depois seria retrabalho |
| atribuição | rodapé fixo da home, com o texto oficial do TMDB | critério de aceite do AP-31 e exigência de uso da API |

## Health e a contagem do acervo na home

Duas coisas que já estão na tela e o card não menciona:

- **health** (`Backend respondeu: ok`): era prova de fiação. Com carrossel de dado real, vira
  ruído e código sem leitor na tela.
- **contagem do acervo** (`Seu acervo: N títulos`, do AP-28): continua útil.

Proposta (pendente de decisão do dono):

- remover o health **da home** e apagar `HealthViewModel`/`HealthRepository` + os testes deles,
  que ficariam sem leitor (é a mesma regra que removeu `usuarioAtual` do contrato);
- manter a contagem do acervo no rodapé, **acima** da linha de atribuição do TMDB.

## Arquivos

nascem:

- `lib/data/api_models/tmdb_item.dart` (+ `.g.dart`)
- `lib/data/api_models/em_alta_response.dart` (+ `.g.dart`)
- `lib/data/repositories/titulo_repository.dart`
- `lib/data/repositories/titulo_repository_impl.dart`
- `lib/ui/view_model/secao_titulos.dart` (estado imutável de uma seção)
- `lib/ui/widgets/poster_card.dart`
- `lib/ui/widgets/carousel_section.dart`
- `lib/utils/tmdb_image.dart`
- testes: repository, ViewModel, model

entram:

- `lib/data/services/rest_client.dart` (+ `.g.dart`)
- `lib/ui/view_model/home_view_model.dart` (reescrito: dois carrosséis)
- `lib/ui/view/home_page.dart` (corpo novo)
- `lib/main.dart` (providers novos)
- `test/ui/view/home_page_test.dart` (reescrito) e os testes que montam a home
  (`auth_gate_test`, `login_flow_test`)

saem (se o dono aprovar):

- `lib/ui/view_model/home_view_model.dart` atual (health), `lib/data/repositories/health_repository*.dart`,
  `lib/data/api_models/health_status*.dart`, `test/.../health_repository_test.dart`,
  `test/.../home_view_model_test.dart` (health)

## Passos (um commit por assunto)

1. `docs(home): spec da home com carrosseis`
2. `feat(home): models do item de TMDB e da resposta com resultados` (o `TipoMidia` saiu para
   `tipo_midia.dart`, para o acervo e o catálogo usarem o mesmo enum)
3. `feat(home): em-alta e populares no RestClient`
4. `feat(home): repositorio de titulos com erro tipado` + testes
5. `feat(home): view model com dois carrosseis independentes` + testes
6. `feat(home): carrosseis com cache de poster e atribuicao, e saida do health` — a remoção do
   health entrou junto porque é a mesma mudança de tela (a home deixa de ser prova de fiação)
7. `docs(home): fecha a spec com a validação`

## Critério de pronto

- `flutter analyze` limpo e `flutter test` verde (CI verde no PR)
- repository: 200 com itens, lista vazia e falha de rede
- ViewModel: carrega as duas seções; erro em uma não apaga a outra; falha de rede vira frase
  pronta
- na tela, logado: dois carrosséis com títulos reais, pôster, título e ano; rolar para o lado
  funciona; sem faixa de overflow em 360x640
- atribuição do TMDB visível no rodapé
- pôster nulo vira card cinza com ícone (não quebra)
- pôsteres não são rebaixados ao rolar para baixo e voltar (cache)
- horas das subtarefas atualizadas no Jira

## Validação feita (21/10)

- `flutter analyze` limpo e `flutter test` **166/166**
- `flutter build web --release` ok, com as strings dos dois carrosséis e da atribuição no bundle
- **prova real dos endpoints** com token da conta de teste, contra produção: `/em-alta` e
  `/populares` devolveram 10 itens cada, **5 filmes + 5 séries intercalados**, todos com
  `posterPath`. É o dado que a tela desenha
- teste de widget da home: dois carrosséis, atribuição, contagem do acervo, seção que falha sem
  derrubar a outra e o primeiro frame sem os títulos da conta anterior
- **aberto**: ver na tela logado (a leitura depende de sessão), rolar os carrosséis e conferir
  ausência de overflow em 360x640

## Review (21/10) — o que mudou depois

Duas revisões independentes, **2 bloqueantes** (ambos reproduzidos por teste antes do conserto):

| achado | correção |
|---|---|
| **bloqueante**: o carregador da carga velha punha a seção em `carregando` e notificava **antes** do check de geração, então uma carga antiga que terminasse depois da nova deixava "Populares" girando para sempre, com o conteúdo apagado | o check de geração passou a ser a primeira linha dos dois carregadores; teste de corrida com `Completer` (carga A terminando depois de B) |
| **bloqueante**: a invalidação por geração não tinha teste (removendo os dois `if`, a suíte continuava verde) | o mesmo teste de corrida cobre: a resposta da conta anterior não entra e nenhuma seção fica `carregando` |
| `on Exception` não pega `Error` (cast quebrado, `StateError`) e a seção ficava girando | `catch` genérico no `_resultado`, com teste que lança `StateError` |
| dedupe por `id` só, e congelado na carga (retry de "Em alta" duplicava título) | dedupe **derivado na leitura**, com `chaveTitulo(tipo, id)`; teste de retry |
| atribuição e conta logada só apareciam depois de rolar | viraram **rodapé fixo**, fora do scroll |
| o e-mail da conta logada tinha desaparecido na reescrita | voltou, no rodapé, com teste |
| `posterPath`/`ano` vazios (`""` do backend) deixavam linha fantasma | card trata vazio como ausente |
| fixture do 502 usava código inexistente (`tmdb_unavailable`) | `tmdb_error`, fiel ao contrato |
| nenhum teste do model | `test/data/api_models/tmdb_item_test.dart` com o literal do contrato, lista vazia, `posterPath` nulo e tipo desconhecido |
| docs ainda apontavam para o health removido (README, tutorial, `Result`) | atualizados para a home |

### Segunda rodada (concluída)

Depois do conserto, duas revisões independentes de novo — **0 bloqueante de regressão** e **3 testes
falso-verdes**, todos fechados (cada um provado por mutação, com o teste falhando antes do ajuste):

| teste que prometia e não cobria | conserto |
|---|---|
| "a segunda carga não devolve os títulos da sessão anterior" — as fixtures da 2ª carga eram vazias, então apagar o reset do `load()` continuava verde | reescrito: durante o reload afirma `carregando` e listas vazias |
| "em tela pequena (360x640)" — o fake de auth nunca emitia usuário, então o e-mail (e o `maxLines` do fix anterior) não era exercitado | emite usuário com e-mail longo e afirma `maxLines == 1` + `ellipsis` |
| "primeiro frame após o login" — só o `HomeViewModel` vinha sujo; apagar `AcervoViewModel.reset()` do `initState` passava | o acervo também entra sujo (3 itens) e a contagem antiga tem de sumir |

Também fechados: dedupe com o **mesmo id em tipos diferentes** (filme 550 × série 550), `carregando == true`
afirmado (o reset não pode virar "Nada por aqui agora"), mensagem exata no teste do `Error`, **401 sem corpo**
no `TituloRepository` (o switch do `error_mapper` não era exercitado), `id` decimal no model, e teste do
`PosterCard` para pôster nulo, título vazio e ano vazio.

Ajustes de código que vieram junto: o retry agora **preserva os itens** da seção (sem isso o dedupe soltava os
títulos duplicados durante a recarga), `SafeArea` no rodapé (gesture bar) e log com stack no `catch`.

Backlog declarado: retry durante um `load()` em voo pode disparar duas requisições para a mesma seção
(resolver com token por seção) — a UI esconde o botão durante a carga, então não é observável hoje.

Decisão mantida: a carga continua **sequencial** (o segundo carrossel precisa do primeiro para o dedupe). O `finally` garante que "Populares" roda mesmo se "Em alta" falhar.

## Riscos

- `home_page_test`, `auth_gate_test` e `login_flow_test` montam a home: todos passam a precisar
  dos providers novos (o texto "Backend respondeu: ok" saiu junto com o health)
- `cached_network_image` no web usa o cache do navegador; provar o cache no DevTools, não por
  impressão
- o `posterPath` às vezes vem nulo: teste com ele nulo, não só com o caminho feliz
