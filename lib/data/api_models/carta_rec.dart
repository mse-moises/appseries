import 'package:json_annotation/json_annotation.dart';

import 'tipo_midia.dart';

export 'tipo_midia.dart';

part 'carta_rec.g.dart';

/// De onde veio a recomendação.
///
/// `emAlta` é o plano B do servidor (sem preferência e sem feedback, ou quando
/// a IA falhou). A tela desenha as cartas do mesmo jeito: fallback não é erro.
enum OrigemRec {
  @JsonValue('llm')
  llm,
  @JsonValue('em_alta')
  emAlta,

  /// Valor que esta versão do app não conhece.
  @JsonValue('desconhecida')
  desconhecida,
}

/// Uma carta de `POST /api/v1/rec`.
///
/// Dois detalhes iguais aos do acervo e diferentes do catálogo: o id se chama
/// `tmdbId` (não `id`) e `ano` é **String** (o TMDB manda `"2011"` e uma faixa
/// como `"2011–2019"` não caberia num número).
@JsonSerializable()
class CartaRec {
  const CartaRec({
    required this.tmdbId,
    required this.tipo,
    required this.titulo,
    required this.justificativa,
    this.ano,
    this.posterPath,
  });

  factory CartaRec.fromJson(Map<String, dynamic> json) => _$CartaRecFromJson(json);

  final int tmdbId;

  @JsonKey(unknownEnumValue: TipoMidia.desconhecido)
  final TipoMidia tipo;

  final String titulo;
  final String? ano;
  final String? posterPath;

  /// Uma linha escrita pelo servidor: cita o momento, os gêneros declarados ou
  /// uma curtida de verdade (nunca um título inventado).
  final String justificativa;

  Map<String, dynamic> toJson() => _$CartaRecToJson(this);
}

/// Resposta inteira do `/rec`: as cartas e de onde elas vieram.
@JsonSerializable()
class RecResult {
  const RecResult({required this.cartas, required this.origem});

  factory RecResult.fromJson(Map<String, dynamic> json) => _$RecResultFromJson(json);

  /// Até 5 cartas. Pode vir com menos de 3 e até vazia, quando o acervo e os 👎
  /// fortes esgotam os candidatos: a tela explica em vez de ficar em branco.
  final List<CartaRec> cartas;

  @JsonKey(unknownEnumValue: OrigemRec.desconhecida)
  final OrigemRec origem;

  Map<String, dynamic> toJson() => _$RecResultToJson(this);
}
