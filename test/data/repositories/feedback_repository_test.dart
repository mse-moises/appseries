import 'package:appseries/data/api_models/feedback_item.dart';
import 'package:appseries/data/repositories/feedback_repository_impl.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_rest_client.dart';

const FeedbackItem _dislike = FeedbackItem(
  tmdbId: 1399,
  sinal: SinalGosto.dislike,
  peso: 2,
  tipo: TipoMidia.tv,
);

DioException _erroHttp(int statusCode, Object corpo) => DioException.badResponse(
      statusCode: statusCode,
      requestOptions: RequestOptions(path: '/api/v1/feedback/1399'),
      response: Response<Object>(
        requestOptions: RequestOptions(path: '/api/v1/feedback/1399'),
        statusCode: statusCode,
        data: corpo,
      ),
    );

void main() {
  group('FeedbackRepositoryImpl', () {
    test('listar devolve os sinais', () async {
      final repo = FeedbackRepositoryImpl(FakeRestClient()
        ..respostaFeedback = const <FeedbackItem>[_dislike]);

      final result = await repo.listar();

      expect(result.valueOrNull?.single.sinal, SinalGosto.dislike);
    });

    test('marcar manda sinal, tipo e peso no corpo', () async {
      final FakeRestClient api = FakeRestClient()..respostaMarcarFeedback = _dislike;
      final repo = FeedbackRepositoryImpl(api);

      final result = await repo.marcar(TipoMidia.tv, 1399, SinalGosto.dislike, peso: 1);

      expect(result.valueOrNull?.sinal, SinalGosto.dislike);
      expect(api.idRecebido, 1399);
      expect(api.feedbackEnviado?.sinal, SinalGosto.dislike);
      expect(api.feedbackEnviado?.tipo, TipoMidia.tv);
      expect(api.feedbackEnviado?.peso, 1);
      expect(api.feedbackEnviado?.origem, OrigemFeedback.fechamento);
    });

    test('a origem escolhida chega ao corpo', () async {
      final FakeRestClient api = FakeRestClient()..respostaMarcarFeedback = _dislike;

      await FeedbackRepositoryImpl(api).marcar(
        TipoMidia.tv,
        1399,
        SinalGosto.dislike,
        origem: OrigemFeedback.abandono,
      );

      expect(api.feedbackEnviado?.origem, OrigemFeedback.abandono);
    });

    test('sem peso explícito, o corpo leva 2', () async {
      final FakeRestClient api = FakeRestClient()..respostaMarcarFeedback = _dislike;

      await FeedbackRepositoryImpl(api).marcar(TipoMidia.tv, 1399, SinalGosto.dislike);

      expect(api.feedbackEnviado?.peso, 2);
    });

    test('👍 com peso 1 continua sendo forte: o corpo não contradiz o contrato', () async {
      final FakeRestClient api = FakeRestClient()..respostaMarcarFeedback = _dislike;

      await FeedbackRepositoryImpl(api).marcar(TipoMidia.tv, 1399, SinalGosto.like, peso: 1);

      expect(api.feedbackEnviado?.peso, 2, reason: 'um 👍 é sempre 2');
    });

    test('origem desconhecida recusa antes da rede', () async {
      final FakeRestClient api = FakeRestClient();

      final result = await FeedbackRepositoryImpl(api).marcar(
        TipoMidia.tv,
        1399,
        SinalGosto.like,
        origem: OrigemFeedback.desconhecido,
      );

      expect(result.errorOrNull, isA<FeedbackIndisponivelError>());
      expect(api.chamadas, isEmpty);
    });

    test('peso fora de 1 ou 2 cai no forte, em vez de virar 400', () async {
      final FakeRestClient api = FakeRestClient()..respostaMarcarFeedback = _dislike;

      await FeedbackRepositoryImpl(api).marcar(TipoMidia.tv, 1399, SinalGosto.dislike, peso: 7);

      expect(api.feedbackEnviado?.peso, 2);
    });

    test('sinal desconhecido recusa antes da rede', () async {
      final FakeRestClient api = FakeRestClient();

      final result =
          await FeedbackRepositoryImpl(api).marcar(TipoMidia.tv, 1399, SinalGosto.desconhecido);

      expect(result.errorOrNull, isA<FeedbackIndisponivelError>());
      expect(api.chamadas, isEmpty);
    });

    test('tipo desconhecido recusa antes da rede, em marcar e remover', () async {
      final FakeRestClient api = FakeRestClient();
      final repo = FeedbackRepositoryImpl(api);

      final marcado = await repo.marcar(TipoMidia.desconhecido, 1399, SinalGosto.like);
      final removido = await repo.remover(TipoMidia.desconhecido, 1399);

      expect(marcado.errorOrNull, isA<FeedbackIndisponivelError>());
      expect(removido.errorOrNull, isA<FeedbackIndisponivelError>());
      expect(api.chamadas, isEmpty);
    });

    test('remover manda o tipo, para não apagar o sinal do outro tipo', () async {
      final FakeRestClient api = FakeRestClient();

      final result = await FeedbackRepositoryImpl(api).remover(TipoMidia.tv, 550);

      expect(result.isOk, isTrue);
      expect(api.removido, 'feedback:tv:550');
    });

    test('401 ao listar vira UnauthorizedError', () async {
      final repo = FeedbackRepositoryImpl(
        FakeRestClient(error: _erroHttp(401, <String, String>{'error': 'unauthorized'})),
      );

      final result = await repo.listar();

      expect(result.errorOrNull, isA<UnauthorizedError>());
    });

    test('queda de rede ao remover vira NetworkError', () async {
      final repo = FeedbackRepositoryImpl(FakeRestClient(
        error: DioException.connectionError(
          requestOptions: RequestOptions(path: '/api/v1/feedback/1399'),
          reason: 'sem rede',
        ),
      ));

      final result = await repo.remover(TipoMidia.tv, 1399);

      expect(result.errorOrNull, isA<NetworkError>());
    });

    test('remover sinal que já não existia vira NotFoundError (a tela decide)', () async {
      final repo = FeedbackRepositoryImpl(
        FakeRestClient(error: _erroHttp(404, <String, String>{'error': 'not_found'})),
      );

      final result = await repo.remover(TipoMidia.tv, 1399);

      expect(result.errorOrNull, isA<NotFoundError>());
    });

    test('400 invalid_sinal do backend vira FeedbackIndisponivelError', () async {
      final repo = FeedbackRepositoryImpl(
        FakeRestClient(error: _erroHttp(400, <String, String>{'error': 'invalid_sinal'})),
      );

      final result = await repo.marcar(TipoMidia.tv, 1399, SinalGosto.like);

      expect(result.errorOrNull, isA<FeedbackIndisponivelError>());
    });
  });
}
