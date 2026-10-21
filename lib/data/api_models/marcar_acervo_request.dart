import 'package:json_annotation/json_annotation.dart';

import 'acervo_item.dart';

part 'marcar_acervo_request.g.dart';

/// Body of `PUT /api/v1/acervo/:tmdbId`.
///
/// `tipo` is **obligatory** on the wire: the key of a shelf line is
/// `(user, tipo, tmdbId)`, and the backend answers `400 invalid_tipo` when it is
/// missing. Never send [EstadoAcervo.desconhecido] — it is only a decode
/// fallback, not a state the user can choose.
@JsonSerializable()
class MarcarAcervoRequest {
  const MarcarAcervoRequest({required this.estado, required this.tipo});

  factory MarcarAcervoRequest.fromJson(Map<String, dynamic> json) =>
      _$MarcarAcervoRequestFromJson(json);

  final EstadoAcervo estado;
  final TipoMidia tipo;

  Map<String, dynamic> toJson() => _$MarcarAcervoRequestToJson(this);
}
