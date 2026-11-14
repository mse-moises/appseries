import 'package:appseries/ui/theme/app_theme.dart';
import 'package:appseries/ui/view_model/preferences_view_model.dart';
import 'package:appseries/ui/widgets/genero_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cor do gênero', () {
    test('todo gênero da lista fixa tem a sua cor', () {
      for (final String genero in kGenerosTmdb) {
        expect(kCorDoGenero.containsKey(genero), isTrue, reason: genero);
      }
    });

    test('as cores não se repetem', () {
      expect(kCorDoGenero.values.toSet(), hasLength(kCorDoGenero.length));
    });

    test('gênero fora da lista cai no vermelho do app', () {
      expect(corDoGenero('Anime'), AppTheme.destaque);
    });

    testWidgets('marcado, o chip pinta com a cor do gênero', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: GeneroChip(genero: 'Terror', selecionado: true, onTap: null)),
      ));

      final FilterChip chip = tester.widget<FilterChip>(find.byType(FilterChip));
      expect(chip.selectedColor, kCorDoGenero['Terror']);
    });
  });
}
