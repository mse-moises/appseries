import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/app_error.dart';
import '../../utils/result.dart';
import 'primeiro_acesso_repository.dart';

/// Keeps the mark in `shared_preferences`, one boolean per account.
class PrimeiroAcessoRepositoryImpl implements PrimeiroAcessoRepository {
  PrimeiroAcessoRepositoryImpl({Future<SharedPreferences> Function()? prefs})
      : _prefs = prefs ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _prefs;

  @visibleForTesting
  static String chave(String uid) => 'preferencias_vistas_$uid';

  @override
  Future<Result<bool>> jaPassou(String uid) async {
    try {
      final SharedPreferences prefs = await _prefs();
      return Result<bool>.ok(prefs.getBool(chave(uid)) ?? false);
    } catch (error) {
      debugPrint('[AppSeries] marca de primeiro acesso ilegível: $error');
      return const Result<bool>.error(ArmazenamentoLocalError());
    }
  }

  @override
  Future<Result<void>> marcar(String uid) async {
    try {
      final SharedPreferences prefs = await _prefs();
      await prefs.setBool(chave(uid), true);
      return const Result<void>.ok(null);
    } catch (error) {
      debugPrint('[AppSeries] não gravou a marca de primeiro acesso: $error');
      return const Result<void>.error(ArmazenamentoLocalError());
    }
  }
}
