import 'package:json_annotation/json_annotation.dart';

import 'tipo_midia.dart';

export 'tipo_midia.dart';

part 'titulo_detalhe.g.dart';

/// Full sheet of a title, as `GET /api/v1/titulos/:tmdbId?tipo=` returns it.
///
/// It is **not** an extension of [TmdbItem]: the catalogue item has no synopsis,
/// no rating and no genres, and the detail page cannot count on a field that the
/// list never sends. `nota` is nullable on purpose — the backend omits it when
/// the TMDB has no vote average.
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

  Map<String, dynamic> toJson() => _$TituloDetalheToJson(this);
}
