import 'package:appseries/data/api_models/preferencias.dart';
import 'package:appseries/data/repositories/preferencias_repository.dart';
import 'package:appseries/data/repositories/primeiro_acesso_repository.dart';
import 'package:appseries/ui/view_model/preferences_view_model.dart';
import 'package:appseries/utils/result.dart';

/// Taste repository that answers at once, from memory.
class FakePreferenciasRepository implements PreferenciasRepository {
  FakePreferenciasRepository({this.atual = const Preferencias()});

  Preferencias atual;
  int leituras = 0;

  @override
  Future<Result<Preferencias>> ler() async {
    leituras++;
    return Result<Preferencias>.ok(atual);
  }

  @override
  Future<Result<Preferencias>> salvar(Preferencias preferencias) async {
    atual = preferencias;
    return Result<Preferencias>.ok(preferencias);
  }
}

/// Local first-access mark kept in memory.
class FakePrimeiroAcessoRepository implements PrimeiroAcessoRepository {
  FakePrimeiroAcessoRepository({Set<String>? marcados}) : marcados = marcados ?? <String>{};

  final Set<String> marcados;

  @override
  Future<Result<bool>> jaPassou(String uid) async => Result<bool>.ok(marcados.contains(uid));

  @override
  Future<Result<void>> marcar(String uid) async {
    marcados.add(uid);
    return const Result<void>.ok(null);
  }
}

/// For tests about the login/home pair: every account already went through
/// the chips, so the gate goes straight to the home.
PreferencesViewModel preferenciasJaEscolhidas() => PreferencesViewModel(
      FakePreferenciasRepository(atual: const Preferencias(generos: <String>['Drama'])),
      FakePrimeiroAcessoRepository(),
    );
