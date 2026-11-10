import 'package:flutter/material.dart';

import '../../utils/app_error.dart';

bool falhaDeConexao(AppError erro) => erro is NetworkError || erro is TempoEsgotadoError;

void avisarFalha(
  ScaffoldMessengerState aviso, {
  required String prefixo,
  required AppError erro,
  VoidCallback? tentarDeNovo,
}) {
  if (!aviso.mounted) return;
  final bool comRetry = tentarDeNovo != null && falhaDeConexao(erro);
  aviso
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('$prefixo ${erro.mensagem}'),
        action: comRetry ? SnackBarAction(label: 'Tentar de novo', onPressed: tentarDeNovo) : null,
      ),
    );
}
