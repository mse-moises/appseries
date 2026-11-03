import 'package:flutter/material.dart';

import '../ui/navegacao/titulo_ref.dart';
import '../ui/view/acervo_tabs_page.dart';
import '../ui/view/auth_gate.dart';
import '../ui/view/historico_page.dart';
import '../ui/view/search_page.dart';
import '../ui/view/title_detail_page.dart';
import '../ui/view/preferences_page.dart';
import '../ui/widgets/aguarda_sessao.dart';

/// Named routes for the whole app.
///
/// `login` and `home` are **not** here, on purpose: which of the two shows is
/// decided by the `AuthGate` from the session state (`app.dart`). A named route
/// to either of them would render the screen without that decision, which is
/// the one thing the gate exists to prevent.
///
/// Internal screens register their route here and are reached from a signed-in
/// screen. The foundation task (AP-108) opened the map with a stub per screen,
/// so no feature branch has to touch it again; each card replaces its stub,
/// one file per screen (the shelf, `acervo`, is no longer one: AP-59).
class Routes {
  const Routes._();

  static const String busca = '/busca';
  static const String detalhe = '/detalhe';
  static const String acervo = '/acervo';
  static const String historico = '/historico';
  static const String preferencias = '/preferencias';

  static Map<String, WidgetBuilder> get mapa => <String, WidgetBuilder>{
        busca: (BuildContext _) => const SearchPage(),
        detalhe: (BuildContext _) => const TitleDetailPage(),
        acervo: (BuildContext _) => const AcervoTabsPage(),
        historico: (BuildContext _) => const HistoricoPage(),
        preferencias: (BuildContext _) => const PreferencesPage(),
      };

  /// The detail's name carries the pair in the query (`/detalhe?tipo=tv&id=1399`),
  /// so the address bar keeps it and a reload can open the same title. The
  /// arguments alone live in memory and die with an F5.
  ///
  /// A [TipoMidia.desconhecido] has no wire value: the name stays the bare
  /// [detalhe], which still opens from the arguments.
  static String detalheDe(TituloRef ref) {
    final String? tipo = tipoWire(ref.tipo);
    if (tipo == null) return detalhe;
    return Uri(path: detalhe, queryParameters: <String, String>{'tipo': tipo, 'id': '${ref.id}'})
        .toString();
  }

  /// The pair back from a name built by [detalheDe], or `null` when the name is
  /// not the detail or the query is missing or malformed.
  static TituloRef? refDoDetalhe(String? nome) {
    final Uri? uri = nome == null ? null : Uri.tryParse(nome);
    if (uri == null || uri.path != detalhe) return null;
    final TipoMidia? tipo = switch (uri.queryParameters['tipo']) {
      'tv' => TipoMidia.tv,
      'movie' => TipoMidia.movie,
      _ => null,
    };
    final int? id = int.tryParse(uri.queryParameters['id'] ?? '');
    if (tipo == null || id == null || id <= 0) return null;
    return TituloRef(tipo: tipo, id: id);
  }

  /// What every screen calls to open a title: the pair goes both in the name
  /// (for the address bar) and in the arguments (what the page reads).
  static Future<void> abrirDetalhe(BuildContext context, TituloRef ref) =>
      Navigator.pushNamed<void>(context, detalheDe(ref), arguments: ref);

  /// `onGenerateRoute`: names outside [mapa]. The first route `/` (the
  /// `AuthGate`, which is not `home:` because of [iniciais]) and the detail
  /// with its query, which the map cannot match because the key is the bare
  /// path.
  static Route<void>? gerar(RouteSettings settings) {
    if (settings.name == '/') return _raiz();
    final Uri? uri = Uri.tryParse(settings.name ?? '');
    if (uri == null || uri.path != detalhe) return null;
    return MaterialPageRoute<void>(settings: settings, builder: (_) => const TitleDetailPage());
  }

  static Route<void> _raiz() => MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/'),
        builder: (_) => const AuthGate(),
      );

  /// `onGenerateInitialRoutes`: the route the app starts on, which is the
  /// address bar after an F5 or a pasted link.
  ///
  /// Always starts with the `AuthGate`, so going back lands where a tap would
  /// have come from. An internal screen on top waits for the session
  /// ([AguardaSessao]); the detail gets its pair from the query.
  static List<Route<dynamic>> iniciais(String inicial) {
    final Route<void> raiz = _raiz();
    final Uri? uri = Uri.tryParse(inicial);
    final WidgetBuilder? tela = uri == null ? null : mapa[uri.path];
    if (tela == null) return <Route<dynamic>>[raiz];
    return <Route<dynamic>>[
      raiz,
      MaterialPageRoute<void>(
        settings: RouteSettings(name: inicial, arguments: refDoDetalhe(inicial)),
        builder: (BuildContext c) => AguardaSessao(child: tela(c)),
      ),
    ];
  }
}
