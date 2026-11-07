// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'carta_rec.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CartaRec _$CartaRecFromJson(Map<String, dynamic> json) => CartaRec(
  tmdbId: (json['tmdbId'] as num).toInt(),
  tipo: $enumDecode(
    _$TipoMidiaEnumMap,
    json['tipo'],
    unknownValue: TipoMidia.desconhecido,
  ),
  titulo: json['titulo'] as String,
  justificativa: json['justificativa'] as String,
  ano: json['ano'] as String?,
  posterPath: json['posterPath'] as String?,
);

Map<String, dynamic> _$CartaRecToJson(CartaRec instance) => <String, dynamic>{
  'tmdbId': instance.tmdbId,
  'tipo': _$TipoMidiaEnumMap[instance.tipo]!,
  'titulo': instance.titulo,
  'ano': instance.ano,
  'posterPath': instance.posterPath,
  'justificativa': instance.justificativa,
};

const _$TipoMidiaEnumMap = {
  TipoMidia.movie: 'movie',
  TipoMidia.tv: 'tv',
  TipoMidia.desconhecido: 'desconhecido',
};

RecResult _$RecResultFromJson(Map<String, dynamic> json) => RecResult(
  cartas: (json['cartas'] as List<dynamic>)
      .map((e) => CartaRec.fromJson(e as Map<String, dynamic>))
      .toList(),
  origem: $enumDecode(
    _$OrigemRecEnumMap,
    json['origem'],
    unknownValue: OrigemRec.desconhecida,
  ),
);

Map<String, dynamic> _$RecResultToJson(RecResult instance) => <String, dynamic>{
  'cartas': instance.cartas,
  'origem': _$OrigemRecEnumMap[instance.origem]!,
};

const _$OrigemRecEnumMap = {
  OrigemRec.llm: 'llm',
  OrigemRec.emAlta: 'em_alta',
  OrigemRec.desconhecida: 'desconhecida',
};
