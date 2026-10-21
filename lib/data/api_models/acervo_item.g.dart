// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'acervo_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AcervoItem _$AcervoItemFromJson(Map<String, dynamic> json) => AcervoItem(
  tmdbId: (json['tmdbId'] as num).toInt(),
  estado: $enumDecode(
    _$EstadoAcervoEnumMap,
    json['estado'],
    unknownValue: EstadoAcervo.desconhecido,
  ),
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

Map<String, dynamic> _$AcervoItemToJson(AcervoItem instance) =>
    <String, dynamic>{
      'tmdbId': instance.tmdbId,
      'estado': _$EstadoAcervoEnumMap[instance.estado]!,
      'tipo': _$TipoMidiaEnumMap[instance.tipo],
      'titulo': instance.titulo,
      'ano': instance.ano,
      'posterPath': instance.posterPath,
      'atualizadoEm': instance.atualizadoEm?.toIso8601String(),
    };

const _$EstadoAcervoEnumMap = {
  EstadoAcervo.planToWatch: 'plan_to_watch',
  EstadoAcervo.watching: 'watching',
  EstadoAcervo.watched: 'watched',
  EstadoAcervo.dropped: 'dropped',
  EstadoAcervo.desconhecido: 'desconhecido',
};

const _$TipoMidiaEnumMap = {
  TipoMidia.movie: 'movie',
  TipoMidia.tv: 'tv',
  TipoMidia.desconhecido: 'desconhecido',
};
