import 'package:json_annotation/json_annotation.dart';

part 'preferencias.g.dart';

/// What the person likes, as `GET/PUT /api/v1/preferencias` carries it.
///
/// `momento` is free text and may be null (never filled); `generos` is the list
/// of pt-BR TMDB genre names and may be empty.
///
/// **`salvar` é replace total, não merge**: o `PUT` substitui o registro inteiro,
/// então `Preferencias(momento: 'domingo')` (sem gêneros) apaga os gêneros, e
/// `Preferencias(generos: [...])` apaga o momento. Quem só quer mudar metade lê
/// antes e manda o conjunto completo.
@JsonSerializable()
class Preferencias {
  const Preferencias({this.momento, this.generos = const <String>[]});

  factory Preferencias.fromJson(Map<String, dynamic> json) => _$PreferenciasFromJson(json);

  final String? momento;
  final List<String> generos;

  Map<String, dynamic> toJson() => _$PreferenciasToJson(this);

  bool get vazio => generos.isEmpty && (momento == null || momento!.trim().isEmpty);
}
