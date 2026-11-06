import 'dart:async';

import 'package:appseries/data/api_models/preferencias.dart';
import 'package:appseries/data/repositories/preferencias_repository.dart';
import 'package:appseries/data/repositories/primeiro_acesso_repository.dart';
import 'package:appseries/ui/view_model/preferences_view_model.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:appseries/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePreferencias implements PreferenciasRepository {
  _FakePreferencias({this.lidas = const Result<Preferencias>.ok(Preferencias())});

  Result<Preferencias> lidas;
  Completer<Result<Preferencias>>? leituraPendente;
  Result<Preferencias>? salvas;
  Preferencias? enviadas;
  int leituras = 0;

  @override
  Future<Result<Preferencias>> ler() {
    leituras++;
    return leituraPendente?.future ?? Future<Result<Preferencias>>.value(lidas);
  }

  @override
  Future<Result<Preferencias>> salvar(Preferencias preferencias) async {
    enviadas = preferencias;
    return salvas ?? Result<Preferencias>.ok(preferencias);
  }
}

class _FakeMarca implements PrimeiroAcessoRepository {
  _FakeMarca({Set<String>? marcados}) : marcados = marcados ?? <String>{};

  final Set<String> marcados;
  bool falha = false;

  @override
  Future<Result<bool>> jaPassou(String uid) async => falha
      ? const Result<bool>.error(ServerError())
      : Result<bool>.ok(marcados.contains(uid));

  @override
  Future<Result<void>> marcar(String uid) async {
    if (falha) return const Result<void>.error(ServerError());
    marcados.add(uid);
    return const Result<void>.ok(null);
  }
}

void main() {
  group('PreferencesViewModel — primeiro acesso', () {
    test('conta sem marca e sem gêneros cai nos chips', () async {
      final _FakePreferencias prefs = _FakePreferencias();
      final PreferencesViewModel vm = PreferencesViewModel(prefs, _FakeMarca());

      await vm.verificarPrimeiroAcesso('u1');

      expect(vm.acesso, AcessoInicial.escolher);
      expect(vm.selecionados, isEmpty);
    });

    test('com a marca local vai direto para a home, sem chamar o servidor', () async {
      final _FakePreferencias prefs = _FakePreferencias();
      final PreferencesViewModel vm =
          PreferencesViewModel(prefs, _FakeMarca(marcados: <String>{'u1'}));

      await vm.verificarPrimeiroAcesso('u1');

      expect(vm.acesso, AcessoInicial.liberado);
      expect(prefs.leituras, 0);
    });

    test('gêneros já salvos no servidor liberam a home e gravam a marca', () async {
      final _FakeMarca marca = _FakeMarca();
      final PreferencesViewModel vm = PreferencesViewModel(
        _FakePreferencias(
          lidas: const Result<Preferencias>.ok(Preferencias(generos: <String>['Drama'])),
        ),
        marca,
      );

      await vm.verificarPrimeiroAcesso('u1');

      expect(vm.acesso, AcessoInicial.liberado);
      expect(marca.marcados, contains('u1'));
    });

    test('servidor fora do ar nunca trava a entrada: vai para a home', () async {
      final PreferencesViewModel vm = PreferencesViewModel(
        _FakePreferencias(lidas: const Result<Preferencias>.error(NetworkError())),
        _FakeMarca(),
      );

      await vm.verificarPrimeiroAcesso('u1');

      expect(vm.acesso, AcessoInicial.liberado);
    });

    test('marca ilegível não decide sozinha: consulta o servidor', () async {
      final _FakePreferencias prefs = _FakePreferencias();
      final PreferencesViewModel vm = PreferencesViewModel(prefs, _FakeMarca()..falha = true);

      await vm.verificarPrimeiroAcesso('u1');

      expect(prefs.leituras, 1);
      expect(vm.acesso, AcessoInicial.escolher);
    });

    test('pular libera a home, grava a marca e não manda nada ao servidor', () async {
      final _FakePreferencias prefs = _FakePreferencias();
      final _FakeMarca marca = _FakeMarca();
      final PreferencesViewModel vm = PreferencesViewModel(prefs, marca);
      await vm.verificarPrimeiroAcesso('u1');

      await vm.pular();

      expect(vm.acesso, AcessoInicial.liberado);
      expect(marca.marcados, contains('u1'));
      expect(prefs.enviadas, isNull);
    });

    test('pular com a marca falhando ainda libera a home', () async {
      final _FakeMarca marca = _FakeMarca();
      final PreferencesViewModel vm = PreferencesViewModel(_FakePreferencias(), marca);
      await vm.verificarPrimeiroAcesso('u1');
      marca.falha = true;

      await vm.pular();

      expect(vm.acesso, AcessoInicial.liberado);
    });

    test('resposta de uma sessão antiga não decide a nova', () async {
      final _FakePreferencias prefs = _FakePreferencias()
        ..leituraPendente = Completer<Result<Preferencias>>();
      final PreferencesViewModel vm = PreferencesViewModel(prefs, _FakeMarca());

      final Future<void> antiga = vm.verificarPrimeiroAcesso('u1');
      await Future<void>.delayed(Duration.zero);
      vm.resetSessao();
      prefs.leituraPendente!.complete(const Result<Preferencias>.ok(Preferencias()));
      await antiga;

      expect(vm.acesso, AcessoInicial.verificando);
    });
  });

  group('PreferencesViewModel — chips', () {
    test('alternar marca e desmarca, e a contagem segue o mínimo sugerido de 3', () async {
      final PreferencesViewModel vm = PreferencesViewModel(_FakePreferencias(), _FakeMarca());
      await vm.verificarPrimeiroAcesso('u1');

      expect(vm.faltamParaSugerido, 3);
      vm
        ..alternar('Drama')
        ..alternar('Comédia');
      expect(vm.faltamParaSugerido, 1);
      vm.alternar('Terror');
      expect(vm.faltamParaSugerido, 0);
      vm.alternar('Terror');
      expect(vm.selecionados, <String>['Comédia', 'Drama'], reason: 'na ordem da lista fixa');
    });

    test('sem nenhum chip não dá para salvar; com um já dá (3 é sugestão)', () async {
      final PreferencesViewModel vm = PreferencesViewModel(_FakePreferencias(), _FakeMarca());
      await vm.verificarPrimeiroAcesso('u1');

      expect(vm.podeSalvar, isFalse);
      vm.alternar('Drama');
      expect(vm.podeSalvar, isTrue);
    });

    test('a lista tem os 18 gêneros do TMDB em pt-BR', () {
      expect(kGenerosTmdb, hasLength(18));
      expect(kGenerosTmdb.toSet(), hasLength(18), reason: 'o servidor recusa gênero repetido');
      expect(kGenerosTmdb, containsAll(<String>['Ficção científica', 'Faroeste', 'Ação']));
    });

    test('gênero salvo fora da lista fixa aparece e continua marcado', () async {
      final PreferencesViewModel vm = PreferencesViewModel(
        _FakePreferencias(
          lidas: const Result<Preferencias>.ok(Preferencias(generos: <String>['Anime'])),
        ),
        _FakeMarca(),
      );

      await vm.carregar();

      expect(vm.generos.last, 'Anime');
      expect(vm.selecionado('Anime'), isTrue);
    });
  });

  group('PreferencesViewModel — salvar e carregar', () {
    test('salvar manda os gêneros e preserva o momento já salvo (PUT é replace)', () async {
      final _FakePreferencias prefs = _FakePreferencias(
        lidas: const Result<Preferencias>.ok(Preferencias(momento: 'domingo à tarde')),
      );
      final _FakeMarca marca = _FakeMarca();
      final PreferencesViewModel vm = PreferencesViewModel(prefs, marca);
      await vm.verificarPrimeiroAcesso('u1');
      vm
        ..alternar('Drama')
        ..alternar('Ação')
        ..alternar('Comédia');

      final bool salvou = await vm.salvar();

      expect(salvou, isTrue);
      expect(prefs.enviadas?.momento, 'domingo à tarde');
      expect(prefs.enviadas?.generos, <String>['Ação', 'Comédia', 'Drama']);
      expect(vm.acesso, AcessoInicial.liberado);
      expect(marca.marcados, contains('u1'));
    });

    test('erro ao salvar vira frase, mantém os chips e a tela', () async {
      final _FakePreferencias prefs = _FakePreferencias()
        ..salvas = const Result<Preferencias>.error(NetworkError());
      final PreferencesViewModel vm = PreferencesViewModel(prefs, _FakeMarca());
      await vm.verificarPrimeiroAcesso('u1');
      vm.alternar('Drama');

      final bool salvou = await vm.salvar();

      expect(salvou, isFalse);
      expect(vm.erroSalvar, const NetworkError().mensagem);
      expect(vm.selecionados, <String>['Drama']);
      expect(vm.acesso, AcessoInicial.escolher);
      expect(vm.salvando, isFalse);
    });

    test('carregar mostra os chips que o GET devolveu', () async {
      final PreferencesViewModel vm = PreferencesViewModel(
        _FakePreferencias(
          lidas: const Result<Preferencias>.ok(
            Preferencias(generos: <String>['Drama', 'Terror', 'Comédia']),
          ),
        ),
        _FakeMarca(),
      );

      await vm.carregar();

      expect(vm.carregando, isFalse);
      expect(vm.selecionados, <String>['Comédia', 'Drama', 'Terror']);
    });

    test('carga que falha mostra erro e bloqueia o salvar (não apaga o momento)', () async {
      final PreferencesViewModel vm = PreferencesViewModel(
        _FakePreferencias(lidas: const Result<Preferencias>.error(NetworkError())),
        _FakeMarca(),
      );

      await vm.carregar();
      vm.alternar('Drama');

      expect(vm.erroCarga, const NetworkError().mensagem);
      expect(vm.podeSalvar, isFalse);
    });

    test('repository que estoura não deixa a tela presa carregando', () async {
      final PreferencesViewModel vm = PreferencesViewModel(_Estoura(), _FakeMarca());

      await vm.carregar();

      expect(vm.carregando, isFalse);
      expect(vm.erroCarga, const ServerError().mensagem);
    });
  });
}

class _Estoura implements PreferenciasRepository {
  @override
  Future<Result<Preferencias>> ler() => throw StateError('quebrou');

  @override
  Future<Result<Preferencias>> salvar(Preferencias preferencias) => throw StateError('quebrou');
}
