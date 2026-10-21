// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'preferencias.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Preferencias _$PreferenciasFromJson(Map<String, dynamic> json) => Preferencias(
  momento: json['momento'] as String?,
  generos:
      (json['generos'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
);

Map<String, dynamic> _$PreferenciasToJson(Preferencias instance) =>
    <String, dynamic>{'momento': instance.momento, 'generos': instance.generos};
