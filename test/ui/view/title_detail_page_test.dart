import 'package:appseries/data/api_models/acervo_item.dart';
import 'package:appseries/data/api_models/feedback_item.dart';
import 'package:appseries/data/api_models/titulo_detalhe.dart';
import 'package:appseries/data/api_models/tmdb_item.dart';
import 'package:appseries/data/repositories/acervo_repository.dart';
import 'package:appseries/data/repositories/feedback_repository.dart';
import 'package:appseries/data/repositories/titulo_repository.dart';
import 'package:appseries/ui/navegacao/titulo_ref.dart';
import 'package:appseries/ui/view/title_detail_page.dart';
import 'package:appseries/ui/view_model/acervo_view_model.dart';
import 'package:appseries/ui/view_model/title_detail_view_model.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:appseries/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Responde uma ficha por chamada, na ordem: é como se prova o retry.
class _FakeTitulos implements TituloRepository {
  _FakeTitulos(this.respostas);

  final List<Result<TituloDetalhe>> respostas;
  int chamadas = 0;

  @override
  Future<Result<TituloDetalhe>> titulo(TipoMidia tipo, int tmdbId) async =>
      respostas[(chamadas++).clamp(0, respostas.length - 1)];

  @override
  Future<Result<List<TmdbItem>>> buscar(String q) => throw UnimplementedError();

  @override
  Future<Result<List<TmdbItem>>> emAlta() => throw UnimplementedError();

  @override
  Future<Result<List<TmdbItem>>> populares() => throw UnimplementedError();
}

class _FakeAcervo implements AcervoRepository {
  _FakeAcervo([this.itens = const <AcervoItem>[]]);

  final List<AcervoItem> itens;

  @override
  Future<Result<List<AcervoItem>>> listar() async => Result<List<AcervoItem>>.ok(itens);

  @override
  Future<Result<AcervoItem>> marcar(TipoMidia tipo, int tmdbId, EstadoAcervo estado) async =>
      Result<AcervoItem>.ok(AcervoItem(tmdbId: tmdbId, estado: estado, tipo: tipo));

  @override
  Future<Result<void>> remover(TipoMidia tipo, int tmdbId) async => const Result<void>.ok(null);
}

class _FakeFeedback implements FeedbackRepository {
  final List<String> gravados = <String>[];

  @override
  Future<Result<List<FeedbackItem>>> listar() async =>
      const Result<List<FeedbackItem>>.ok(<FeedbackItem>[]);

  @override
  Future<Result<FeedbackItem>> marcar(
    TipoMidia tipo,
    int tmdbId,
    SinalGosto sinal, {
    int peso = 2,
    OrigemFeedback origem = OrigemFeedback.fechamento,
  }) async {
    gravados.add('${sinal.name} ${origem.name}');
    return Result<FeedbackItem>.ok(FeedbackItem(tmdbId: tmdbId, sinal: sinal, tipo: tipo));
  }

  @override
  Future<Result<void>> remover(TipoMidia tipo, int tmdbId) async => const Result<void>.ok(null);
}

const TituloDetalhe _ficha = TituloDetalhe(
  id: 1399,
  tipo: TipoMidia.tv,
  titulo: 'Game of Thrones',
  ano: '2011',
  sinopse: 'Nove famílias nobres lutam pelo controle de Westeros.',
  nota: 8.4,
  generos: <String>['Drama', 'Fantasia'],
);

/// Abre o detalhe pela rota, como o app faz, com os ViewModels na raiz.
Future<_FakeFeedback> _abrir(
  WidgetTester tester,
  List<Result<TituloDetalhe>> respostas, {
  List<AcervoItem> acervo = const <AcervoItem>[],
  double largura = 1200,
}) async {
  final _FakeFeedback feedback = _FakeFeedback();
  final AcervoViewModel acervoVm = AcervoViewModel(_FakeAcervo(acervo));
  await acervoVm.load();
  tester.view.physicalSize = Size(largura, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AcervoViewModel>.value(value: acervoVm),
        ChangeNotifierProvider<TitleDetailViewModel>(
          create: (_) => TitleDetailViewModel(_FakeTitulos(respostas), feedback),
        ),
      ],
      child: MaterialApp(
        onGenerateRoute: (RouteSettings s) => MaterialPageRoute<void>(
          settings: const RouteSettings(arguments: TituloRef(tipo: TipoMidia.tv, id: 1399)),
          builder: (_) => const TitleDetailPage(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return feedback;
}

void main() {
  group('TitleDetailPage', () {
    testWidgets('mostra título, ano, tipo, nota, gêneros, sinopse e o botão do acervo',
        (tester) async {
      await _abrir(tester, const <Result<TituloDetalhe>>[Result<TituloDetalhe>.ok(_ficha)]);

      expect(find.text('Game of Thrones'), findsWidgets);
      expect(find.text('2011 · Série'), findsOneWidget);
      expect(find.text('8.4'), findsOneWidget);
      expect(find.text('Drama'), findsOneWidget);
      expect(find.text('Fantasia'), findsOneWidget);
      expect(find.text('Nove famílias nobres lutam pelo controle de Westeros.'), findsOneWidget);
      expect(find.text('Quero ver'), findsOneWidget);
      expect(find.textContaining('TMDB API'), findsOneWidget);
    });

    testWidgets('nota 0 e ano vazio não viram "0.0" nem rótulo vazio', (tester) async {
      await _abrir(tester, const <Result<TituloDetalhe>>[
        Result<TituloDetalhe>.ok(
          TituloDetalhe(id: 1399, tipo: TipoMidia.tv, titulo: 'Sem dados', ano: '', nota: 0),
        ),
      ]);

      expect(find.text('0.0'), findsNothing);
      expect(find.byIcon(Icons.star), findsNothing);
      expect(find.text('Série'), findsOneWidget, reason: 'sem ano, sobra só o tipo, sem " · "');
      expect(find.text('Sem sinopse disponível.'), findsOneWidget);
    });

    testWidgets('sinopse longa corta em 6 linhas com "Ler mais"', (tester) async {
      await _abrir(tester, <Result<TituloDetalhe>>[
        Result<TituloDetalhe>.ok(TituloDetalhe(
          id: 1399,
          tipo: TipoMidia.tv,
          titulo: 'Longa',
          sinopse: List<String>.filled(80, 'palavra comprida').join(' '),
        )),
      ]);

      expect(find.text('Ler mais'), findsOneWidget);
      await tester.tap(find.text('Ler mais'));
      await tester.pump();
      expect(find.text('Ler menos'), findsOneWidget);
    });

    testWidgets('a sinopse fechada mostra no máximo 6 linhas', (tester) async {
      await _abrir(tester, <Result<TituloDetalhe>>[
        Result<TituloDetalhe>.ok(TituloDetalhe(
          id: 1399,
          tipo: TipoMidia.tv,
          titulo: 'Longa',
          sinopse: List<String>.filled(80, 'palavra comprida').join(' '),
        )),
      ]);

      final Text sinopse = tester.widget<Text>(find.textContaining('palavra comprida'));
      expect(sinopse.maxLines, 6);
    });

    testWidgets('sinopse curta não mostra "Ler mais"', (tester) async {
      await _abrir(tester, const <Result<TituloDetalhe>>[Result<TituloDetalhe>.ok(_ficha)]);

      expect(find.text('Ler mais'), findsNothing);
    });

    testWidgets('👍/👎 só aparece depois de assistido ou abandonado', (tester) async {
      await _abrir(tester, const <Result<TituloDetalhe>>[Result<TituloDetalhe>.ok(_ficha)]);
      expect(find.text('👍 Curti'), findsNothing);

      await tester.tap(find.byTooltip('Outros estados'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Assistido').last);
      await tester.pumpAndSettle();

      expect(find.text('👍 Curti'), findsOneWidget);
      expect(find.text('👎 Não curti'), findsOneWidget);
    });

    for (final EstadoAcervo estado in const <EstadoAcervo>[
      EstadoAcervo.planToWatch,
      EstadoAcervo.watching,
    ]) {
      testWidgets('em "${estado.name}" ainda não há 👍/👎', (tester) async {
        await _abrir(
          tester,
          const <Result<TituloDetalhe>>[Result<TituloDetalhe>.ok(_ficha)],
          acervo: <AcervoItem>[AcervoItem(tmdbId: 1399, estado: estado, tipo: TipoMidia.tv)],
        );

        expect(find.text('👍 Curti'), findsNothing);
      });
    }

    testWidgets('em tela estreita com fonte grande a ficha não estoura', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _abrir(
        tester,
        const <Result<TituloDetalhe>>[Result<TituloDetalhe>.ok(_ficha)],
        largura: 320,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('2011 · Série'), findsOneWidget);
    });

    testWidgets('"não curti" num abandonado grava com origem abandono', (tester) async {
      final _FakeFeedback feedback = await _abrir(
        tester,
        const <Result<TituloDetalhe>>[Result<TituloDetalhe>.ok(_ficha)],
        acervo: const <AcervoItem>[
          AcervoItem(tmdbId: 1399, estado: EstadoAcervo.dropped, tipo: TipoMidia.tv),
        ],
      );

      await tester.tap(find.text('👎 Não curti'));
      await tester.pumpAndSettle();

      expect(feedback.gravados, <String>['dislike abandono']);
    });

    testWidgets('catálogo fora do ar: frase clara e o retry funciona (AP-79)', (tester) async {
      await _abrir(tester, const <Result<TituloDetalhe>>[
        Result<TituloDetalhe>.error(CatalogoIndisponivelError()),
        Result<TituloDetalhe>.ok(_ficha),
      ]);

      expect(find.text(const CatalogoIndisponivelError().mensagem), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing, reason: 'não fica girando');

      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();

      expect(find.text('2011 · Série'), findsOneWidget);
    });
  });
}
