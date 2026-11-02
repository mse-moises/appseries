import 'package:flutter/material.dart';

import '../ui/view/acervo_tabs_page.dart';
import '../ui/view/historico_page.dart';
import '../ui/view/search_page.dart';
import '../ui/view/title_detail_page.dart';
import '../ui/view/preferences_page.dart';

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
}
