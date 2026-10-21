# Motivo do abandono = peso do feedback (AP-56 / AP-57)

## Objetivo

O card de "abandonei" pede um motivo, e motivo não existia em lugar nenhum do
sistema: o acervo guarda só `{estado, tipo}`, e não há coluna para texto.

A saída escolhida foi a **B**: o motivo não ganha coluna — ele vira o `peso` do
sinal de gosto (`PUT /api/v1/feedback/:tmdbId`, sinal `dislike`, origem
`abandono`), que é o único dado que a recomendação lê. **Zero mudança no
backend**: nenhuma migração, nenhuma rota nova.

Trade-off aceito: o motivo não volta no `GET /acervo`, então a lista mostra só o
estado e o selo "abandonei" (AP-58). E "motivo opcional" vira "dois motivos
fixos".

## Contrato usado (o que já está no ar)

`PUT /api/v1/acervo/:tmdbId` — body `{estado, tipo}`. `dropped` é um dos quatro
estados. `tipo` obrigatório (`400 invalid_tipo`).

`PUT /api/v1/feedback/:tmdbId` — body `{sinal, peso, tipo, origem}`:
`sinal` `like|dislike` e `tipo` `movie|tv` obrigatórios, `peso` `1|2`
(1 fraco, não veta; 2 forte, veta), `origem` `fechamento|detalhe|abandono`.

`GET /api/v1/acervo` — devolve `tmdbId, estado, tipo, titulo, ano, posterPath,
atualizadoEm`. **Não** devolve motivo, por desenho.

## Decisões

| decisão | por quê |
| --- | --- |
| dois motivos fixos, no app | o contrato só carrega `peso 1\|2`; a tradução "qual chip é forte" é do app (decisão travada do backend) |
| "Sem tempo" = 1, "Não gostei" = 2 | o critério do E5: abandono por tempo não veta, "não curti" veta |
| o estado é salvo **no toque**, antes dos chips | AP-57: os chips vêm depois e não seguram a tela; fechar = motivo opcional |
| folha descartável, não diálogo | arrastar, tocar fora ou "Agora não" devolvem `null`; nada trava |
| falha do motivo não desfaz o abandono | duas gravações independentes; o estado é o que a lista mostra. A tela avisa e para |
| falha do acervo impede o motivo | motivo de abandono que não aconteceu não deve vetar o título |

## Arquivos

Nascem:
- `lib/data/api_models/motivo_abandono.dart` — enum com o peso
- `lib/ui/widgets/motivo_abandono.dart` — rótulos e a folha dos chips
- `lib/ui/view_model/marcar_acervo_view_model.dart` — as duas gravações
- `lib/ui/widgets/marcar_acervo_button.dart` — o botão que as telas montam
- testes em `test/ui/view_model/` e `test/ui/widgets/`

Entra:
- `lib/main.dart` — `ChangeNotifierProvider<MarcarAcervoViewModel>`

## Fora desta fatia

- o selo "abandonei" dentro da aba assistido (AP-58) depende da tela do acervo
  (AP-60, ainda stub);
- montar o botão nas telas: home, busca e detalhe são stubs e marcar nos três
  pontos de entrada é de outra trilha. O widget já junta os dois endpoints, então
  a tela só monta `MarcarAcervoButton(tipo:, tmdbId:)`.

## Critério de pronto

- [x] os motivos têm peso 1 e 2 (teste do enum, provado por mutação)
- [x] abandono com motivo grava `dislike` + peso + origem `abandono` (ViewModel e widget)
- [x] fechar os chips mantém o abandono e não grava gosto
- [x] estado que não é abandono não pergunta motivo e não grava gosto
- [x] falha do acervo mostra a frase do erro e não grava motivo
- [x] falha do motivo avisa ("Abandono salvo. O motivo não foi registrado.") sem desfazer
- [x] reentrância: dois toques seguidos viram uma gravação
- [ ] integração nas telas (cards de tela)
- [ ] verificação ao vivo no navegador (depende da integração)
