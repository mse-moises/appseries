import 'package:appseries/data/api_models/acervo_item.dart';
import 'package:appseries/data/api_models/marcar_acervo_request.dart';
import 'package:appseries/data/api_models/preferencias.dart';
import 'package:appseries/data/api_models/titulo_detalhe.dart';
import 'package:appseries/data/api_models/titulos_response.dart';
import 'package:appseries/data/services/rest_client.dart';

/// One dublê of [RestClient] for every repository test.
///
/// It lives here because the interface grows with the features: with one copy per
/// test file, adding an endpoint broke five files at once.
///
/// **Nothing comes back by accident.** Every response starts unset and the method
/// throws a clear message; an empty list that the server could really send must be
/// written on purpose (`respostaAcervo = const <AcervoItem>[]`). Without this, a
/// test that forgets to configure passes as if the server answered empty, and an
/// error-path test can pass for the wrong reason.
class FakeRestClient implements RestClient {
  FakeRestClient({this.error});

  /// When set, every method throws it instead of answering.
  final Object? error;

  List<AcervoItem>? respostaAcervo;
  TitulosResponse? respostaEmAlta;
  TitulosResponse? respostaPopulares;
  TitulosResponse? respostaBusca;
  TituloDetalhe? respostaTitulo;
  AcervoItem? respostaMarcar;
  Preferencias? respostaPreferencias;

  /// What `PUT /preferencias` echoes; by default it echoes the request body.
  Preferencias? respostaSalvar;

  // what the repository sent
  String? qRecebida;
  String? tipoRecebido;
  int? idRecebido;
  MarcarAcervoRequest? corpoRecebido;
  Preferencias? preferenciasEnviadas;
  String? removido;
  final List<String> chamadas = <String>[];

  T _exige<T>(T? valor, String campo) {
    if (valor == null) {
      throw StateError('configure $campo no FakeRestClient');
    }
    return valor;
  }

  void _talvezFalhe(String chamada) {
    chamadas.add(chamada);
    if (error != null) throw error!;
  }

  @override
  Future<List<AcervoItem>> acervo() async {
    _talvezFalhe('acervo');
    return _exige(respostaAcervo, 'respostaAcervo');
  }

  @override
  Future<TitulosResponse> emAlta() async {
    _talvezFalhe('emAlta');
    return _exige(respostaEmAlta, 'respostaEmAlta');
  }

  @override
  Future<TitulosResponse> populares() async {
    _talvezFalhe('populares');
    return _exige(respostaPopulares, 'respostaPopulares');
  }

  @override
  Future<TitulosResponse> busca(String q) async {
    qRecebida = q;
    _talvezFalhe('busca');
    return _exige(respostaBusca, 'respostaBusca');
  }

  @override
  Future<TituloDetalhe> titulo(int tmdbId, String tipo) async {
    idRecebido = tmdbId;
    tipoRecebido = tipo;
    _talvezFalhe('titulo');
    return _exige(respostaTitulo, 'respostaTitulo');
  }

  @override
  Future<AcervoItem> marcar(int tmdbId, MarcarAcervoRequest corpo) async {
    idRecebido = tmdbId;
    corpoRecebido = corpo;
    _talvezFalhe('marcar');
    return _exige(respostaMarcar, 'respostaMarcar');
  }

  @override
  Future<void> remover(int tmdbId, String tipo) async {
    _talvezFalhe('remover');
    removido = '$tipo:$tmdbId';
  }

  @override
  Future<Preferencias> preferencias() async {
    _talvezFalhe('preferencias');
    return _exige(respostaPreferencias, 'respostaPreferencias');
  }

  @override
  Future<Preferencias> salvarPreferencias(Preferencias corpo) async {
    preferenciasEnviadas = corpo;
    _talvezFalhe('salvarPreferencias');
    return respostaSalvar ?? corpo;
  }
}
