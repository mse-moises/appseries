import 'package:json_annotation/json_annotation.dart';

import 'tipo_midia.dart';

export 'tipo_midia.dart';

part 'titulo_detalhe.g.dart';

/// Full sheet of a title, as `GET /api/v1/titulos/:tmdbId?tipo=` returns it.
///
/// It is **not** an extension of [TmdbItem]: the catalogue item has no synopsis,
/// no rating and no genres, and the detail page cannot count on a field that the
/// list never sends.
///
/// `nota` chega **sempre**, como número: o backend manda `0` quando o TMDB não
/// tem avaliação (não omite o campo). Por isso existe [notaExibivel] — a tela
/// não deve mostrar "0.0" como se fosse nota ruim.
@JsonSerializable()
class TituloDetalhe {
  const TituloDetalhe({
    required this.id,
    required this.tipo,
    required this.titulo,
    this.ano,
    this.posterPath,
    this.sinopse,
    this.nota,
    this.generos = const <String>[],
  });

  factory TituloDetalhe.fromJson(Map<String, dynamic> json) => _$TituloDetalheFromJson(json);

  final int id;

  @JsonKey(unknownEnumValue: TipoMidia.desconhecido)
  final TipoMidia tipo;

  final String titulo;
  final String? ano;
  final String? posterPath;
  final String? sinopse;

  /// The backend can send `8` or `8.4`; both have to decode.
  final double? nota;

  final List<String> generos;

  /// `null` quando não há avaliação (o backend manda `0`), para a tela escolher
  /// entre mostrar a nota e não mostrar nada.
  double? get notaExibivel => (nota == null || nota == 0) ? null : nota;

  Map<String, dynamic> toJson() => _$TituloDetalheToJson(this);
}
