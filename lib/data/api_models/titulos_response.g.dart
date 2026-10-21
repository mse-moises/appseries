// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'titulos_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TitulosResponse _$TitulosResponseFromJson(Map<String, dynamic> json) =>
    TitulosResponse(
      resultados: (json['resultados'] as List<dynamic>)
          .map((e) => TmdbItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$TitulosResponseToJson(TitulosResponse instance) =>
    <String, dynamic>{'resultados': instance.resultados};
