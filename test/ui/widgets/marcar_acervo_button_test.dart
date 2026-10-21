import 'package:appseries/data/api_models/acervo_item.dart';
import 'package:appseries/data/api_models/feedback_item.dart';
import 'package:appseries/data/repositories/acervo_repository.dart';
import 'package:appseries/data/repositories/feedback_repository.dart';
import 'package:appseries/ui/view_model/acervo_view_model.dart';
import 'package:appseries/ui/view_model/marcar_acervo_view_model.dart';
import 'package:appseries/ui/widgets/marcar_acervo_button.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:appseries/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeAcervoRepository implements AcervoRepository {
  _FakeAcervoRepository({this.resposta});

  Result<AcervoItem>? resposta;
  EstadoAcervo? estadoRecebido;
  int chamadas = 0;

  @override
  Future<Result<AcervoItem>> marcar(TipoMidia tipo, int tmdbId, EstadoAcervo estado) async {
    chamadas++;
    estadoRecebido = estado;
    return resposta!;
  }

  @override
  Future<Result<List<AcervoItem>>> listar() async =>
      const Result<List<AcervoItem>>.ok(<AcervoItem>[]);

  @override
  Future<Result<void>> remover(TipoMidia tipo, int tmdbId) => throw UnimplementedError();
}

class _FakeFeedbackRepository implements FeedbackRepository {
  _FakeFeedbackRepository({this.resposta});

  Result<FeedbackItem>? resposta;
  int? pesoRecebido;
  OrigemFeedback? origemRecebida;
  int chamadas = 0;

  @override
  Future<Result<FeedbackItem>> marcar(
    TipoMidia tipo,
    int tmdbId,
    SinalGosto sinal, {
    int peso = 2,
    OrigemFeedback origem = OrigemFeedback.fechamento,
  }) async {
    chamadas++;
    pesoRecebido = peso;
    origemRecebida = origem;
    return resposta!;
  }

  @override
  Future<Result<List<FeedbackItem>>> listar() async =>
      const Result<List<FeedbackItem>>.ok(<FeedbackItem>[]);

  @override
  Future<Result<void>> remover(TipoMidia tipo, int tmdbId) => throw UnimplementedError();
}

void main() {
  late _FakeAcervoRepository acervo;
  late _FakeFeedbackRepository feedback;

  setUp(() {
    acervo = _FakeAcervoRepository(
      resposta: const Result<AcervoItem>.ok(
        AcervoItem(tmdbId: 550, estado: EstadoAcervo.dropped, tipo: TipoMidia.movie),
      ),
    );
    feedback = _FakeFeedbackRepository(
      resposta: const Result<FeedbackItem>.ok(
        FeedbackItem(
          tmdbId: 550,
          sinal: SinalGosto.dislike,
          origem: OrigemFeedback.abandono,
          tipo: TipoMidia.movie,
        ),
      ),
    );
  });

  Future<void> montar(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AcervoViewModel>(
            create: (_) => AcervoViewModel(acervo),
          ),
          ChangeNotifierProvider<MarcarAcervoViewModel>(
            create: (_) => MarcarAcervoViewModel(acervo: acervo, feedback: feedback),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: Center(child: MarcarAcervoButton(tipo: TipoMidia.movie, tmdbId: 550))),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> escolherNoMenu(WidgetTester tester, String rotulo) async {
    await tester.tap(find.text('Marcar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(rotulo));
    await tester.pumpAndSettle();
  }

  group('MarcarAcervoButton', () {
    testWidgets('estado que não é abandono salva e não pede motivo', (tester) async {
      acervo.resposta = const Result<AcervoItem>.ok(
        AcervoItem(tmdbId: 550, estado: EstadoAcervo.watched, tipo: TipoMidia.movie),
      );
      await montar(tester);

      await escolherNoMenu(tester, 'Assistido');

      expect(acervo.estadoRecebido, EstadoAcervo.watched);
      expect(find.text('Por que você abandonou?'), findsNothing,
          reason: 'só o abandono pergunta motivo');
      expect(feedback.chamadas, 0);
    });

    testWidgets('abandono: os chips aparecem e o motivo vira peso 2', (tester) async {
      await montar(tester);

      await escolherNoMenu(tester, 'Abandonei');
      expect(find.text('Por que você abandonou?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('motivo-naoGostei')));
      await tester.pumpAndSettle();

      expect(acervo.estadoRecebido, EstadoAcervo.dropped);
      expect(feedback.pesoRecebido, 2);
      expect(feedback.origemRecebida, OrigemFeedback.abandono);
    });

    testWidgets('"Agora não" mantém o abandono e não grava gosto', (tester) async {
      await montar(tester);

      await escolherNoMenu(tester, 'Abandonei');
      await tester.tap(find.byKey(const Key('motivo-agora-nao')));
      await tester.pumpAndSettle();

      expect(acervo.estadoRecebido, EstadoAcervo.dropped,
          reason: 'o toque em "Abandonei" já salva, com ou sem motivo');
      expect(feedback.chamadas, 0);
    });

    testWidgets('falha ao salvar mostra a frase do erro na tela', (tester) async {
      acervo.resposta = const Result<AcervoItem>.error(NetworkError());
      await montar(tester);

      await escolherNoMenu(tester, 'Abandonei');
      await tester.tap(find.byKey(const Key('motivo-agora-nao')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(const NetworkError().mensagem), findsOneWidget);
      expect(feedback.chamadas, 0, reason: 'sem abandono salvo não há motivo');
    });
  });
}
