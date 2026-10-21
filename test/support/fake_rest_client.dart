import 'package:appseries/data/api_models/acervo_item.dart';
import 'package:appseries/data/api_models/marcar_acervo_request.dart';
import 'package:appseries/data/api_models/preferencias.dart';
import 'package:appseries/data/api_models/titulo_detalhe.dart';
import 'package:appseries/data/api_models/titulos_response.dart';
import 'package:appseries/data/api_models/tmdb_item.dart';
import 'package:appseries/data/services/rest_client.dart';

/// One dublê of [RestClient] for every repository test.
///
/// It lives here because the interface grows with the features: with one copy per
/// test file, adding an endpoint broke five files at once (it happened when the
/// detail/search endpoints were added). Fill only the response the test needs and
/// read back what the repository sent (`qRecebida`, `corpoRecebido`, ...).
class FakeRestClient implements RestClient {
  FakeRestClient({this.error});

  /// When set, every method throws it instead of answering.
  final Object? error;

  List<AcervoItem> respostaAcervo = const <AcervoItem>[];
  TitulosResponse respostaEmAlta = const TitulosResponse(resultados: <TmdbItem>[]);
  TitulosResponse respostaPopulares = const TitulosResponse(resultados: <TmdbItem>[]);
  TitulosResponse respostaBusca = const TitulosResponse(resultados: <TmdbItem>[]);
  TituloDetalhe? respostaTitulo;
  AcervoItem? respostaMarcar;
  Preferencias respostaPreferencias = const Preferencias();

  // what the repository sent
  String? qRecebida;
  String? tipoRecebido;
  int? idRecebido;
  MarcarAcervoRequest? corpoRecebido;
  Preferencias? preferenciasEnviadas;
  String? removido;

  @override
  Future<List<AcervoItem>> acervo() async {
    if (error != null) throw error!;
    return respostaAcervo;
  }

  @override
  Future<TitulosResponse> emAlta() async {
    if (error != null) throw error!;
    return respostaEmAlta;
  }

  @override
  Future<TitulosResponse> populares() async {
    if (error != null) throw error!;
    return respostaPopulares;
  }

  @override
  Future<TitulosResponse> busca(String q) async {
    qRecebida = q;
    if (error != null) throw error!;
    return respostaBusca;
  }

  @override
  Future<TituloDetalhe> titulo(int tmdbId, String tipo) async {
    idRecebido = tmdbId;
    tipoRecebido = tipo;
    if (error != null) throw error!;
    return respostaTitulo!;
  }

  @override
  Future<AcervoItem> marcar(int tmdbId, MarcarAcervoRequest corpo) async {
    idRecebido = tmdbId;
    corpoRecebido = corpo;
    if (error != null) throw error!;
    return respostaMarcar!;
  }

  @override
  Future<void> remover(int tmdbId, String tipo) async {
    if (error != null) throw error!;
    removido = '$tipo:$tmdbId';
  }

  @override
  Future<Preferencias> preferencias() async {
    if (error != null) throw error!;
    return respostaPreferencias;
  }

  @override
  Future<Preferencias> salvarPreferencias(Preferencias corpo) async {
    preferenciasEnviadas = corpo;
    if (error != null) throw error!;
    return corpo;
  }
}
