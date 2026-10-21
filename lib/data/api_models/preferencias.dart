import 'package:json_annotation/json_annotation.dart';

part 'preferencias.g.dart';

/// What the person likes, as `GET/PUT /api/v1/preferencias` carries it.
///
/// `momento` is free text and may be null (never filled); `generos` is the list
/// of pt-BR TMDB genre names and may be empty. On `PUT`, empty `momento` clears
/// the field on the server.
@JsonSerializable()
class Preferencias {
  const Preferencias({this.momento, this.generos = const <String>[]});

  factory Preferencias.fromJson(Map<String, dynamic> json) => _$PreferenciasFromJson(json);

  final String? momento;
  final List<String> generos;

  Map<String, dynamic> toJson() => _$PreferenciasToJson(this);

  bool get vazio => generos.isEmpty && (momento == null || momento!.trim().isEmpty);
}
