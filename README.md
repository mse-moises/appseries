# AppSeries

App Flutter do trabalho integrado da pós (vale nas disciplinas de **Flutter**, **DevOps**
e **Gestão de Projetos**): catálogo pessoal de séries e filmes com recomendação por IA.

- **Backend**: `https://gdn.vps-kinghost.net` (repo `mse-moises/-pos-backend`) — o app
  fala **só** com ele; chave do TMDB e da IA ficam no servidor
- **Arquitetura**: MVVM (View · ViewModel · Repository · Service) — regras em
  [`constitution.md`](constitution.md)
- **Spec do esqueleto**: [`specs/esqueleto.md`](specs/esqueleto.md)

## Rodar

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # gera os .g.dart
flutter run -d chrome --web-port 8080                      # ou -d <seu-device-android>
```

No web a porta **não é livre**: o backend libera só a origem `http://localhost:8080` no
CORS (`CORS_ORIGINS`). Em outra porta o navegador bloqueia a leitura da resposta e a tela
fica em estado de erro, sem nenhuma pista de que o problema é a origem.

A base URL já vem por padrão em `lib/utils/env.dart` e é **só o host**, sem path: cada
endpoint carrega o seu (`/health`, `/api/v1/...`). Para apontar para outro lugar:

```bash
flutter run -d chrome --web-port 8080 --dart-define=API_BASE_URL=https://outro-host
```

Verificação antes de abrir PR:

```bash
flutter analyze && flutter test
```

## Como criar uma feature nova (7 passos)

A feature de **login** é o molde completo, ponta a ponta. Copie o caminho dela:

1. branch a partir da `main`: `git checkout main && git pull && git checkout -b feature/AP-XX-nome-curto`
2. `<Nome>Service` em `data/services/` — o acesso ao mundo externo, **sem estado**.
   Fala com a API do backend pelo `RestClient`, ou esconde outro provedor (o
   `AuthService` esconde o Firebase Auth): nenhum tipo do provedor passa daqui
3. modelo em `data/api_models/` (`@JsonSerializable()` + `part '<nome>.g.dart';` quando
   vem do backend) e contrato + implementação em `data/repositories/`:
   `<Nome>Repository` (abstrato, devolve `Future<Result<T>>`) e `<Nome>RepositoryImpl`
   (recebe o **Service** e traduz o erro dele em `AppError`)
4. ViewModel em `ui/view_model/<nome>_view_model.dart` (`extends ChangeNotifier`, recebe
   o repository no construtor, tem getters públicos e chama `notifyListeners()`)
5. página + widgets em `ui/view/<nome>_page.dart` (`context.watch` no ViewModel; estado
   efêmero de tela fica na View)
6. **testes por camada** (é critério de aceite, não enfeite): repository com o Service
   dublado, ViewModel com repository falso e o widget test da tela
7. telas internas registram a sua rota em `utils/routes_config.dart` e navegam com
   `Navigator.pushNamed`. **`login` e `home` não são rotas**: quem decide entre elas é o
   `AuthGate` (`app.dart`), pelo estado da sessão

Antes de abrir o PR: `dart run build_runner build --delete-conflicting-outputs` (se mexeu
em DTO ou no `RestClient`), `flutter analyze && flutter test`.

## Fluxo de trabalho

- **Só `main`**: cada pessoa cria a sua branch `feature/<chave-do-Jira>-<nome>` a partir
  da `main` e volta por PR. `main` é a única branch de vida longa
- **PR com 1 review** de outra pessoa (a Definição de Pronto exige item testado por outra
  pessoa)
- commits em inglês, pequenos, um assunto por commit
- `build_runner` antes do commit quando um DTO ou o `RestClient` mudar (os `.g.dart` vão
  no mesmo commit)

## Regras rápidas

- a View **nunca** chama Service e nunca busca dado direto: quem faz é o ViewModel, pelo
  Repository
- mensagem de erro para o usuário **sem termo técnico**
- todo dado vindo do TMDB é exibido com a **atribuição** ("This product uses the TMDB
  API but is not endorsed or certified by TMDB" + logo)
- nenhum segredo no app; o keystore de **release** não entra no repositório (vai por
  segredo de CI)
- o `debug.keystore` **do projeto** (chave de debug, nunca publicada na loja) ainda **não
  existe no repo**: entra na fatia 3, junto com o cadastro da SHA-1 no Firebase. Sem ele,
  cada dev tem a SHA-1 do próprio keystore e o Google Sign-In quebra por máquina
