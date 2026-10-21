/// Por que ela abandonou o título.
///
/// **Não é campo do contrato**: o acervo guarda só o estado. O motivo vira o
/// `peso` do sinal de gosto (`PUT /api/v1/feedback/:tmdbId`, sinal `dislike`,
/// origem `abandono`), que é o que a recomendação lê — peso 1 apenas informa o
/// desinteresse, peso 2 veta o título pra sempre.
///
/// A tradução "qual chip é forte" mora aqui, no app: o servidor valida `1|2` e
/// não infere a intenção (decisão travada do backend).
enum MotivoAbandono {
  /// "Sem tempo": peso fraco, não veta.
  semTempo(1),

  /// "Não gostei": peso forte, veta.
  naoGostei(2);

  const MotivoAbandono(this.peso);

  /// Peso no contrato do feedback: 1 fraco, 2 forte.
  final int peso;
}
