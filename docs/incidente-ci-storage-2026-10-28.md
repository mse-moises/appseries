# Incidente: storage do Actions travou o CI e o deploy do web (28/10/2026)

**Status (02/11):** **cota resolvida e provada** — fix em `29df15b`, PR #21, merge `49e4f7f`. O `analyze + test`,
`build APK` e `build web` voltaram a ficar verdes nos 6 PRs abertos (#15 a #20). O que ainda falha é o
`deploy web`, por **outro motivo**: 403 `serviceusage.services.get` na service account (ver "Segundo bloqueio" abaixo).
**Status (28/10):** resolvido por fora do CI (deploy manual).
**Afetou:** `main` (`6b377cd` e `4274d38`) — `build APK`, `build web` e `deploy web`.
**Não afetou:** código, testes, backend, app rodando local.

---

## Fecho de 02/11 (segundo bloqueio: IAM do deploy)

A franquia virou o mês e a cota está livre (medido: **66 MB de artifacts, 0 caches**). Com o `ci.yml` corrigido
e mergeado, os três jobs de verificação ficam verdes — o bug de cota está fechado.

O `deploy web` na `main` ainda falha, agora com **403 em `serviceusage.services.get`** no projeto
`238916672789` (`firebasehosting.googleapis.com`). É IAM, não cota: a service account de
`secrets.FIREBASE_SERVICE_ACCOUNT` não tem permissão de leitura em Service Usage. Conserto é **console**:
Google Cloud → IAM → a service account do secret → adicionar `Service Usage Viewer`
(`roles/serviceusage.serviceUsageViewer`) e conferir se `firebasehosting.googleapis.com` está habilitada no projeto.
Enquanto isso, o site continua no build de **29/10** (deploy manual do dono, `main.dart.js` com
`Last-Modified: 29 Oct 2026`) e o `deploy web` do CI é vermelho a cada merge na `main`.


---

## Resumo em três linhas

1. Os PRs #13 e #14 foram revisados, mesclados e estão na `main`; `flutter test` local: **378/378**.
2. O `deploy web` não rodou porque o **storage de artefatos do Actions estourou** (500 MB do plano Free,
   medidos em **GB-hora ao longo do mês**) — e com os budgets em **$0 / "Usage blocked"** o excedente é
   **bloqueado**, não cobrado.
3. O site foi publicado **manualmente** com `flutter build web` + `firebase deploy` (usa o login do dono,
   não o service account do CI), e o `ci.yml` foi corrigido num branch para não repetir.

---

## Linha do tempo

| hora | o que aconteceu |
|---|---|
| ~19:20 | #13 mesclado (`6b377cd`). `analyze + test`, `build APK` e `build web` verdes; **`deploy web` falhou com 403** (`serviceusage.services.get` em `firebasehosting.googleapis.com`, service account). |
| ~19:34 | #14 mesclado (`4274d38`). No run da `main`, `build APK` e `build web` falharam em **`Sobe o artefato`** com `Failed to CreateArtifact: Artifact storage quota has been hit`. Sem eles, `deploy web` fica `skipped`. |
| 19:5x–20:4x | Limpeza: **249 artefatos apagados (~2,64 GB)** e **2 caches (1,51 GB + 53 MB)**. Storage visível caiu para **67 MB / 0 caches**. |
| 20:2x–21:0x | **4 tentativas de re-run**: todas falharam no mesmo ponto. `analyze + test` sempre verde (o artefato `cobertura`, sub-MB, era criado; APK 23 MB e web 10 MB não). |
| ~21:0x | Deploy manual: `flutter build web` (41 MB) + `firebase deploy --only hosting --project pos-app-c4297` → **38 arquivos, release complete**. |
| ~21:06 | Confirmado por API: canal `live` com release em `2026-10-28 21:06:03`. |

---

## Causa raiz

1. **O plano é GitHub Free:** 500 MB de storage de Actions. O repositório é **privado**, então a cota vale.
2. **A cota é medida em GB-hora ao longo do mês**, não como foto do momento. Os ~2,6 GB que ficaram
   guardados por semanas consumiram a franquia do mês inteiro; apagar hoje **não devolve** o que já foi
   consumido.
3. **Os budgets estão todos em `$0,00` com "Usage blocked"** (Codespaces, Packages, Actions, Git LFS,
   AI Credit). Ou seja: excedente não é faturado, é **recusado**. Daí o erro em `CreateArtifact`.
4. **A mensagem completa do GitHub** (que a action corta no log) é:
   `... Unable to upload any new artifacts. Usage is recalculated every 6-12 hours.`
   O medidor só reconcilia a cada 6–12 h — por isso apagar não libera na hora.

### O que alimentava o consumo

| item | tamanho | observação |
|---|---|---|
| cache do SDK do Flutter (`subosito/flutter-action` com `cache: true`, em 3 jobs) | **1,5 GB** | sozinho já estoura os 500 MB |
| APK por execução | ~23 MB | subia em **todo** push de PR |
| web por execução | ~10 MB | subia em todo push de PR |
| retenção padrão | **90 dias** | nada expirava |
| cache do pub | 53 MB | menor, mas contava |

Resultado: ~2,6 GB acumulados em duas semanas, franquia de 500 MB consumida, upload bloqueado.

---

## Hipótese que estava errada (registro para não repetir)

Cheguei a supor **"~430 MB de storage invisível"** (artefatos de backend antigo/órfãos), porque as APIs
mostravam 67 MB e o painel dizia 0,5 GB. **Não era isso:** o painel estava mostrando consumo do mês
(GB-hora) e o medidor não havia reconciliado. A hipótese foi derrubada pela pesquisa (documentação do
GitHub + casos na comunidade), não por mais tentativas.

---

## O que resolveu agora

```bash
# no clone, já na main
flutter build web                                  # 41 MB em build/web
firebase login --reauth                            # OAuth normal; o fluxo auth.firebase.tools falhou
firebase deploy --only hosting --project pos-app-c4297
```

Por que funcionou onde o CI falhava: **não usa o Actions** (sem cota de artefato) e **não usa o service
account** (usa a credencial do dono), então também dribla o 403 do IAM.

Verificação sem depender da rede local: `firebase hosting:channel:list` mostra o release mais recente do
canal `live`. `curl` no domínio **não** serve como prova aqui — ver "rede" abaixo.

---

## Pendências

- [ ] **Reset da franquia (previsto 01/11):** rodar o CI uma vez para confirmar que `build APK`, `build web`
      e `deploy web` voltam a passar.
- [ ] **403 do service account** (`FIREBASE_SERVICE_ACCOUNT`): ainda não re-testado (o `deploy web` nunca
      chegou a rodar depois da falha de cota). Se voltar, é permissão no GCP/Firebase, não código.
- [ ] **PR do `ci.yml`** preparado no branch `chore/ci-artifact-storage` (ver abaixo).
- [ ] **Limpeza periódica**: sem `retention-days`, o problema volta em qualquer projeto com build grande.

---

## Correção do `ci.yml` (branch `chore/ci-artifact-storage`)

| mudança | antes | depois |
|---|---|---|
| cache do SDK Flutter (3 jobs) | `cache: true` | **`cache: false`** (−1,5 GB) |
| artefato do APK | sem retenção (90 d), todo push | **`retention-days: 1`**, só em push na `main` |
| artefato do web | sem retenção, todo push | **`retention-days: 1`**, só em push na `main` |
| cobertura | sem retenção | `retention-days: 3` (sempre) |

Efeito esperado: de ~2,6 GB acumulados para **dezenas de MB por merge**, com expiração em 24 h.
Custo: ~40 s de download do SDK por job.

---

## Lições

1. **Artefato e cache contam na mesma cota de 500 MB** — e em GB-hora. Cache de SDK de 1,5 GB não cabe,
   não importa quão "grátis" o cache pareça.
2. **Medidor e bloqueio não são instantâneos**: 6–12 h de recálculo. Apagar e re-rodar em seguida só
   queima minutos da cota de Actions (cada tentativa aqui custou ~16 min).
3. **`[erro]` no último passo do job** (`Sobe o artefato`) com tudo antes verde é o sintoma clássico; o
   `deploy web` fica `skipped` e o site continua no ar **com a versão antiga**, sem aviso.
4. **Verificar deploy pela API** (`firebase hosting:channel:list`), não por `curl` na máquina do dono: esta
   rede não alcançava `199.36.158.100` (TCP 443/80 e ICMP morriam, `google.com` respondia) — bloqueio de
   roteador/ISP, nada a ver com o site.
5. **PR empilhado:** ao mesclar o de baixo, **troque a base do de cima para `main` antes** de apagar o
   branch. Apagar primeiro faz o GitHub **fechar** o PR de cima (aconteceu com o #14; recuperado
   recriando o branch no commit antigo e reabrindo o PR).

---

## Comandos de diagnóstico (reaproveitáveis)

```bash
# quem está consumindo artefatos / cache
gh api "repos/OWNER/REPO/actions/artifacts?per_page=100" --paginate \
  --jq '.artifacts[] | "\(.size_in_bytes/1048576|floor) MB \(.created_at[0:10]) \(.name) exp=\(.expired)"'
gh api repos/OWNER/REPO/actions/cache/usage          # autoritativo, inclui cache que a lista esconde

# por que o job falhou (a anotação tem a mensagem inteira)
gh api "repos/OWNER/REPO/commits/<sha>/check-runs?per_page=50" \
  --jq '.check_runs[] | select(.conclusion=="failure") | .id' \
  | xargs -I{} gh api repos/OWNER/REPO/check-runs/{}/annotations --jq '.[].message'

# apagar artefatos antigos (um DELETE por artefato)
gh api --method DELETE repos/OWNER/REPO/actions/artifacts/<id>
gh api --method DELETE repos/OWNER/REPO/actions/caches/<id>

# deploy e verificação
flutter build web
firebase deploy --only hosting --project pos-app-c4297
firebase hosting:channel:list --project pos-app-c4297
```
