import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_model/preferences_view_model.dart';
import '../widgets/genero_chip.dart';
import '../widgets/status_view.dart';

/// "O que eu gosto": genre chips (AP-38).
///
/// Two ways in:
/// - [primeiroAcesso]: shown by the `AuthGate` after the first login, with
///   "Pular". The gate already read the server, so the screen does not load,
///   and saving or skipping swaps it for the home by itself;
/// - the `/preferencias` route, from the home: loads what is saved and closes
///   after saving.
class PreferencesPage extends StatefulWidget {
  const PreferencesPage({super.key, this.primeiroAcesso = false});

  final bool primeiroAcesso;

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  @override
  void initState() {
    super.initState();
    if (widget.primeiroAcesso) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PreferencesViewModel>().carregar();
    });
  }

  Future<void> _salvar(PreferencesViewModel vm) async {
    final bool salvou = await vm.salvar();
    if (!salvou || !mounted || widget.primeiroAcesso) return;
    final ScaffoldMessengerState mensagens = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    mensagens.showSnackBar(const SnackBar(content: Text('Seus gostos foram salvos.')));
  }

  @override
  Widget build(BuildContext context) {
    final PreferencesViewModel vm = context.watch<PreferencesViewModel>();
    final bool primeiro = widget.primeiroAcesso;

    final Widget corpo;
    if (vm.carregando) {
      corpo = const LoadingView();
    } else if (vm.erroCarga != null) {
      corpo = ErrorView(mensagem: vm.erroCarga!, onRetry: vm.carregar);
    } else {
      corpo = _Chips(vm: vm, primeiroAcesso: primeiro);
    }

    final bool mostraBotao = !vm.carregando && vm.erroCarga == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(primeiro ? 'Do que você gosta?' : 'O que eu gosto'),
        automaticallyImplyLeading: !primeiro,
        actions: <Widget>[
          if (primeiro)
            TextButton(
              key: const Key('preferencias-pular'),
              onPressed: vm.salvando || vm.pulando ? null : vm.pular,
              child: vm.pulando
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Pular'),
            ),
        ],
      ),
      body: corpo,
      bottomNavigationBar: mostraBotao
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton(
                  key: const Key('preferencias-salvar'),
                  onPressed: vm.podeSalvar ? () => _salvar(vm) : null,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: vm.salvando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(primeiro ? 'Continuar' : 'Salvar'),
                ),
              ),
            )
          : null,
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({required this.vm, required this.primeiroAcesso});

  final PreferencesViewModel vm;
  final bool primeiroAcesso;

  @override
  Widget build(BuildContext context) {
    final TextTheme texto = Theme.of(context).textTheme;
    final ColorScheme cores = Theme.of(context).colorScheme;
    final int escolhidos = vm.selecionados.length;
    final int faltam = vm.faltamParaSugerido;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        Text(
          primeiroAcesso
              ? 'Escolha os gêneros que você curte. Sua primeira sugestão parte daqui.'
              : 'Os gêneros que você curte entram nas suas sugestões.',
          style: texto.bodyLarge,
        ),
        const SizedBox(height: 8),
        Text(
          faltam > 0
              ? 'Escolha pelo menos $kGenerosSugeridos para acertar mais '
                  '(${faltam == 1 ? 'falta 1' : 'faltam $faltam'}).'
              : '$escolhidos gêneros escolhidos.',
          key: const Key('preferencias-contagem'),
          style: texto.bodySmall?.copyWith(color: cores.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final String genero in vm.generos)
              GeneroChip(
                key: ValueKey<String>('genero-$genero'),
                genero: genero,
                selecionado: vm.selecionado(genero),
                onTap: vm.salvando || vm.pulando ? null : () => vm.alternar(genero),
              ),
          ],
        ),
        if (vm.erroSalvar != null) ...<Widget>[
          const SizedBox(height: 16),
          Text(vm.erroSalvar!, style: texto.bodyMedium?.copyWith(color: cores.error)),
        ],
      ],
    );
  }
}
