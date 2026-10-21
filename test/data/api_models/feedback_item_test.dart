import 'package:appseries/data/api_models/feedback_item.dart';
import 'package:appseries/data/api_models/marcar_feedback_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeedbackItem.fromJson', () {
    test('lê o item completo do contrato', () {
      final FeedbackItem f = FeedbackItem.fromJson(<String, dynamic>{
        'tmdbId': 1399,
        'sinal': 'dislike',
        'peso': 1,
        'origem': 'abandono',
        'tipo': 'tv',
        'titulo': 'Game of Thrones',
        'ano': '2011',
        'posterPath': '/x.jpg',
        'atualizadoEm': '2026-10-20T12:00:00.000Z',
      });

      expect(f.tmdbId, 1399);
      expect(f.sinal, SinalGosto.dislike);
      expect(f.peso, 1);
      expect(f.origem, OrigemFeedback.abandono);
      expect(f.tipo, TipoMidia.tv);
      expect(f.posterPath, '/x.jpg');
      expect(f.atualizadoEm, isNotNull);
    });

    test('sinal e origem fora do contrato não quebram a lista', () {
      final FeedbackItem f = FeedbackItem.fromJson(<String, dynamic>{
        'tmdbId': 1,
        'sinal': 'love',
        'origem': 'telepatia',
      });

      expect(f.sinal, SinalGosto.desconhecido);
      expect(f.origem, OrigemFeedback.desconhecido);
      expect(f.peso, 2, reason: 'sem peso, o default é forte');
    });
  });

  group('MarcarFeedbackRequest', () {
    test('serializa os valores que o backend conhece', () {
      final Map<String, dynamic> json = const MarcarFeedbackRequest(
        sinal: SinalGosto.dislike,
        tipo: TipoMidia.tv,
        peso: 1,
        origem: OrigemFeedback.abandono,
      ).toJson();

      expect(json, <String, dynamic>{
        'sinal': 'dislike',
        'tipo': 'tv',
        'peso': 1,
        'origem': 'abandono',
      });
    });

    test('default é 👍 forte, na origem de fechamento', () {
      final Map<String, dynamic> json =
          const MarcarFeedbackRequest(sinal: SinalGosto.like, tipo: TipoMidia.movie).toJson();

      expect(json['peso'], 2);
      expect(json['origem'], 'fechamento');
    });
  });
}
