// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'marcar_acervo_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MarcarAcervoRequest _$MarcarAcervoRequestFromJson(Map<String, dynamic> json) =>
    MarcarAcervoRequest(
      estado: $enumDecode(_$EstadoAcervoEnumMap, json['estado']),
      tipo: $enumDecode(_$TipoMidiaEnumMap, json['tipo']),
    );

Map<String, dynamic> _$MarcarAcervoRequestToJson(
  MarcarAcervoRequest instance,
) => <String, dynamic>{
  'estado': _$EstadoAcervoEnumMap[instance.estado]!,
  'tipo': _$TipoMidiaEnumMap[instance.tipo]!,
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
