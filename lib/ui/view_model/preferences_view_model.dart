import 'package:flutter/foundation.dart';

import '../../data/api_models/preferencias.dart';
import '../../data/repositories/preferencias_repository.dart';
import '../../data/repositories/primeiro_acesso_repository.dart';
import '../../utils/app_error.dart';
import '../../utils/result.dart';

/// The TMDB genres, in pt-BR, as the chips show them.
///
/// Fixed in the app: the backend has no genre route. The AI prompt takes free
/// text, so the names do not have to match a TMDB id.
const List<String> kGenerosTmdb = <String>[
  'Ação',
  'Aventura',
  'Animação',
  'Comédia',
  'Crime',
  'Documentário',
  'Drama',
  'Família',
  'Fantasia',
  'História',
  'Terror',
  'Música',
  'Mistério',
  'Romance',
  'Ficção científica',
  'Thriller',
  'Guerra',
  'Faroeste',
];

/// Suggested, not required: with fewer she can still go on.
const int kGenerosSugeridos = 3;

/// What the `AuthGate` shows right after the login.
enum AcessoInicial {
  /// Reading the local mark and the server: a loading screen.
  verificando,

  /// First access: the genre chips.
  escolher,

  /// The home.
  liberado,
}

/// State of the taste screen (AP-38) and of the first-access decision.
///
/// Created once at the root: the gate calls [resetSessao] on every login, so
/// one account never opens on the previous one's chips.
class PreferencesViewModel extends ChangeNotifier {
  PreferencesViewModel(this._preferencias, this._primeiroAcesso);

  final PreferenciasRepository _preferencias;
  final PrimeiroAcessoRepository _primeiroAcesso;

  AcessoInicial _acesso = AcessoInicial.verificando;
  String? _uid;

  /// Bumped on every new session: an answer from an older one is dropped.
  int _sessao = 0;

  /// Bumped on every screen load and on every new session: only the latest
  /// answer counts. The load does **not** watch [_sessao]: after an F5 on
  /// `/preferencias` the gate's [verificarPrimeiroAcesso] and the screen's
  /// [carregar] start in the same frame, in no guaranteed order, and the
  /// gate's check must not throw the screen's read away.
  int _carga = 0;

  bool _carregando = false;
  String? _erroCarga;
  bool _salvando = false;
  bool _pulando = false;
  String? _erroSalvar;

  /// The GET answered: only then saving is safe. The `PUT` replaces the whole
  /// record, so saving without the read would wipe the saved moment.
  bool _lido = false;
  String? _momento;
  final Set<String> _selecionados = <String>{};

  AcessoInicial get acesso => _acesso;
  bool get carregando => _carregando;
  String? get erroCarga => _erroCarga;
  bool get salvando => _salvando;

  /// Writing the local mark after "Pular": the button waits, a second tap
  /// does nothing.
  bool get pulando => _pulando;
  String? get erroSalvar => _erroSalvar;

  /// The chips on screen: the fixed list, plus any genre the server holds that
  /// is not in it (so saving never drops it without her seeing).
  List<String> get generos => <String>[
        ...kGenerosTmdb,
        ..._selecionados.where((String g) => !kGenerosTmdb.contains(g)),
      ];

  /// The chosen ones, in the order of [generos].
  List<String> get selecionados =>
      List<String>.unmodifiable(generos.where(_selecionados.contains));

  bool selecionado(String genero) => _selecionados.contains(genero);

  /// How many are left to reach the suggestion (3). Zero once there.
  int get faltamParaSugerido =>
      (kGenerosSugeridos - _selecionados.length).clamp(0, kGenerosSugeridos);

  bool get podeSalvar => _lido && _selecionados.isNotEmpty && !_salvando && !_pulando;

  /// Clears the previous session **without notifying** (called in `initState`).
  void resetSessao() {
    _sessao++;
    _carga++;
    _uid = null;
    _acesso = AcessoInicial.verificando;
    _limparTela();
  }

  /// Decides between the chips and the home, right after the login.
  ///
  /// - local mark present: home (she already saved or skipped on this device);
  /// - genres saved on the server: home (she chose them on another device);
  /// - nothing: the chips.
  ///
  /// Any failure goes to the home: a taste screen must never lock her out of
  /// the app. Without the mark, the decision is simply made again next login.
  ///
  /// It does not clear the chips: [resetSessao] already did, in the gate's
  /// `initState`, and a screen opened by F5 may be loading them right now.
  Future<void> verificarPrimeiroAcesso(String uid) async {
    final int sessao = ++_sessao;
    _uid = uid;
    _acesso = AcessoInicial.verificando;
    notifyListeners();

    final Result<bool> marca = await _seguro(() => _primeiroAcesso.jaPassou(uid));
    if (sessao != _sessao) return;
    if (marca.valueOrNull ?? false) {
      _acesso = AcessoInicial.liberado;
      notifyListeners();
      return;
    }

    final Result<Preferencias> lidas = await _seguro(_preferencias.ler);
    if (sessao != _sessao) return;

    switch (lidas) {
      case Ok<Preferencias>(:final value):
        _aplicar(value);
        if (value.generos.isEmpty) {
          _acesso = AcessoInicial.escolher;
        } else {
          _acesso = AcessoInicial.liberado;
          // Next login does not need the round trip.
          await _seguro(() => _primeiroAcesso.marcar(uid));
          if (sessao != _sessao) return;
        }
      case Error<Preferencias>(:final error):
        debugPrint('[AppSeries] preferências não lidas no primeiro acesso: $error');
        _acesso = AcessoInicial.liberado;
    }
    notifyListeners();
  }

  /// Loads the saved taste for the screen opened from the home.
  Future<void> carregar() async {
    final int carga = ++_carga;
    _carregando = true;
    _erroCarga = null;
    _erroSalvar = null;
    // Until this read answers, what is on screen may be stale: no saving.
    _lido = false;
    notifyListeners();

    final Result<Preferencias> lidas = await _seguro(_preferencias.ler);
    if (carga != _carga) return;

    switch (lidas) {
      case Ok<Preferencias>(:final value):
        _aplicar(value);
      case Error<Preferencias>(:final error):
        _erroCarga = error.mensagem;
    }
    _carregando = false;
    notifyListeners();
  }

  void alternar(String genero) {
    if (_salvando || _pulando) return;
    if (!_selecionados.remove(genero)) _selecionados.add(genero);
    _erroSalvar = null;
    notifyListeners();
  }

  /// Saves the chosen genres, keeping the moment that was saved before.
  ///
  /// Answers whether it saved, so the screen opened from the home knows to
  /// close. On the first access the gate swaps the screen by itself.
  Future<bool> salvar() async {
    if (!podeSalvar) return false;
    final int sessao = _sessao;
    _salvando = true;
    _erroSalvar = null;
    notifyListeners();

    final Result<Preferencias> salvas = await _seguro(
      () => _preferencias.salvar(Preferencias(momento: _momento, generos: selecionados)),
    );
    if (sessao != _sessao) return false;

    switch (salvas) {
      case Ok<Preferencias>(:final value):
        _aplicar(value);
        await _marcarSessao(sessao);
        if (sessao != _sessao) return false;
        _salvando = false;
        _acesso = AcessoInicial.liberado;
        notifyListeners();
        return true;
      case Error<Preferencias>(:final error):
        _salvando = false;
        _erroSalvar = error.mensagem;
        notifyListeners();
        return false;
    }
  }

  /// Skips the chips: nothing goes to the server (empty genres already mean
  /// "no taste"), only the local mark, so the screen does not come back.
  Future<void> pular() async {
    if (_salvando || _pulando || _acesso != AcessoInicial.escolher) return;
    final int sessao = _sessao;
    _pulando = true;
    notifyListeners();
    await _marcarSessao(sessao);
    if (sessao != _sessao) return;
    _pulando = false;
    _acesso = AcessoInicial.liberado;
    notifyListeners();
  }

  /// A failed mark only costs showing the screen once more: never an error.
  Future<void> _marcarSessao(int sessao) async {
    final String? uid = _uid;
    if (uid == null || sessao != _sessao) return;
    final Result<void> r = await _seguro(() => _primeiroAcesso.marcar(uid));
    if (r.errorOrNull != null) debugPrint('[AppSeries] marca de primeiro acesso não gravada');
  }

  void _aplicar(Preferencias preferencias) {
    _lido = true;
    _momento = preferencias.momento;
    _selecionados
      ..clear()
      ..addAll(preferencias.generos);
  }

  void _limparTela() {
    _carregando = false;
    _erroCarga = null;
    _salvando = false;
    _pulando = false;
    _erroSalvar = null;
    _lido = false;
    _momento = null;
    _selecionados.clear();
  }

  /// A repository answers a `Result`; this guards the day that contract breaks,
  /// so the gate never hangs on the loading screen.
  Future<Result<T>> _seguro<T>(Future<Result<T>> Function() chamada) async {
    try {
      return await chamada();
    } catch (error, stack) {
      debugPrint('[AppSeries] preferências fora do contrato: $error\n$stack');
      return Result<T>.error(const ServerError());
    }
  }
}
