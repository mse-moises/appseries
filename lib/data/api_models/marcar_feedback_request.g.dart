// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'marcar_feedback_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MarcarFeedbackRequest _$MarcarFeedbackRequestFromJson(
  Map<String, dynamic> json,
) => MarcarFeedbackRequest(
  sinal: $enumDecode(_$SinalGostoEnumMap, json['sinal']),
  tipo: $enumDecode(_$TipoMidiaEnumMap, json['tipo']),
  peso: (json['peso'] as num?)?.toInt() ?? 2,
  origem:
      $enumDecodeNullable(_$OrigemFeedbackEnumMap, json['origem']) ??
      OrigemFeedback.fechamento,
);

Map<String, dynamic> _$MarcarFeedbackRequestToJson(
  MarcarFeedbackRequest instance,
) => <String, dynamic>{
  'sinal': _$SinalGostoEnumMap[instance.sinal]!,
  'tipo': _$TipoMidiaEnumMap[instance.tipo]!,
  'peso': instance.peso,
  'origem': _$OrigemFeedbackEnumMap[instance.origem]!,
};

const _$SinalGostoEnumMap = {
  SinalGosto.like: 'like',
  SinalGosto.dislike: 'dislike',
  SinalGosto.desconhecido: 'desconhecido',
};

const _$TipoMidiaEnumMap = {
  TipoMidia.movie: 'movie',
  TipoMidia.tv: 'tv',
  TipoMidia.desconhecido: 'desconhecido',
};

const _$OrigemFeedbackEnumMap = {
  OrigemFeedback.fechamento: 'fechamento',
  OrigemFeedback.detalhe: 'detalhe',
  OrigemFeedback.abandono: 'abandono',
  OrigemFeedback.desconhecido: 'desconhecido',
};
