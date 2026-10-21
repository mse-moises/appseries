// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feedback_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FeedbackItem _$FeedbackItemFromJson(Map<String, dynamic> json) => FeedbackItem(
  tmdbId: (json['tmdbId'] as num).toInt(),
  sinal: $enumDecode(
    _$SinalGostoEnumMap,
    json['sinal'],
    unknownValue: SinalGosto.desconhecido,
  ),
  peso: (json['peso'] as num?)?.toInt() ?? 2,
  origem:
      $enumDecodeNullable(
        _$OrigemFeedbackEnumMap,
        json['origem'],
        unknownValue: OrigemFeedback.desconhecido,
      ) ??
      OrigemFeedback.fechamento,
  tipo: $enumDecodeNullable(
    _$TipoMidiaEnumMap,
    json['tipo'],
    unknownValue: TipoMidia.desconhecido,
  ),
  titulo: json['titulo'] as String?,
  ano: json['ano'] as String?,
  posterPath: json['posterPath'] as String?,
  atualizadoEm: json['atualizadoEm'] == null
      ? null
      : DateTime.parse(json['atualizadoEm'] as String),
);

Map<String, dynamic> _$FeedbackItemToJson(FeedbackItem instance) =>
    <String, dynamic>{
      'tmdbId': instance.tmdbId,
      'sinal': _$SinalGostoEnumMap[instance.sinal]!,
      'peso': instance.peso,
      'origem': _$OrigemFeedbackEnumMap[instance.origem]!,
      'tipo': _$TipoMidiaEnumMap[instance.tipo],
      'titulo': instance.titulo,
      'ano': instance.ano,
      'posterPath': instance.posterPath,
      'atualizadoEm': instance.atualizadoEm?.toIso8601String(),
    };

const _$SinalGostoEnumMap = {
  SinalGosto.like: 'like',
  SinalGosto.dislike: 'dislike',
  SinalGosto.desconhecido: 'desconhecido',
};

const _$OrigemFeedbackEnumMap = {
  OrigemFeedback.fechamento: 'fechamento',
  OrigemFeedback.detalhe: 'detalhe',
  OrigemFeedback.abandono: 'abandono',
  OrigemFeedback.desconhecido: 'desconhecido',
};

const _$TipoMidiaEnumMap = {
  TipoMidia.movie: 'movie',
  TipoMidia.tv: 'tv',
  TipoMidia.desconhecido: 'desconhecido',
};
