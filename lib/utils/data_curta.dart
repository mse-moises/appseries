/// Dates as the app shows them (AP-54, AP-73).
///
/// Lives in `utils` because the detail ("Assistido em") and the history list
/// show the same date: a second copy would drift.
library;

/// The default conversion of [dataCurta]: the same instant, in the device's
/// time zone (a local `DateTime`, never a UTC one).
DateTime paraLocalDoAparelho(DateTime quando) => quando.toLocal();

/// `dd/mm/aaaa` in the device's time zone: the server sends UTC, and a title
/// watched at 22h in Brazil is already the next day in UTC.
///
/// [paraLocal] is the conversion to the device's zone; a test passes a fixed
/// one, because the zone of the machine running the tests is not Brazil's.
String dataCurta(DateTime quando, {DateTime Function(DateTime) paraLocal = paraLocalDoAparelho}) {
  final DateTime local = paraLocal(quando);
  String doisDigitos(int n) => n.toString().padLeft(2, '0');
  return '${doisDigitos(local.day)}/${doisDigitos(local.month)}/${local.year}';
}
