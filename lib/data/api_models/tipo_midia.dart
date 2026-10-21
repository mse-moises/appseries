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

/// O valor que viaja na rede (`movie`/`tv`), ou `null` quando o tipo é
/// [TipoMidia.desconhecido].
///
/// Existe porque `TipoMidia.name` é uma armadilha: `desconhecido` também tem
/// nome, e mandá-lo ao backend responde `400 invalid_tipo`. Quem traduz usa
/// este ponto e recusa antes da rede.
String? tipoWire(TipoMidia tipo) => switch (tipo) {
      TipoMidia.movie => 'movie',
      TipoMidia.tv => 'tv',
      TipoMidia.desconhecido => null,
    };

/// Chave de um título: `tipo:id`.
///
/// O id do TMDB não é único entre filme e série (`550` é *Clube da Luta* e
/// também uma série), então toda comparação de título usa este par.
String chaveTitulo(TipoMidia tipo, int tmdbId) => '${tipo.name}:$tmdbId';
