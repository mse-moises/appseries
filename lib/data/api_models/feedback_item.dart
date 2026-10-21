import 'package:json_annotation/json_annotation.dart';

import 'tipo_midia.dart';

export 'tipo_midia.dart';

part 'feedback_item.g.dart';

/// 👍 ou 👎. `desconhecido` existe para decodificar valor mais novo que o app.
enum SinalGosto {
  @JsonValue('like')
  like,
  @JsonValue('dislike')
  dislike,
  @JsonValue('desconhecido')
  desconhecido,
}

/// Onde o sinal nasceu. O backend trata `fechamento` como default.
enum OrigemFeedback {
  @JsonValue('fechamento')
  fechamento,
  @JsonValue('detalhe')
  detalhe,
  @JsonValue('abandono')
  abandono,
  @JsonValue('desconhecido')
  desconhecido,
}

/// Um sinal de gosto, como `GET /api/v1/feedback` devolve.
///
/// A chave é `(usuária, tipo, tmdbId)`: o 👍 no filme 1399 e o 👎 na série 1399
/// são sinais independentes. `peso` 2 é forte (veta a recomendação no 👎) e 1 é
/// fraco ("sem tempo"); num 👍 o peso é sempre 2.
@JsonSerializable()
class FeedbackItem {
  const FeedbackItem({
    required this.tmdbId,
    required this.sinal,
    this.peso = 2,
    this.origem = OrigemFeedback.fechamento,
    this.tipo,
    this.titulo,
    this.ano,
    this.posterPath,
    this.atualizadoEm,
  });

  factory FeedbackItem.fromJson(Map<String, dynamic> json) => _$FeedbackItemFromJson(json);

  final int tmdbId;

  @JsonKey(unknownEnumValue: SinalGosto.desconhecido)
  final SinalGosto sinal;

  final int peso;

  @JsonKey(unknownEnumValue: OrigemFeedback.desconhecido)
  final OrigemFeedback origem;

  /// Nulo em linha anterior à migração 008. Nesse caso não há como remover o
  /// sinal por tipo: a tela deve esconder a ação, não forçar `tipo!`.
  @JsonKey(unknownEnumValue: TipoMidia.desconhecido)
  final TipoMidia? tipo;

  final String? titulo;
  final String? ano;
  final String? posterPath;
  final DateTime? atualizadoEm;

  Map<String, dynamic> toJson() => _$FeedbackItemToJson(this);
}
