import 'package:appseries/data/api_models/acervo_item.dart';
import 'package:appseries/data/api_models/feedback_item.dart';
import 'package:appseries/data/api_models/marcar_feedback_request.dart';
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

  /// What `PUT /preferencias` echoes. Configure it even when it equals the body:
  /// echoing the body by default would hide a server that answers something else.
  Preferencias? respostaSalvar;
  List<FeedbackItem>? respostaFeedback;
  FeedbackItem? respostaMarcarFeedback;

  // what the repository sent
  String? qRecebida;
  String? tipoRecebido;
  int? idRecebido;
  MarcarAcervoRequest? corpoRecebido;
  Preferencias? preferenciasEnviadas;
  MarcarFeedbackRequest? feedbackEnviado;
  String? removido;
  final List<String> chamadas = <String>[];

  /// Aviso: o `StateError` é `Error`, e os repositórios têm `catch (_)` — se um
  /// teste esquecer de configurar, o repositório converte isto em `ServerError`.
  /// Teste de caminho de erro deve passar `error:`, não depender do esquecimento.
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
    return _exige(respostaSalvar, 'respostaSalvar');
  }

  @override
  Future<List<FeedbackItem>> feedback() async {
    _talvezFalhe('feedback');
    return _exige(respostaFeedback, 'respostaFeedback');
  }

  @override
  Future<FeedbackItem> marcarFeedback(int tmdbId, MarcarFeedbackRequest corpo) async {
    idRecebido = tmdbId;
    feedbackEnviado = corpo;
    _talvezFalhe('marcarFeedback');
    return _exige(respostaMarcarFeedback, 'respostaMarcarFeedback');
  }

  @override
  Future<void> removerFeedback(int tmdbId, String tipo) async {
    _talvezFalhe('removerFeedback');
    removido = 'feedback:$tipo:$tmdbId';
  }
}
