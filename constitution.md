# Constitution — AppSeries

> Regras que valem para **todo** trabalho neste repositório. Cada spec referencia este
> arquivo e só acrescenta o que é específico daquela feature.
> Origem das decisões: grill de 13–14/10/2026 (`hermes-home/projetos/pos-flutter/CONTEXTO.md`).

## 1. Arquitetura (MVVM — é critério de avaliação da disciplina)

- Camadas e sentido único: **View → ViewModel → Repository → Service**. A View **nunca**
  chama Service, e ninguém pula camada.
- `ViewModel` é `ChangeNotifier` e é dono do **estado da tela** (dados, carregando, erro).
- `Repository` é **contrato abstrato** (`<Feature>Repository`) + implementação
  (`<Feature>RepositoryImpl`). O ViewModel depende do contrato.
- `Service` é o acesso ao mundo externo (retrofit/`RestClient`, Firebase Auth) e **não
  tem estado**.
- O que só existe porque a tela existe (foco, `TextEditingController`, animação) fica na
  **View**. "Quem está logado" é estado de **app**: `AuthViewModel` na raiz, observado
  pelo `AuthGate`.
- A View pega o ViewModel com `context.watch<...>()`; a **primeira carga** acontece no
  `create` do provider (`..carregar()`). **Nunca** disparar carga dentro do `build()`.

## 2. Estrutura de pastas (por tipo, como o desenho da aula)

```
lib/
├── main.dart              # MultiProvider (a injeção) + runApp
├── app.dart               # MaterialApp: tema, rotas, AuthGate
├── data/
│   ├── api_models/        # DTOs (um por recurso do backend) + .g.dart
│   ├── repositories/      # <Feature>Repository (abstrato) + <Feature>RepositoryImpl
│   └── services/          # rest_client.dart (retrofit), auth_service.dart
├── ui/
│   ├── view/              # <feature>_page.dart
│   ├── view_model/        # <feature>_view_model.dart
│   ├── theme/             # app_theme.dart
│   └── widgets/           # componentes reutilizáveis (campo, botão, estado vazio/erro)
└── utils/                 # result.dart, app_error.dart, routes_config.dart, env.dart
```

Toda feature nova nasce **copiando a de login**: `<f>_view_model.dart` em
`ui/view_model/`, `<f>_page.dart` em `ui/view/`, `<F>Repository` + `<F>RepositoryImpl`
em `data/repositories/` e o DTO em `data/api_models/`. Sem pasta por feature.

## 3. `Result` e erro

- Todo método de repository devolve `Future<Result<T>>` (`utils/result.dart`).
- Erro é **tipado**: `AppError` (`utils/app_error.dart`), um caso por família
  (`Network`, `Unauthorized`, `NotFound`, `Conflict`, `RateLimit`, `Server`), carregando
  o **código cru** que o backend devolveu (para log) e a **frase em português** que a
  tela mostra. Nunca jogar `Exception` genérica na tela.
- Mensagem para o usuário **sem termo técnico** ("e-mail ou senha inválidos", não
  "401 unauthorized").

## 4. Política de erro (para quem mexe no código)

1. **Nunca corrigir às cegas**: primeiro reproduza e instrumente o que revela a causa
   (log, valor, caminho). Leia o log, entenda, e só então corrija.
2. Correção **mínima**: mexer só no que a causa exige e conferir que nada mais mudou.
3. Depois de corrigir, **rode de novo** e confirme o critério de pronto.
4. Log inconclusivo → repetir diagnosticar → corrigir → verificar. Não avançar no escuro.
5. Limites: no máximo **10 tentativas** na mesma tarefa; ao esgotar, parar e reportar o
   melhor resultado parcial + o que foi diagnosticado.

## 5. Fluxo de trabalho (git)

- **Uma branch de vida longa só: `main`.** Cada feature nasce da `main`
  (`feature/<chave-do-Jira>-<nome>`) e volta por PR. Nada de push direto na `main`:
  o merge é sempre por PR.
- PR com **1 review de outra pessoa** (cumpre o "testado por outra pessoa" da Definição
  de Pronto).
- Commits **em inglês**, pequenos, **um assunto por commit** (`feat:`, `fix:`, `docs:`,
  `test:`, `chore:`).
- `dart run build_runner build --delete-conflicting-outputs` **antes do commit** sempre
  que um DTO ou o `RestClient` mudar; os `.g.dart` vão no mesmo commit. Esquecer isso dá
  erro de compilação confuso (`part of` sem o arquivo gerado).

## 6. Definição de Pronto

Um item só está pronto quando:

- `flutter analyze` sem nenhum issue e `flutter test` verde (e o CI passou no PR)
- o critério de aceite do item do Jira foi conferido na tela, não só no teste
- **outra pessoa** revisou e rodou
- nada que já funcionava quebrou
- as horas restantes foram atualizadas no item do Jira

## 7. Invariantes de segurança

- **Nenhum segredo no app**: chave do TMDB, chave da IA e credenciais de banco vivem só
  no backend (`.env` do servidor). O app conversa **só** com o backend próprio.
- A `baseUrl` vem por `--dart-define`, não hardcoded.
- `debug.keystore` **do projeto** será versionado (é chave de debug: não publica na loja),
  e ainda **não existe no repo**: nasce na fatia 3, junto com a SHA-1 cadastrada no
  Firebase. Keystore de **release** não entra no repositório, vai por segredo de CI.
- `google-services.json` e `firebase_options.dart` são versionados (a config do Firebase
  é pública por natureza); qualquer outro `.json` de credencial, não.
- Comando destrutivo (`push --force`, `rm -rf` em pasta do projeto, `drop`) só com OK
  humano explícito.
