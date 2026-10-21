// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tmdb_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TmdbItem _$TmdbItemFromJson(Map<String, dynamic> json) => TmdbItem(
  id: (json['id'] as num).toInt(),
  tipo: $enumDecode(
    _$TipoMidiaEnumMap,
    json['tipo'],
    unknownValue: TipoMidia.desconhecido,
  ),
  titulo: json['titulo'] as String,
  ano: json['ano'] as String?,
  posterPath: json['posterPath'] as String?,
);

Map<String, dynamic> _$TmdbItemToJson(TmdbItem instance) => <String, dynamic>{
  'id': instance.id,
  'tipo': _$TipoMidiaEnumMap[instance.tipo]!,
  'titulo': instance.titulo,
  'ano': instance.ano,
  'posterPath': instance.posterPath,
};

const _$TipoMidiaEnumMap = {
  TipoMidia.movie: 'movie',
  TipoMidia.tv: 'tv',
  TipoMidia.desconhecido: 'desconhecido',
};
