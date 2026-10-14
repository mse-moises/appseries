/// Build-time environment, injected with `--dart-define`.
///
/// Example:
///   flutter run -d chrome --dart-define=API_BASE_URL=https://gdn.vps-kinghost.net
class Env {
  const Env._();

  /// Backend host. Endpoints carry their own path (`/health`, `/api/v1/...`).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://gdn.vps-kinghost.net',
  );
}
