import 'package:json_annotation/json_annotation.dart';

import 'tmdb_item.dart';

part 'titulos_response.g.dart';

/// Answer of `/em-alta` and `/populares`: the array comes inside `resultados`.
///
/// The wrapper is why the endpoint cannot return `List<TmdbItem>` directly.
@JsonSerializable()
class TitulosResponse {
  const TitulosResponse({required this.resultados});

  factory TitulosResponse.fromJson(Map<String, dynamic> json) => _$TitulosResponseFromJson(json);

  final List<TmdbItem> resultados;

  Map<String, dynamic> toJson() => _$TitulosResponseToJson(this);
}
