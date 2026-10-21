/// Base of the TMDB image CDN.
///
/// The API key is never part of an image URL: posters are public. Keeping the
/// base in one place is what lets the AP-34 cache change only the widget.
const String tmdbImageBase = 'https://image.tmdb.org/t/p';

/// URL of a poster, or `null` when the title has none.
///
/// The backend sends the raw path (`/x.jpg`), so the size goes between the base
/// and the path: `.../t/p/w342/x.jpg`.
String? urlDoPoster(String? posterPath, {String tamanho = 'w342'}) {
  if (posterPath == null || posterPath.isEmpty) return null;
  return '$tmdbImageBase/$tamanho$posterPath';
}
