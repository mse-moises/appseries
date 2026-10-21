import 'package:json_annotation/json_annotation.dart';

/// `movie` or `tv` — the TMDB numbers each one in its own space, so the same id
/// can be two different titles.
///
/// Lives in its own file because it is shared by the shelf (`AcervoItem`) and by
/// the catalogue (`TmdbItem`): two copies of this enum would drift.
enum TipoMidia {
  @JsonValue('movie')
  movie,
  @JsonValue('tv')
  tv,

  /// A value this app version does not know (server newer than the app).
  @JsonValue('desconhecido')
  desconhecido,
}
