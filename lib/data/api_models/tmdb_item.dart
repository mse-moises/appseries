import 'package:json_annotation/json_annotation.dart';

import 'tipo_midia.dart';

export 'tipo_midia.dart';

part 'tmdb_item.g.dart';

/// One title of the catalogue, as `/em-alta` and `/populares` return it.
///
/// Two details that cost time if you assume them from the shelf:
/// here the id is called `id` (not `tmdbId`), and `ano` is a **string**.
/// `posterPath` is null when the TMDB has no poster — the card falls back to a
/// grey box, it never throws.
@JsonSerializable()
class TmdbItem {
  const TmdbItem({
    required this.id,
    required this.tipo,
    required this.titulo,
    this.ano,
    this.posterPath,
  });

  factory TmdbItem.fromJson(Map<String, dynamic> json) => _$TmdbItemFromJson(json);

  final int id;

  @JsonKey(unknownEnumValue: TipoMidia.desconhecido)
  final TipoMidia tipo;

  final String titulo;
  final String? ano;
  final String? posterPath;

  Map<String, dynamic> toJson() => _$TmdbItemToJson(this);
}
