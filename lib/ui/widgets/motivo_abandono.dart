import 'package:flutter/material.dart';

import '../../data/api_models/motivo_abandono.dart';

export '../../data/api_models/motivo_abandono.dart';

/// Rótulo do motivo. Mora ao lado do widget que o mostra, igual a
/// `rotuloEstado`: uma segunda cópia em outra tela envelhece sem aviso.
String rotuloMotivo(MotivoAbandono motivo) => switch (motivo) {
      MotivoAbandono.semTempo => 'Sem tempo',
      MotivoAbandono.naoGostei => 'Não gostei',
    };

/// Abre os chips de motivo e devolve o escolhido, ou `null` se ela fechar.
///
/// Este é o passo **depois** do toque em "Abandonei" (AP-57): o estado já está
/// sendo salvo, e o motivo é opcional. A folha é descartável de propósito —
/// arrastar, tocar fora ou "Agora não" devolvem `null` e não desfazem o
/// abandono, nem seguram a tela.
Future<MotivoAbandono?> perguntarMotivoAbandono(BuildContext context) {
  return showModalBottomSheet<MotivoAbandono>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext context) => const _MotivoAbandonoSheet(),
  );
}

class _MotivoAbandonoSheet extends StatelessWidget {
  const _MotivoAbandonoSheet();

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Por que você abandonou?', style: tema.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Opcional: ajuda a recomendar melhor.',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final MotivoAbandono motivo in MotivoAbandono.values)
                  ActionChip(
                    key: Key('motivo-${motivo.name}'),
                    label: Text(rotuloMotivo(motivo)),
                    onPressed: () => Navigator.of(context).pop(motivo),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('motivo-agora-nao'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Agora não'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
