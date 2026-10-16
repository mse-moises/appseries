import 'package:flutter/material.dart';

/// Named routes for the whole app.
///
/// `login` and `home` are **not** here, on purpose: which of the two shows is
/// decided by the `AuthGate` from the session state (`app.dart`). A named route
/// to either of them would render the screen without that decision, which is
/// the one thing the gate exists to prevent.
///
/// Internal screens (a detail page, for instance) register their route here and
/// are reached from a signed-in screen. No internal screen exists yet, so the
/// map is empty — and the mechanism stays in place for the first one.
class Routes {
  const Routes._();

  static Map<String, WidgetBuilder> get mapa => <String, WidgetBuilder>{};
}
