# Spec — acervo na nuvem (AP-26 / AP-28)

> Item do Jira: **AP-26** (US "acervo na nuvem por usuária") e **AP-28** (leitura do acervo
> no login). Regras gerais: [`constitution.md`](../constitution.md).
> Tutorial passo a passo, para quem está começando: [`docs/tutorial-acervo.md`](../docs/tutorial-acervo.md).

## Objetivo

O acervo da usuária vem do servidor, preso à conta. Ao entrar, o app já sabe o que ela
marcou, em qualquer aparelho. Esta fatia entrega **só a camada de dados + o carregamento
no login**, sem tela de acervo: quem desenha as abas é o AP-59.

## Escopo

- DTO do `GET /api/v1/acervo`
- endpoint no `RestClient`
- `AcervoRepository` (contrato) + `AcervoRepositoryImpl`
- `AcervoViewModel` com a lista e a consulta de estado por título
- carga do acervo no login (o `initState` da `HomePage`)
- prova visível mínima na home: a contagem de títulos do acervo
- testes de repository e de ViewModel (widget test é opcional neste projeto)

## Fora de escopo

marcar/desmarcar (AP-49 em diante), tela das abas (AP-59), cache de pôster (AP-34/AP-62),
leitura offline (AP-77), histórico (AP-73). O `shared_preferences` que entrou no PR #7 **não**
é usado aqui: acervo não tem espelho local, quem guarda é o servidor.

## Contrato (`GET /api/v1/acervo`)

Array na raiz, mais recente primeiro, filtrado pelo uid do token (o app nunca manda id de
usuário). Campos reais, conferidos em `specs/contrato-api.md` do backend:

```json
[
  {
    "tmdbId": 1399,
    "estado": "watching",
    "tipo": "tv",
    "titulo": "Game of Thrones",
    "ano": "2011",
    "posterPath": "/1XS1oqL89opfnbLl8WnZY1O1uJx.jpg",
    "atualizadoEm": "2026-10-20T12:00:00.000Z"
  }
]
```

- `estado` ∈ `plan_to_watch` · `watching` · `watched` · `dropped`
- `tipo` ∈ `movie` · `tv`, e pode vir **null** numa linha anterior à migração 008
- `titulo`, `ano` (string, não número) e `posterPath` podem vir **null** quando a ficha do
  TMDB falhou na hora da marcação
- vazio é `[]` com 200, nunca 404

## Decisões desta fatia

| tema | decisão | por quê |
|---|---|---|
| chave do estado | **`(tipo, tmdbId)`**, não só `tmdbId` | o TMDB numera filme e série em espaços separados: `550` é *Clube da Luta* (filme) e *Till Death Us Do Part* (série). Um mapa só por id devolveria o estado errado para um dos dois |
| `estado` no model | `enum EstadoAcervo` com `@JsonKey(unknownEnumValue: EstadoAcervo.desconhecido)` | servidor novo + app antigo não pode quebrar a tela inteira por um valor desconhecido |
| `tipo` no model | `enum TipoMidia?`, anulável | linha antiga do banco tem `tipo` nulo e o campo é opcional no JSON |
| carga | no `initState` da `HomePage`, igual ao health | o ViewModel é criado uma vez no `main.dart`; a tela é remontada a cada login, e é isso que faz a conta nova começar limpa |
| reset | o `load()` **zera a lista e avisa** antes de buscar | senão a conta nova vê o acervo da anterior por um frame |
| falha do acervo | não derruba a home: a home mostra o health e uma linha do acervo com "tentar de novo" | o acervo é um bloco da tela, não a tela |
| linha antiga sem `tipo` | o estado dela responde aos **dois** espaços (`movie` e `tv`), e a linha tipada do mesmo id tem precedência | sem isso, uma linha anterior à 008 nunca seria encontrada por `estadoDe(tipo, id)`; a precedência evita que ela apague o estado de um filme/série já tipado |

## Arquivos

nascem:

- `lib/data/api_models/acervo_item.dart` (+ `.g.dart`)
- `lib/data/repositories/acervo_repository.dart`
- `lib/data/repositories/acervo_repository_impl.dart`
- `lib/ui/view_model/acervo_view_model.dart`
- `test/data/repositories/acervo_repository_test.dart`
- `test/ui/view_model/acervo_view_model_test.dart`

entram:

- `lib/data/services/rest_client.dart` (um método + `.g.dart` regerado)
- `lib/main.dart` (dois providers)
- `lib/ui/view/home_page.dart` (dispara o load e mostra a contagem)
- `test/ui/view/home_page_test.dart` (o widget test que já existe passa a precisar do provider novo)

## Passos (um commit por assunto)

1. `docs(acervo): plano e tutorial da feature` — esta spec + o guia
2. `feat(acervo): model do item de acervo com estado e tipo` — DTO + build_runner
3. `feat(acervo): GET /api/v1/acervo no RestClient` — endpoint + build_runner
4. `feat(acervo): repository do acervo com erro tipado` — contrato, impl e testes
5. `feat(acervo): view model do acervo com estado por título` — VM e testes
6. `feat(acervo): carrega o acervo no login` — providers no `main.dart` + `HomePage`
7. `docs(acervo): fecha o tutorial com as armadilhas medidas`

## Critério de pronto

- `flutter analyze` sem issue e `flutter test` verde (e CI verde no PR)
- repository: lista com itens, lista vazia e falha de rede cobertos por teste
- ViewModel: monta o mapa por `(tipo, tmdbId)` e uma segunda carga não devolve dado da
  sessão anterior (teste com respostas em sequência)
- ao entrar com uma conta que tem acervo, a home mostra o número certo de títulos
- ao entrar com conta vazia, mostra `0`
- `flutter run -d chrome --web-port 8080` logado: a contagem vem do servidor, não de constante
- as horas restantes do AP-28 atualizadas no Jira (a estimativa de 1 h não cobre os 7 passos;
  corrigir para 3–4 h na mesma passada)

## Riscos

- **`test/ui/view/home_page_test.dart` quebra** quando a `HomePage` passa a ler o
  `AcervoViewModel`: todo `pumpWidget` de home precisa registrar o provider novo. É o efeito
  colateral esperado de mexer na View, e o motivo de o widget test entrar no mesmo commit.
- o `build_runner` esquecido é erro de compilação confuso (`part of` sem o `.g.dart`): rodar
  antes de cada commit que toca DTO ou `RestClient`.
- o projeto é CRLF: arquivo novo em LF o git normaliza, mas arquivo sobrescrito em LF aparece
  inteiro modificado no diff.
