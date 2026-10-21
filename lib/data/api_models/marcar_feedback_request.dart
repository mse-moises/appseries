import 'package:json_annotation/json_annotation.dart';

import 'feedback_item.dart';

part 'marcar_feedback_request.g.dart';

/// Body de `PUT /api/v1/feedback/:tmdbId`.
///
/// `sinal` e `tipo` são obrigatórios (o servidor responde `400 invalid_sinal` /
/// `400 invalid_tipo`); `peso` só produz efeito no 👎 — um 👍 é sempre 2.
@JsonSerializable()
class MarcarFeedbackRequest {
  const MarcarFeedbackRequest({
    required this.sinal,
    required this.tipo,
    this.peso = 2,
    this.origem = OrigemFeedback.fechamento,
  });

  factory MarcarFeedbackRequest.fromJson(Map<String, dynamic> json) =>
      _$MarcarFeedbackRequestFromJson(json);

  final SinalGosto sinal;
  final TipoMidia tipo;
  final int peso;
  final OrigemFeedback origem;

  Map<String, dynamic> toJson() => _$MarcarFeedbackRequestToJson(this);
}
