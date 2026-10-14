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
- 3 testes: ViewModel (repository falso), `AuthRepositoryImpl` (`RestClient` dublado) e
  widget test da página de login

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
| plataformas | Android + Web |
| identidade | AppSeries · `br.com.appseries.app` · repo/pasta `appseries` |

## Contrato do backend (o que já existe)

Base: `https://gdn.vps-kinghost.net/api/v1` · auth: `Authorization: Bearer <idToken>`

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

1. **Esqueleto navegável** — estrutura, tema, rotas, `AuthGate` com Home casca,
   `README` + `constitution`, CI verde.
2. **Login e-mail/senha** ponta a ponta — página, ViewModel, `AuthRepository(Impl)`,
   `AppError`, os 3 testes.
3. **Google Sign-In + acabamento** — `debug.keystore` + SHA-1, deploy do web, domínio
   autorizado no Auth.

## Critério de pronto

- abre no **Chrome** e no **Android** e mostra a página de login
- cadastro e login por **e-mail/senha** funcionam; a Home casca aparece; **logout** volta
  ao login
- **Google** entra na mesma Home
- login errado mostra frase clara, sem termo técnico
- os 3 testes passam e o **CI ficou verde** no PR
- `README` e `constitution.md` estão no repo; o web está publicado com URL
- outra pessoa revisou e rodou

## Como verificar (comandos)

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter run -d chrome
```

## Dependências do dono (o agente não faz)

- console do **Firebase** `pos-app-c4297`: registrar os apps android + web, habilitar
  e-mail/senha e Google, colar a SHA-1 do `debug.keystore`, autorizar o domínio do Hosting
- **renomear** o repo no GitHub e a pasta local para `appseries`
- **token novo do Jira** (o atual responde 401) — sem ele não dá pra nomear branch com a
  chave do item nem atualizar as horas do E0/E1
