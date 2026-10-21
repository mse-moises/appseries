# Tutorial — a feature de acervo, camada por camada

> **Para quem está começando no app.** Este documento é o exemplo real de como uma feature
> nasce neste repositório, usando a tarefa **AP-26/AP-28 (acervo na nuvem)**. A ideia é que
> você leia este arquivo e consiga fazer a sua própria task copiando o caminho.
>
> Regras do projeto: [`constitution.md`](../constitution.md) · o plano desta fatia:
> [`specs/acervo.md`](../specs/acervo.md) · o resumo dos 7 passos:
> [`README.md`](../README.md#como-criar-uma-feature-nova-7-passos).
>
> É um guia escrito **junto com a implementação**. Se algum trecho divergir do código, o
> código é a verdade: abra o arquivo citado e compare.

## O que a feature faz

O acervo é o que a usuária marcou: "quero ver", "assistindo", "assistido", "abandonei".
Esse dado mora no **servidor**, preso à conta. Nesta fatia o app só **lê** a lista
(`GET /api/v1/acervo`) e deixa ela disponível para as telas. Não tem tela nova ainda: as
abas do acervo são a tarefa AP-59.

## Antes de encostar no código: entenda as 4 camadas

```
View (tela)  →  ViewModel  →  Repository  →  Service  →  backend
   desenha      estado        contrato+impl    HTTP
```

- **Service**: fala com o mundo externo. Aqui é o `RestClient` (retrofit sobre o `dio`). Não
  guarda estado e não sabe se a tela está carregando.
- **Repository**: recebe o Service e devolve sempre `Result<T>` — `Ok(valor)` ou
  `Error(AppError)`. Nunca joga exceção para a tela.
- **ViewModel**: é o dono do estado da tela (carregando, erro, dados) e avisa a View com
  `notifyListeners()`.
- **View**: desenha e repassa toque. Nunca chama Service.

O `login` é o molde completo dessas camadas; o `health` é o molde mais curto e é o que vamos
copiar aqui, porque ele também só **lê** um endpoint.

## Passo 0 — branch

```bash
git checkout main && git pull
git checkout -b feature/AP-28-acervo-na-nuvem
```

O nome segue `feature/<chave-do-Jira>-<nome-curto>`. Só existe `main` como branch de vida
longa; a volta é sempre por PR com 1 review.

## Passo 1 — model (o formato do dado)

`lib/data/api_models/acervo_item.dart`

**Por que**: o JSON chega como `Map<String, dynamic>`. O model transforma isso em objeto
tipado, e o `build_runner` gera a tradução (`acervo_item.g.dart`) para você não escrever
`json['tmdbId']` na mão em cada lugar.

```dart
import 'package:json_annotation/json_annotation.dart';

part 'acervo_item.g.dart';

/// The four states a title can have on the user's shelf.
enum EstadoAcervo {
  @JsonValue('plan_to_watch')
  planToWatch,
  @JsonValue('watching')
  watching,
  @JsonValue('watched')
  watched,
  @JsonValue('dropped')
  dropped,

  /// A value this app version does not know (server newer than the app).
  /// It must not break the whole list.
  @JsonValue('desconhecido')
  desconhecido,
}

/// `movie` or `tv` — the TMDB numbers each in its own space.
enum TipoMidia {
  @JsonValue('movie')
  movie,
  @JsonValue('tv')
  tv,
  @JsonValue('desconhecido')
  desconhecido,
}

/// Key of a shelf line: the same TMDB id can be a movie AND a series
/// (`550` is *Fight Club* and also *Till Death Us Do Part*), so the id alone
/// is not enough to know whose state we are reading.
String chaveEstado(TipoMidia tipo, int tmdbId) => '${tipo.name}:$tmdbId';

/// One line of `GET /api/v1/acervo`.
@JsonSerializable()
class AcervoItem {
  const AcervoItem({
    required this.tmdbId,
    required this.estado,
    this.tipo,
    this.titulo,
    this.ano,
    this.posterPath,
    this.atualizadoEm,
  });

  factory AcervoItem.fromJson(Map<String, dynamic> json) => _$AcervoItemFromJson(json);

  final int tmdbId;
  @JsonKey(unknownEnumValue: EstadoAcervo.desconhecido)
  final EstadoAcervo estado;
  @JsonKey(unknownEnumValue: TipoMidia.desconhecido)
  final TipoMidia? tipo;
  final String? titulo;

  /// Keeps the API type: the backend sends `"2011"`, not `2011`.
  final String? ano;
  final String? posterPath;
  final DateTime? atualizadoEm;

  Map<String, dynamic> toJson() => _$AcervoItemToJson(this);
}
```

Depois de salvar:

```bash
dart run build_runner build --delete-conflicting-outputs
```

**Como conferir**: o arquivo `acervo_item.g.dart` apareceu ao lado. Sem ele o compilador
reclama de `_$AcervoItemFromJson` (erro de `part of`, que assusta e não diz a causa).

**Erro comum**: tratar `ano` como `int`. O backend devolve string, porque ano de série às
vezes não é número ("2011–2019").

## Passo 2 — endpoint no Service

`lib/data/services/rest_client.dart` (arquivo que já existe)

**Por que**: o `RestClient` é a única porta para o backend, e o token do Firebase entra por
interceptor do `dio` — por isso **nenhum método recebe token**.

```dart
/// `GET /api/v1/acervo` — everything the signed-in user marked, newest first.
@GET('/api/v1/acervo')
Future<List<AcervoItem>> acervo();
```

Importe o model no topo (`import '../api_models/acervo_item.dart';`) e rode o
`build_runner` de novo: o `rest_client.g.dart` muda.

**Erro comum**: usar `@GET('api/v1/acervo')` sem a barra inicial. A `baseUrl` é só o host,
então o path precisa começar com `/`.

## Passo 3 — repository (contrato + implementação)

`lib/data/repositories/acervo_repository.dart`

```dart
import '../../utils/result.dart';
import '../api_models/acervo_item.dart';

/// Contract of the shelf resource. The ViewModel depends on this, never on the
/// implementation: that is what lets a test pass a fake.
abstract class AcervoRepository {
  Future<Result<List<AcervoItem>>> listar();
}
```

`lib/data/repositories/acervo_repository_impl.dart`

```dart
import 'package:dio/dio.dart';

import '../../utils/app_error.dart';
import '../../utils/result.dart';
import '../api_models/acervo_item.dart';
import '../services/error_mapper.dart';
import '../services/rest_client.dart';
import 'acervo_repository.dart';

/// Talks to the backend through [RestClient] and always answers a `Result`.
class AcervoRepositoryImpl implements AcervoRepository {
  AcervoRepositoryImpl(this._api);

  final RestClient _api;

  @override
  Future<Result<List<AcervoItem>>> listar() async {
    try {
      return Result.ok(await _api.acervo());
    } on DioException catch (e) {
      return Result.error(appErrorFromDio(e));
    } catch (_) {
      // A body in an unexpected shape (breaking fromJson, for instance) must
      // not escape either: the screen would stay loading forever.
      return const Result<List<AcervoItem>>.error(ServerError());
    }
  }
}
```

**Como conferir**: `flutter analyze` limpo.

**Por que esse `catch (_)`**: o contrato do repository é *sempre* responder `Result`. Se
deixar uma exceção escapar, o ViewModel precisa adivinhar, e é assim que tela fica presa em
"carregando".

## Passo 4 — ViewModel (o estado da tela)

`lib/ui/view_model/acervo_view_model.dart`

```dart
import 'package:flutter/foundation.dart';

import '../../data/api_models/acervo_item.dart';
import '../../data/repositories/acervo_repository.dart';
import '../../utils/app_error.dart';
import '../../utils/result.dart';

/// The user's shelf, as the screens need it: the list plus a lookup by title.
class AcervoViewModel extends ChangeNotifier {
  AcervoViewModel(this._repository);

  final AcervoRepository _repository;

  // `true` de saída: este ViewModel vive mais que a tela (é criado uma vez no
  // `main.dart`), então o primeiro frame de um login novo não pode desenhar o
  // acervo da conta anterior.
  bool _isLoading = true;
  String? _error;
  List<AcervoItem> _itens = const <AcervoItem>[];
  Map<String, EstadoAcervo> _estados = const <String, EstadoAcervo>{};
  int _geracao = 0;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<AcervoItem> get itens => _itens;
  int get total => _itens.length;

  /// `null` means "not on the shelf" (or unknown yet).
  ///
  /// O tipo é obrigatório: o id sozinho é ambíguo (filme 550 e série 550 são
  /// títulos diferentes). Para `desconhecido`, procura nos dois espaços.
  EstadoAcervo? estadoDe(TipoMidia tipo, int tmdbId) {
    if (tipo != TipoMidia.desconhecido) {
      return _estados[chaveEstado(tipo, tmdbId)];
    }
    return _estados[chaveEstado(TipoMidia.movie, tmdbId)] ??
        _estados[chaveEstado(TipoMidia.tv, tmdbId)];
  }

  /// Zera o estado da sessão anterior **sem notificar**.
  ///
  /// A tela chama isto no `initState`, antes do primeiro build: o ViewModel é
  /// criado uma vez na raiz, então no segundo login ele ainda tem o acervo da
  /// conta anterior, e notificar dentro do `initState` não é permitido. Quem
  /// avisa a View é o `load()` logo depois.
  void reset() {
    _itens = const <AcervoItem>[];
    _estados = const <String, EstadoAcervo>{};
    _error = null;
    _isLoading = true;
  }

  Future<void> load() async {
    // Contador de geração: a requisição da conta anterior pode responder DEPOIS
    // da nova (nada cancela a chamada no logout). Só a chamada mais recente pode
    // escrever estado, senão a lista volta a ser a de outra pessoa.
    final int geracao = ++_geracao;

    _itens = const <AcervoItem>[];
    _estados = const <String, EstadoAcervo>{};
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final Result<List<AcervoItem>> resultado = await _repository.listar();
      if (geracao != _geracao) return;
      switch (resultado) {
        case Ok<List<AcervoItem>>(:final value):
          _itens = List<AcervoItem>.unmodifiable(value);
          _estados = _mapaDeEstados(_itens);
        case Error<List<AcervoItem>>(:final error):
          _error = error.mensagem;
      }
    } on Exception catch (error) {
      if (geracao != _geracao) return;
      debugPrint('[AppSeries] acervo fora do contrato: $error');
      _error = const ServerError().mensagem;
    } finally {
      if (geracao == _geracao) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Builds the `(tipo, tmdbId) -> estado` lookup.
  ///
  /// A line written before migration 008 has no `tipo`, and we cannot know
  /// which space the id belongs to: it answers for both, the same rule the
  /// backend uses when vetoing recommendations. Typed lines are written last so
  /// they win over the ambiguous one.
  static Map<String, EstadoAcervo> _mapaDeEstados(List<AcervoItem> itens) {
    final Map<String, EstadoAcervo> mapa = <String, EstadoAcervo>{};

    for (final AcervoItem item in itens) {
      if (item.tipo == null || item.tipo == TipoMidia.desconhecido) {
        mapa[chaveEstado(TipoMidia.movie, item.tmdbId)] = item.estado;
        mapa[chaveEstado(TipoMidia.tv, item.tmdbId)] = item.estado;
      }
    }

    for (final AcervoItem item in itens) {
      final TipoMidia? tipo = item.tipo;
      if (tipo != null && tipo != TipoMidia.desconhecido) {
        mapa[chaveEstado(tipo, item.tmdbId)] = item.estado;
      }
    }

    return Map<String, EstadoAcervo>.unmodifiable(mapa);
  }
}
```

**Por que `switch` com `Ok<T>()` / `Error<T>()`**: `Result` é `sealed`, então o compilador
cobra os dois casos. É o mesmo desenho do `HomeViewModel`.

## Passo 5 — ligar tudo (a injeção é aqui)

`lib/main.dart`, dentro do `MultiProvider`:

```dart
Provider<AcervoRepository>(
  create: (ctx) => AcervoRepositoryImpl(ctx.read<RestClient>()),
),
ChangeNotifierProvider<AcervoViewModel>(
  create: (ctx) => AcervoViewModel(ctx.read<AcervoRepository>()),
),
```

**Erro comum e caro**: esquecer esta parte. Não dá erro de `analyze` — dá erro em runtime,
na primeira tela que chamar `context.read<AcervoViewModel>()`.

## Passo 6 — View: carregar no login e provar na tela

`lib/ui/view/home_page.dart`

No `initState`, **antes** do load que já existe, o reset síncrono (é ele que
impede a contagem da conta anterior de aparecer no primeiro frame):

```dart
@override
void initState() {
  super.initState();
  context.read<AcervoViewModel>().reset(); // sem notify: estamos no build
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    context.read<HomeViewModel>().load();
    context.read<AcervoViewModel>().load(); // AP-28: cada login começa limpo
  });
}
```

E no corpo, um bloco com três estados (carregando, erro com retry, contagem):

```dart
_AcervoResumo(acervo: context.watch<AcervoViewModel>()),
```

```dart
class _AcervoResumo extends StatelessWidget {
  const _AcervoResumo({required this.acervo});

  final AcervoViewModel acervo;

  @override
  Widget build(BuildContext context) {
    final Widget conteudo;
    if (acervo.isLoading) {
      conteudo = const Text('Carregando seu acervo...');
    } else if (acervo.error != null) {
      conteudo = Row(
        children: <Widget>[
          Expanded(child: Text(acervo.error!)),
          TextButton(onPressed: acervo.load, child: const Text('Tentar de novo')),
        ],
      );
    } else {
      final int total = acervo.total;
      conteudo = Text('Seu acervo: ${total == 1 ? '1 título' : '$total títulos'}');
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: <Widget>[
            const Icon(Icons.video_library_outlined, size: 18),
            const SizedBox(width: 8),
            Expanded(child: conteudo),
          ],
        ),
      ),
    );
  }
}
```

**Por que três ramos e não um `Text`**: o acervo é um **bloco** da tela, não a
tela. Se ele falhar, o health e o resto da home continuam na frente dela, e o
retry é só daquele bloco.

**Por que no `initState` e não no `create` do provider**: o provider roda uma vez só. A tela
é remontada a cada login, então é ela quem sabe que a sessão mudou.

**Erro comum**: disparar `load()` dentro do `build()` — recarrega a cada rebuild, entra em
loop com o `notifyListeners`.

## Passo 7 — testes

Dois arquivos, e nenhum toca a rede:

`test/data/repositories/acervo_repository_test.dart` — dublê do `RestClient`:

```dart
class _FakeRestClient implements RestClient {
  _FakeRestClient({this.itens, this.error});
  final List<AcervoItem>? itens;
  final Object? error;

  @override
  Future<List<AcervoItem>> acervo() async {
    if (error != null) throw error!;
    return itens!;
  }

  @override
  Future<HealthStatus> health() => throw UnimplementedError(); // interface exige
}
```

Casos mínimos: lista com itens → `Ok`; lista vazia → `Ok` com `[]`; `DioException` de
credencial → `UnauthorizedError`; corpo inválido → `ServerError`.

`test/ui/view_model/acervo_view_model_test.dart` — dublê do **contrato** `AcervoRepository`
(um que devolve `Result` fixo e outro que devolve respostas em sequência, para provar a
recarga). Casos mínimos: monta o mapa; `estadoDe(filme 550)` ≠ `estadoDe(série 550)`;
segunda carga não devolve o dado da primeira.

**Por que teste de repository e de ViewModel é obrigatório neste projeto**: são as camadas
onde o bug real mora (erro sem tradução, estado que não volta a zero), e o widget test não
pega isso. Widget test é bem-vindo, mas não bloqueia o PR.

```bash
flutter analyze && flutter test
```

## Passo 8 — verificação ao vivo e PR

```bash
flutter run -d chrome --web-port 8080
```

A porta **não é livre**: o backend libera só `http://localhost:8080` no CORS. Em outra porta
a tela mostra erro de rede, e parece bug do app.

Confira na tela:
- conta com acervo → "Seu acervo: N títulos" (ou "1 título") com o N que o backend tem
- conta sem acervo → `0`
- sair e entrar com outra conta → não pode mostrar o número da conta anterior nem por um frame

Depois: `git push -u origin feature/AP-28-acervo-na-nuvem` e abre o PR (`gh pr create`),
com 1 review de outra pessoa.

## Armadilhas (medidas neste repo)

- **`build_runner` esquecido** = erro de compilação confuso. Rode depois de mexer em DTO ou
  no `RestClient`, e commite o `.g.dart` junto.
- **crase no corpo do commit** dentro de aspas duplas vira *command substitution* no bash e
  corrompe o texto: mensagem longa vai por `git commit -F arquivo`.
- **arquivo sobrescrito em LF** num repo CRLF aparece inteiro modificado no diff: rode
  `git diff --numstat <arquivo>` e veja se as deleções são só as linhas que você trocou.
- **registrants de macos/windows/linux** aparecem modificados com diff vazio depois de
  `pub get`/`flutter test`: não são seus, não faça stage.
- **o token não vai em parâmetro**: o interceptor do `dio` põe `Authorization` em toda
  requisição e desloga em 401. Se você viu 401, o problema está na sessão, não no endpoint.

## Diário da implementação

Preenchido a cada commit (é a parte que o resto do time mais usa: o que deu errado de
verdade).

| commit | o que entrou | o que aprendi |
|---|---|---|
| `docs(acervo)` | spec + este guia + link no README | separar doc de código deixa o PR legível: quem revisa lê o plano antes |
| `feat(acervo): model` | `acervo_item.dart` + `.g.dart` | o `unknownEnumValue` do `json_serializable` resolve enum desconhecido sem `fromJson` na mão |
| `feat(acervo): endpoint` | método no `RestClient` + `.g.dart` | **membro novo no `RestClient` quebra TODOS os dublês dele**: o `_FakeRestClient` do teste de health parou de compilar e o `analyze` entregou a linha exata |
| `feat(acervo): repository` | contrato + impl + 4 testes | corpo em formato inesperado (`FormatException`) tem de virar `ServerError`, senão a tela fica presa |
| `feat(acervo): view model` | VM + 7 testes | **provei o teste por mutação**: removi o reset do `load()` e 2 testes falharam; restaurei e voltaram os 7 verdes. Teste que nunca falhou não é teste |
| `feat(acervo): carrega no login` | providers + `_AcervoResumo` + testes | mudar a View quebra os testes de quem MONTA a tela(`auth_gate`, `login_flow`): os três precisaram do provider novo |
| `docs(acervo): fecha` | este diário + o helper do mapa no guia | editar bloco de fecho por `patch` pode duplicar `}`: o `analyze` apontou na hora (`Expected to find ')'`) e o conserto foi no mesmo turno |
| `fix(acervo)` pós-review | reset no `initState`, `_isLoading` inicial, contador de geração e `estadoDe` sem tipo anulável | **o bloqueante do review foi real e o meu fix óbvio não fechava**: `_isLoading = true` de saída só cobre o PRIMEIRO login. Na segunda sessão o ViewModel já está com `isLoading=false` e os dados antigos, então o build 1 desenha o número velho. Quem fecha é zerar o estado **de forma síncrona no `initState`**. O teste que escrevi falhou antes do conserto e falha de novo se o `reset()` sai (provei por mutação) |
| `fix(acervo)`: testes | precedência com a fixture na ordem real, `fromJson`, conta vazia, erro + retry | o teste de precedência antigo passava com um laço único porque a linha ambígua vinha primeiro: **fixture na ordem errada esconde o bug que o teste existe para pegar** |
| 2ª rodada de review | `reset()` invalida requisição em voo, `estadoDe(desconhecido)` procura nos dois espaços, testes dos guards de geração, 4 valores de wire, `Key` no botão do retry | os dois guards do contador de geração e o ramo do tipo desconhecido podiam ser apagados sem nenhum teste ficar vermelho. Agora cada um derruba um teste quando é removido (provei por mutação). **Teste que morre por mutação é o único que conta** |
