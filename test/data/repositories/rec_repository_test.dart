import 'package:appseries/data/api_models/carta_rec.dart';
import 'package:appseries/data/repositories/rec_repository_impl.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_rest_client.dart';

void main() {
  group('RecRepositoryImpl', () {
    const RecResult resposta = RecResult(
      cartas: <CartaRec>[
        CartaRec(
          tmdbId: 1399,
          tipo: TipoMidia.tv,
          titulo: 'Game of Thrones',
          ano: '2011',
          justificativa: 'Combina com o seu momento',
        ),
      ],
      origem: OrigemRec.llm,
    );

    test('manda o momento sem os espaços das pontas', () async {
      final FakeRestClient api = FakeRestClient()..respostaRec = resposta;

      final result = await RecRepositoryImpl(api).recomendar(momento: '  algo leve  ');

      expect(api.corpoRecEnviado, <String, dynamic>{'momento': 'algo leve'});
      expect(result.valueOrNull?.cartas.single.titulo, 'Game of Thrones');
    });

    test('campo em branco manda corpo vazio (o servidor usa o momento salvo)', () async {
      final FakeRestClient api = FakeRestClient()..respostaRec = resposta;

      await RecRepositoryImpl(api).recomendar(momento: '   ');

      expect(api.corpoRecEnviado, isEmpty,
          reason: 'corpo vazio = "usa o que está salvo"; nunca vai sem chamar a API');
      expect(api.recChamadas, 1);
    });

    test('sem momento também chama a API com corpo vazio', () async {
      final FakeRestClient api = FakeRestClient()..respostaRec = resposta;

      await RecRepositoryImpl(api).recomendar();

      expect(api.corpoRecEnviado, isEmpty);
    });

    test('429 rec_limit vira RateLimitError, não ServerError', () async {
      final RequestOptions opcoes = RequestOptions(path: '/api/v1/rec');
      final FakeRestClient api = FakeRestClient(
        error: DioException(
          requestOptions: opcoes,
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: opcoes,
            statusCode: 429,
            data: <String, dynamic>{'error': 'rec_limit', 'limite': 20},
          ),
        ),
      );

      final result = await RecRepositoryImpl(api).recomendar(momento: 'terror');

      expect(result.errorOrNull, isA<RateLimitError>());
    });

    test('503 rec_unconfigured não manda a pessoa entrar de novo', () async {
      final RequestOptions opcoes = RequestOptions(path: '/api/v1/rec');
      final FakeRestClient api = FakeRestClient(
        error: DioException(
          requestOptions: opcoes,
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: opcoes,
            statusCode: 503,
            data: <String, dynamic>{'error': 'rec_unconfigured'},
          ),
        ),
      );

      final result = await RecRepositoryImpl(api).recomendar();

      expect(result.errorOrNull, isA<ServerError>());
    });

    test('falha de rede vira NetworkError, não exceção', () async {
      final FakeRestClient api = FakeRestClient(
        error: DioException.connectionError(
          requestOptions: RequestOptions(path: '/api/v1/rec'),
          reason: 'sem rede',
        ),
      );

      final result = await RecRepositoryImpl(api).recomendar(momento: 'domingo');

      expect(result.errorOrNull, isA<NetworkError>());
    });

    test('corpo fora do contrato não escapa como exceção', () async {
      final FakeRestClient api = FakeRestClient(error: StateError('json quebrado'));

      final result = await RecRepositoryImpl(api).recomendar();

      expect(result.errorOrNull, isA<ServerError>());
    });
  });
}
