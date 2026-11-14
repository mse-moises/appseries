import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One color per genre, picked to match its mood (Terror blood red, Romance
/// pink, Faroeste dust brown...). Presentation only, so it lives in the UI and
/// not in the ViewModel's genre list.
///
/// A genre outside the fixed list (saved by an older app, say) falls back to
/// the app's highlight red.
const Map<String, Color> kCorDoGenero = <String, Color>{
  'Ação': Color(0xFFE53935),
  'Aventura': Color(0xFF00897B),
  'Animação': Color(0xFFFF9800),
  'Comédia': Color(0xFFFDD835),
  'Crime': Color(0xFF546E7A),
  'Documentário': Color(0xFF5D8AA8),
  'Drama': Color(0xFF8E24AA),
  'Família': Color(0xFF43A047),
  'Fantasia': Color(0xFF7E57C2),
  'História': Color(0xFFA1887F),
  'Terror': Color(0xFF8B0000),
  'Música': Color(0xFFEC407A),
  'Mistério': Color(0xFF3949AB),
  'Romance': Color(0xFFF06292),
  'Ficção científica': Color(0xFF00ACC1),
  'Thriller': Color(0xFF37474F),
  'Guerra': Color(0xFF6B8E23),
  'Faroeste': Color(0xFFB5651D),
};

Color corDoGenero(String genero) => kCorDoGenero[genero] ?? AppTheme.destaque;

/// A genre pill: filled with the genre's color when chosen, an outline tinted
/// with it otherwise, so even the unchosen ones hint at the mood.
class GeneroChip extends StatelessWidget {
  const GeneroChip({
    super.key,
    required this.genero,
    required this.selecionado,
    required this.onTap,
  });

  final String genero;
  final bool selecionado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cores = Theme.of(context).colorScheme;
    final Color cor = corDoGenero(genero);
    // Comédia's yellow needs dark text; Terror's red needs white.
    final Color sobreCor =
        ThemeData.estimateBrightnessForColor(cor) == Brightness.dark ? Colors.white : Colors.black87;

    return FilterChip(
      label: Text(genero),
      selected: selecionado,
      onSelected: onTap == null ? null : (_) => onTap!(),
      checkmarkColor: sobreCor,
      shape: const StadiumBorder(),
      selectedColor: cor,
      backgroundColor: cor.withValues(alpha: 0.08),
      side: BorderSide(color: selecionado ? cor : cor.withValues(alpha: 0.6), width: 1.5),
      labelStyle: TextStyle(
        color: selecionado ? sobreCor : cores.onSurface,
        fontWeight: selecionado ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }
}
