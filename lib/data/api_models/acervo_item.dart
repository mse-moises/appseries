import 'package:json_annotation/json_annotation.dart';

part 'acervo_item.g.dart';

/// The four states a title can have on the user's shelf.
///
/// `desconhecido` exists so a value this app version does not know (server
/// newer than the app) is decoded instead of blowing up the whole list.
enum EstadoAcervo {
  @JsonValue('plan_to_watch')
  planToWatch,
  @JsonValue('watching')
  watching,
  @JsonValue('watched')
  watched,
  @JsonValue('dropped')
  dropped,
  @JsonValue('desconhecido')
  desconhecido,
}

/// `movie` or `tv` — the TMDB numbers each one in its own space.
enum TipoMidia {
  @JsonValue('movie')
  movie,
  @JsonValue('tv')
  tv,
  @JsonValue('desconhecido')
  desconhecido,
}

/// Key of a shelf line.
///
/// The id alone is not enough: `550` is *Fight Club* (movie) **and**
/// *Till Death Us Do Part* (series), so a map keyed only by the TMDB id would
/// answer the wrong state for one of them. The same pair is the primary key on
/// the backend since migration 008.
String chaveEstado(TipoMidia? tipo, int tmdbId) => '${tipo?.name ?? '-'}:$tmdbId';

/// One line of `GET /api/v1/acervo`.
///
/// `titulo`, `ano` and `posterPath` are nullable on purpose: the backend writes
/// only the state when the TMDB lookup fails, and keeps that line forever.
@JsonSerializable()
class AcervoItem {
  const AcervoItem({
    required this.tmdbId,
    required this.estado,
    this.tipo,
    this.titulo,
    this.ano,
    this.posterPath,
    this.atualizadoEm,
  });

  factory AcervoItem.fromJson(Map<String, dynamic> json) => _$AcervoItemFromJson(json);

  final int tmdbId;

  @JsonKey(unknownEnumValue: EstadoAcervo.desconhecido)
  final EstadoAcervo estado;

  @JsonKey(unknownEnumValue: TipoMidia.desconhecido)
  final TipoMidia? tipo;

  final String? titulo;

  /// Keeps the API type: the backend sends `"2011"`, not `2011` (a series range
  /// like `"2011–2019"` would not fit a number).
  final String? ano;

  final String? posterPath;
  final DateTime? atualizadoEm;

  Map<String, dynamic> toJson() => _$AcervoItemToJson(this);

  String get chave => chaveEstado(tipo, tmdbId);
}
