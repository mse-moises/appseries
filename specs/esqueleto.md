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
- `README` (como rodar + como criar uma feature em 6 passos) e `constitution.md`
- CI: `analyze` + `test` + APK release como artefato (PR) e deploy do web (`main`)
- testes em cada camada do molde: repository (com o `RestClient` dublado) e ViewModel (com
  repository falso), widget tests das telas e o teste da navegação login → home

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
| View | `context.watch` + primeira carga no `create` do provider |
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
3. **Google Sign-In + acabamento** — `debug.keystore` + SHA-1, deploy do web no Hosting,
   domínio autorizado no Auth.

## Critério de pronto

- abre no **Chrome** e no **Android** e mostra a página de login
- cadastro e login por **e-mail/senha** funcionam; a Home casca aparece; **logout** volta
  ao login
- **Google** entra na mesma Home
- login errado mostra frase clara, sem termo técnico
- todos os testes passam e o **CI ficou verde** no PR
- `README` e `constitution.md` estão no repo; o web está publicado com URL
- outra pessoa revisou e rodou

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
