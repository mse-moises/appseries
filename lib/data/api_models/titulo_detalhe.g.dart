// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'titulo_detalhe.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TituloDetalhe _$TituloDetalheFromJson(Map<String, dynamic> json) =>
    TituloDetalhe(
      id: (json['id'] as num).toInt(),
      tipo: $enumDecode(
        _$TipoMidiaEnumMap,
        json['tipo'],
        unknownValue: TipoMidia.desconhecido,
      ),
      titulo: json['titulo'] as String,
      ano: json['ano'] as String?,
      posterPath: json['posterPath'] as String?,
      sinopse: json['sinopse'] as String?,
      nota: (json['nota'] as num?)?.toDouble(),
      generos:
          (json['generos'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
    );

Map<String, dynamic> _$TituloDetalheToJson(TituloDetalhe instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tipo': _$TipoMidiaEnumMap[instance.tipo]!,
      'titulo': instance.titulo,
      'ano': instance.ano,
      'posterPath': instance.posterPath,
      'sinopse': instance.sinopse,
      'nota': instance.nota,
      'generos': instance.generos,
    };

const _$TipoMidiaEnumMap = {
  TipoMidia.movie: 'movie',
  TipoMidia.tv: 'tv',
  TipoMidia.desconhecido: 'desconhecido',
};
