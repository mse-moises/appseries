# Spec — Esqueleto do app + login

> Item do Jira: **E0 — Fundação técnica, item 1** ("estrutura do app Flutter: MVVM,
> navegação, tema, lint") e **E1 — Conta e acesso** (Sprint 1).
> Decisões de origem: grill de 13–14/10/2026 (`hermes-home/projetos/pos-flutter/CONTEXTO.md`).
> Regras gerais: `constitution.md`.

## Objetivo

Deixar o app **navegável, com a arquitetura no lugar e o login funcionando ponta a
ponta** contra o backend próprio, de forma que cada item seguinte do backlog seja
"preencher o molde": toda feature nova se escreve **copiando a de login**.

O critério de sucesso **não é "existe"**: é servir de exemplo completo a ser copiado
pelas outras quatro pessoas do time.

## Escopo

- estrutura de pastas, `analysis_options.yaml`, tema (Material 3), rotas nomeadas e
  `AuthGate` na raiz
- **login e-mail/senha + Google** e logout, com sessão persistida pelo Firebase
- camada de rede: `retrofit` + `dio` com interceptor do token, `Result` + `AppError`
- `README` (como rodar + como criar uma feature em 7 passos) e `constitution.md`
- CI: `analyze` + `test` (+ cobertura) e APK release como artefato no PR; o **deploy do
  web no Hosting é da fatia 3** (a esteira ainda não tem job de deploy)
- testes em cada camada do molde: repository (com o **Service** dublado — o `RestClient`
  para as features de backend, o `AuthService` para a de login) e ViewModel (com repository
  falso), widget tests das telas, o teste do `AuthGate` (a troca de tela vem do estado da
  sessão, não de navegação) e o do interceptor do token (token por requisição e 401 desloga)

## Fora de escopo (tem item e dono no Jira)

acervo, busca, detalhe, preferências, recomendação, feedback. Cada um nasce copiando o
molde; a spec de cada feature fica com quem pegar a task.

## Decisões travadas

| tema | decisão |
|---|---|
| estado/DI | `provider` + `ChangeNotifier`, sem `get_it` |
| API | `retrofit` + `json_serializable` + `build_runner`; `dio` por baixo |
| token | interceptor lê `getIdToken()` **a cada requisição**; **401 desloga** |
| base URL | `--dart-define=API_BASE_URL`, default `https://gdn.vps-kinghost.net` |
| navegação | rotas nomeadas (`utils/routes_config.dart`) + `AuthGate` |
| repository | contrato abstrato + `<Feature>RepositoryImpl` |
| erro | `Result<T>` + `sealed AppError` (código cru + frase em pt-BR) |
| View | `context.watch` + primeira carga no `initState` da tela (não no `create`) |
| plataformas | Android + Web (alvo). As pastas `ios/`, `macos/`, `linux/` e `windows/`
continuam no repo por decisão do dono (14/10) |
| identidade | AppSeries · `br.com.appseries.app` · repo/pasta `appseries` |

## Contrato do backend (o que já existe)

Prefixo das rotas: `/api/v1` (o `GET /health` fica **fora** dele).
Auth: `Authorization: Bearer <id token do Firebase>`.
O app usa como base **só o host** (`lib/utils/env.dart` → `https://gdn.vps-kinghost.net`) e
cada endpoint carrega o path completo: pôr `/api/v1` na base duplica o prefixo.

| rota | o que devolve |
|---|---|
| `GET /health` | `{ "status": "ok" }` (sem auth) |
| `GET /acervo` | lista de `{ tmdbId, estado, atualizadoEm }` |
| `PUT /acervo/:tmdbId` | `{ estado }` → 201 na criação, 200 no update |
| `DELETE /acervo/:tmdbId` | 204 (404 se não existe) |
| `GET /busca?q=` | `{ resultados: [ { id, tipo, titulo, ano, posterPath } ] }` (mín. 3 chars) |
| `GET /titulos/:tmdbId?tipo=movie\|tv` | a ficha (+ `sinopse`, `nota`, `generos`) |
| `GET`/`PUT /preferencias` | `{ momento, generos }` |
| `POST /rec` | `{ cartas: [...], origem }` (teto de 20/dia por usuária) |

Erros sempre em `{ "error": "<codigo>" }` (`unauthorized`, `invalid_estado`, `not_found`,
`rec_limit`, `tmdb_error`, …) — é essa string que vira `AppError`.

**Ainda não existe no backend** (e o app esbarra): rota de "em alta" (o cliente TMDB do
backend já tem `trending()`), o 4º estado do acervo (`dropped` / abandonei) e o
enriquecimento do `GET /acervo` com título/pôster.

## Fatias (cada uma um PR)

1. **Esqueleto navegável** — estrutura, tema, rotas, `README` + `constitution`, CI verde.
   ✅ **Entregue e mergeada em 14/10** (PR #1, merge `e317b53`, 23 commits preservados sem
   squash, CI verde na `main`). Ficou **sem o `AuthGate`**: ele depende do Firebase Auth,
   e o console do Firebase só foi registrado no fim do dia (ver "Dependências do dono"). A primeira carga do app
   ficou na rota `/login`, que navega para `/home`; o `AuthGate` entra na fatia 2, junto
   com o Firebase. Também ficou sem o deploy do web no Hosting, pela mesma razão.
2. **Login e-mail/senha** ponta a ponta — página, ViewModel, `AuthRepository(Impl)`,
   `AppError`, os testes da feature, o `AuthGate` e o interceptor do token.
   ✅ **Entregue, revisada em 6 ondas e mergeada em 16/10** (PR #2, merge `a11a67f`;
   109 testes verdes, CI verde nos 3 jobs).
3. **Google Sign-In + acabamento** — `debug.keystore` + SHA-1, deploy do web no Hosting,
   domínio autorizado no Auth.
   🟡 **Em andamento (17/10)**: chaveiro compartilhado, SHA-1 cadastrada, plugin
   `google-services` e o fluxo de login no código (Android pelo `google_sign_in`, web pelo
   popup do Firebase). Falta a validação do dono num aparelho, o deploy e o CORS da origem
   publicada no backend.

## Casos de aceite da fatia 2 (login e-mail/senha)

O que a tela faz em cada caminho. A "validação local" nem chega ao Firebase.

**Sucesso**

| caso | o que acontece |
|---|---|
| criar conta (e-mail inédito + senha de 6+) | cria no Firebase e entra direto na home |
| entrar com e-mail e senha corretos | vai para a home |
| abrir o app com sessão viva | vai direto para a home, sem passar pelo login |
| sair | limpa a sessão e volta ao login |
| a API responder **401** | desloga e volta ao login (interceptor do dio) |

**Erro**

| caso | frase na tela |
|---|---|
| e-mail vazio · sem `@` · senha com menos de 6 (validação local) | "Informe o e-mail" · "Confira o e-mail digitado" · "A senha precisa ter 6 caracteres ou mais" |
| e-mail inexistente **ou** senha errada | "E-mail ou senha incorretos. Confira e tente de novo." |
| cadastro com e-mail já usado | "Esse e-mail já tem conta. Tente entrar." |
| senha fraca no cadastro | "A senha precisa ter pelo menos 6 caracteres." |
| muitas tentativas seguidas | "Muitas tentativas seguidas. Espere um pouco." |
| conta desativada no console | "Essa conta está desativada." |
| a sessão acaba sozinha (401, canal que cai) | "Sua sessão expirou. Entre de novo." (aviso na tela de login) |
| falha ao sair da conta | a frase do erro, numa faixa na home, com o botão "Fechar" |
| sem rede / Firebase fora do ar | "Sem conexão com a internet. Confira sua rede e tente de novo." |
| provedor que não responde dentro do tempo limite | "Demorou demais para responder. Tente de novo." |
| erro não previsto (provedor desligado, erro interno) | "O servidor deu uma escorregada. Tente em instantes." |

O e-mail inexistente e a senha errada devolvem **a mesma frase de propósito**: o
Firebase responde igual nos dois casos para não revelar quais e-mails têm conta.

**Fora desta fatia** (não existe ainda): "esqueci minha senha", trocar senha ou
e-mail, excluir conta, verificação de e-mail e Google Sign-In (esse é a fatia 3).

## Casos de aceite da fatia 3 (Google)

**Como o app assina (a parte que quebra na máquina dos colegas)**

O Android assina com o `android/app/debug.keystore` **versionado no repo**, apontado em
`signingConfigs.debug` — senha e alias são os padrões públicos de debug do Android, não
segredo. A SHA-1 dessa chave (`44:0E:30:FB:AC:A8:C0:24:B1:FF:96:65:3D:C2:F4:90:7A:AC:99:A2`)
está cadastrada no app Android do Firebase, e o plugin `com.google.gms.google-services`
(4.4.4) é quem injeta o cliente OAuth no build. Sem os três, o Google responde
`ApiException: 10`, que não diz nada a quem lê.

**O que a tela faz**

| caso | o que acontece |
|---|---|
| tocar em "Entrar com Google" no Android | abre o seletor de contas; escolher uma conta entra na home |
| tocar em "Entrar com Google" na web | abre a janela do Google; concluir entra na home |
| fechar o seletor ou a janela | "Entrada com o Google cancelada." |
| e-mail que já tem conta com senha | "Esse e-mail já tem conta com senha. Entre com a sua senha." |
| ambiente sem suporte (navegador embutido) | "Entrar com o Google não está disponível aqui. Use e-mail e senha." |
| janela bloqueada pelo navegador | "O navegador bloqueou a janela do Google. Libere as janelas pop-up e tente de novo." |
| configuração, interrupção ou queda sem código | "Não deu para entrar com o Google. Tente de novo." |

O botão do Google **não passa pela validação do formulário** (e-mail e senha são do outro
caminho) e desliga junto com os campos enquanto a requisição está em voo.

## Critério de pronto

**Da fatia 2 (login e-mail/senha)** — é o que se confere neste PR:

- abre no **Chrome** e mostra a página de login (o Android depende de um aparelho ligado:
  o CI compila o APK, não o executa)
- cadastro e login por **e-mail/senha** funcionam; a Home casca aparece; **logout** volta
  ao login
- abrir o app com sessão viva vai direto à home, sem passar pelo login
- login errado mostra frase clara, sem termo técnico
- todos os testes passam e o **CI ficou verde** no PR
- outra pessoa revisou

**Da fatia 3 e do fecho do E1** — ainda não é para estar pronto:

- **Google** entra na mesma Home
- o web está publicado com URL (Hosting)

## Como verificar (comandos)

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter run -d chrome --web-port 8080   # 8080 é a origem liberada no CORS do backend
```

## Dependências do dono (o agente não faz)

- ✅ **console do Firebase `pos-app-c4297`** (feito em 14/10): apps **web** (`pos-web-api`) e
  **android** (`br.com.appseries.app`) registrados, e-mail/senha e Google habilitados, a
  SHA-1 do keystore de debug cadastrada, `google-services.json` versionado e os domínios
  do Hosting autorizados
- ✅ **repo renomeado** para `mse-moises/appseries` e **token novo do Jira** trocado (14/10)
- **renomear a pasta local** `projects/pos/pos_app_filmes` → `appseries` (o `flutter run`
  segura a pasta; exige o processo parado)
- **convidar os 4 colegas** como colaboradores e **publicar o web no Hosting** (site já
  provisionado, sem deploy: entra na fatia 3)
