import 'package:flutter/material.dart';

import '../ui/view/acervo_page.dart';
import '../ui/view/busca_page.dart';
import '../ui/view/detalhe_page.dart';
import '../ui/view/preferencias_page.dart';

/// Named routes for the whole app.
///
/// `login` and `home` are **not** here, on purpose: which of the two shows is
/// decided by the `AuthGate` from the session state (`app.dart`). A named route
/// to either of them would render the screen without that decision, which is
/// the one thing the gate exists to prevent.
///
/// Internal screens register their route here and are reached from a signed-in
/// screen. The four routes below point at stubs on purpose: the foundation task
/// (AP-108) opened the map once so no feature branch has to touch it again.
/// Each stub is replaced by its own card, one file per screen.
class Routes {
  const Routes._();

  static const String busca = '/busca';
  static const String detalhe = '/detalhe';
  static const String acervo = '/acervo';
  static const String preferencias = '/preferencias';

  static Map<String, WidgetBuilder> get mapa => <String, WidgetBuilder>{
        busca: (BuildContext _) => const BuscaPage(),
        detalhe: (BuildContext _) => const DetalhePage(),
        acervo: (BuildContext _) => const AcervoPage(),
        preferencias: (BuildContext _) => const PreferenciasPage(),
      };
}
