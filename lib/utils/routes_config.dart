import 'package:flutter/material.dart';

import '../ui/navegacao/titulo_ref.dart';
import '../ui/view/acervo_tabs_page.dart';
import '../ui/view/auth_gate.dart';
import '../ui/view/historico_page.dart';
import '../ui/view/search_page.dart';
import '../ui/view/title_detail_page.dart';
import '../ui/view/preferences_page.dart';
import '../ui/view/rec_page.dart';
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
  static const String recomendacao = '/recomendacao';

  static Map<String, WidgetBuilder> get mapa => <String, WidgetBuilder>{
        busca: (BuildContext _) => const SearchPage(),
        detalhe: (BuildContext _) => const TitleDetailPage(),
        acervo: (BuildContext _) => const AcervoTabsPage(),
        historico: (BuildContext _) => const HistoricoPage(),
        preferencias: (BuildContext _) => const PreferencesPage(),
        recomendacao: (BuildContext _) => const RecPage(),
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

  /// `onGenerateRoute`: the single door for every route, whether a tap
  /// (`pushNamed`), the address bar changing with the app open (a pasted link,
  /// an edited hash: the engine pushes the name without arguments) or the
  /// first route ([iniciais]). The app has no `routes:` on purpose: an exact
  /// name would match there and skip this door.
  ///
  /// - `/` is the `AuthGate` (not `home:`, because of [iniciais]);
  /// - a screen of [mapa], matched by the path so the detail's query does not
  ///   get in the way, waits for the session ([AguardaSessao]);
  /// - the detail without arguments gets its pair from the name;
  /// - anything else is not a route of the app (`null`).
  static Route<void>? gerar(RouteSettings settings) {
    final String nome = settings.name ?? '';
    if (nome == '/') return _raiz();
    final Uri? uri = Uri.tryParse(nome);
    final WidgetBuilder? tela = uri == null ? null : mapa[uri.path];
    if (tela == null) return null;
    return MaterialPageRoute<void>(
      settings: RouteSettings(name: nome, arguments: settings.arguments ?? refDoDetalhe(nome)),
      builder: (BuildContext c) => AguardaSessao(child: tela(c)),
    );
  }

  static Route<void> _raiz() => MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/'),
        builder: (_) => const AuthGate(),
      );

  /// `onGenerateInitialRoutes`: the route the app starts on, which is the
  /// address bar after an F5 or in a new tab.
  ///
  /// Always starts with the `AuthGate`, so going back lands on the home (or the
  /// login), even for a screen a tap would reach from another one, like the
  /// history from the shelf. The screen on top goes through [gerar].
  static List<Route<dynamic>> iniciais(String inicial) {
    final Route<void>? tela = inicial == '/' ? null : gerar(RouteSettings(name: inicial));
    return <Route<dynamic>>[_raiz(), if (tela != null) tela];
  }
}
