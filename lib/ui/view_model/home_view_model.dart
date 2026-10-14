import 'package:flutter/foundation.dart';

import '../../data/api_models/health_status.dart';
import '../../data/repositories/health_repository.dart';
import '../../utils/result.dart';

/// State of the home screen.
///
/// Owns what the screen renders (loading / error / data) and talks only to the
/// repository **contract**.
class HomeViewModel extends ChangeNotifier {
  HomeViewModel(this._repository);

  final HealthRepository _repository;

  bool _isLoading = true;
  String? _error;
  HealthStatus? _status;

  bool get isLoading => _isLoading;
  String? get error => _error;
  HealthStatus? get status => _status;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    _status = null;
    notifyListeners();

    switch (await _repository.check()) {
      case Ok<HealthStatus>(:final value):
        _status = value;
      case Error<HealthStatus>(:final error):
        _error = error.mensagem;
    }

    _isLoading = false;
    notifyListeners();
  }
}
