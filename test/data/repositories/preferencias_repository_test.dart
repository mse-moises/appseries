import 'package:appseries/data/api_models/preferencias.dart';
import 'package:appseries/data/repositories/preferencias_repository_impl.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_rest_client.dart';

void main() {
  group('PreferenciasRepositoryImpl', () {
    test('ler devolve o momento e os gêneros salvos', () async {
      final FakeRestClient api = FakeRestClient()
        ..respostaPreferencias = const Preferencias(
          momento: 'maratonar no fim de semana',
          generos: <String>['Drama'],
        );

      final result = await PreferenciasRepositoryImpl(api).ler();

      expect(result.valueOrNull?.momento, 'maratonar no fim de semana');
      expect(result.valueOrNull?.generos, <String>['Drama']);
    });

    test('salvar manda o corpo inteiro e devolve o que o servidor ecoou', () async {
      // eco diferente do que foi enviado: sem isso, "devolver o corpo local"
      // passaria como se o servidor tivesse respondido
      final FakeRestClient api = FakeRestClient()
        ..respostaSalvar = const Preferencias(momento: 'domingo', generos: <String>['Drama']);
      const Preferencias corpo = Preferencias(momento: 'domingo ', generos: <String>['Drama']);

      final result = await PreferenciasRepositoryImpl(api).salvar(corpo);

      expect(api.preferenciasEnviadas?.momento, 'domingo ', reason: 'o repositório não normaliza');
      expect(result.valueOrNull?.momento, 'domingo', reason: 'a tela mostra o que voltou do servidor');
    });

    test('falha de rede vira NetworkError, não exceção', () async {
      final FakeRestClient api = FakeRestClient(
        error: DioException.connectionError(
          requestOptions: RequestOptions(path: '/api/v1/preferencias'),
          reason: 'sem rede',
        ),
      );

      final result = await PreferenciasRepositoryImpl(api).salvar(const Preferencias());

      expect(result.errorOrNull, isA<NetworkError>());
    });

    test('corpo fora do contrato não escapa como exceção', () async {
      final FakeRestClient api = FakeRestClient(error: StateError('json quebrado'));

      final result = await PreferenciasRepositoryImpl(api).ler();

      expect(result.errorOrNull, isA<ServerError>());
    });
  });
}
