# Tutorial: motivo do abandono (AP-56 / AP-57)

> O código é a verdade. Se este texto divergir de `lib/`, vale o arquivo.
>
> Feature de uma gravação que virou duas: o estado do acervo e o motivo. Serve
> de exemplo de "um toque, duas chamadas, nenhuma travando a tela".

## O problema em uma frase

O card pedia um motivo que não existia no banco. Em vez de criar coluna, o
motivo passou a ser o **peso** do 👍/👎, que a recomendação já lê.

## Passo 1 — o modelo: enum com o peso

`lib/data/api_models/motivo_abandono.dart`

```dart
enum MotivoAbandono {
  semTempo(1),
  naoGostei(2);

  const MotivoAbandono(this.peso);
  final int peso;
}
```

Por que essa camada existe: o peso é contrato (`1|2`), não decoração de tela.
Quem traduz "esse chip é forte" é o app — o servidor valida o número e não infere
a intenção.

Como conferir: `test/ui/view_model/marcar_acervo_view_model_test.dart` asserta
`semTempo.peso == 1` e `naoGostei.peso == 2`. Erro comum: trocar os pesos e o
teste de fluxo passar (ele asserta o peso enviado, não só o enum).

## Passo 2 — o ViewModel: duas gravações independentes

`lib/ui/view_model/marcar_acervo_view_model.dart`

```dart
final Future<bool> acervoSalvo = marcarVm.marcarAcervo(tipo, id, estado);
```

- `marcarAcervo` grava o estado e devolve `false` em falha (com a frase em
  `erro`) ou em reentrância (silencioso).
- `registrarMotivo` só grava o gosto; se falhar, marca `motivoNaoRegistrado` e
  **não** mexe no abandono.

Por que dois métodos: o abandono vale por si. Um motivo que não gravou não pode
desfazer o estado nem prender a tela.

Erro comum: capturar só `on Exception`. O contrato do repositório é devolver
`Result`, mas um `StateError` (que é `Error`) escaparia e deixaria `salvando`
preso — por isso o `catch` é largo.

## Passo 3 — a folha: motivo é opcional

`lib/ui/widgets/motivo_abandono.dart`

```dart
Future<MotivoAbandono?> perguntarMotivoAbandono(BuildContext context)
```

`showModalBottomSheet` devolve `null` quando ela fecha de qualquer jeito (arrasta,
toca fora, "Agora não"). É o que faz "motivo opcional" ser verdade sem bloquear.

Erro comum: usar `showDialog`. Diálogo trava a tela e não combina com "os chips
aparecem depois do toque e não travam a tela" (AP-57).

## Passo 4 — o botão que as telas montam

`lib/ui/widgets/marcar_acervo_button.dart`

```dart
await tester.tap(find.text('Marcar'));
```

A ordem importa e é o coração do fluxo:

1. dispara a gravação do estado (o toque já vale);
2. se o estado é `dropped`, abre os chips **sem esperar a rede**;
3. espera a gravação do estado;
4. só se ela deu certo e houve motivo, grava o feedback;
5. recarrega o `AcervoViewModel` para o rótulo e o selo refletirem o servidor.

Erro comum: `await marcarAcervo(...)` antes de abrir a folha. Aí o motivo passa a
esperar a rede e o toque fica lento por um dado opcional.

## Passo 5 — a tela

```dart
MarcarAcervoButton(tipo: TipoMidia.movie, tmdbId: 550)
```

A tela não salva nada: o widget lê `AcervoViewModel` e `MarcarAcervoViewModel` do
provider. O par `(tipo, tmdbId)` é obrigatório — id sozinho é ambíguo entre filme
e série.

## Diário

| o que entrou | o que aprendi |
| --- | --- |
| enum `MotivoAbandono` com peso | a força do sinal é do app; o servidor só valida `1\|2` |
| `MarcarAcervoViewModel` com dois métodos | duas gravações independentes: falha do motivo não desfaz o estado |
| folha descartável (`null` = opcional) | "não travar a tela" é escolha de widget, não de texto |
| `MarcarAcervoButton` | o toque salva antes dos chips; o motivo nunca segura o abandono |
| 16 testes novos | peso e origem provados por mutação (trocar 1↔2 e `abandono`→`fechamento` derrubam 2 e 3 testes) |
