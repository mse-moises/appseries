# Spec — preferências de gênero no primeiro acesso (AP-38)

> Item do Jira: **AP-38** ("do que você gosta" no primeiro acesso). Regras gerais:
> [`constitution.md`](../constitution.md).

## Objetivo

Antes da primeira sugestão, a pessoa diz em poucos toques de que gêneros gosta. Assim a
recomendação não começa aleatória.

## Escopo

- tela de chips (`PreferencesPage`) com os 18 gêneros do TMDB em pt-BR. A lista fica fixa
  no app, porque o backend não tem rota de gêneros;
- seleção múltipla. O mínimo de 3 é só uma **sugestão**: com 1 gênero já dá para salvar;
- cada gênero tem a sua cor (`GeneroChip`);
- decisão do primeiro acesso no `AuthGate`, entre o login e a home;
- "Pular" leva para a home com o "Em alta" carregado, nunca para uma tela vazia;
- "Salvar" faz `PUT /api/v1/preferencias` **preservando o `momento`**. O `PUT` substitui
  o registro inteiro, então o salvar só fica liberado depois que o `GET` respondeu;
- atalho na home (ícone na AppBar) para a rota `/preferencias`.

## Contrato

`GET /api/v1/preferencias` devolve `{ "momento": null, "generos": [] }`.
`PUT /api/v1/preferencias` recebe `{ momento, generos }`.

## Decisão do primeiro acesso

| situação | tela |
| --- | --- |
| marca local da conta presente | home |
| sem marca, `generos` não vazio no servidor | home, e grava a marca |
| sem marca, `generos` vazio | chips, com "Pular" e sem botão de voltar |
| qualquer falha (servidor fora, marca ilegível) | home |

A tela de gostos nunca impede a entrada no app.

Pular e nunca ter visto a tela deixam o servidor no mesmo estado (`generos: []`). O que
separa os dois é a marca local em `shared_preferences`, gravada **por conta**
(`preferencias_vistas_<uid>`). Uma falha nesse armazenamento vira
`ArmazenamentoLocalError`, e o único efeito é a tela aparecer mais uma vez.

## Limites conhecidos

- **A marca é por aparelho.** Quem pulou no celular vê os chips de novo no tablet (ou na
  web, ou depois de reinstalar o app), enquanto não salvar nenhum gênero. Isso é esperado:
  o servidor não sabe distinguir "pulou" de "nunca viu". Se isso incomodar, a saída é o
  backend guardar o pulo.
- **A marca nunca é apagada.** `preferencias_vistas_<uid>` continua no aparelho depois do
  logout, de propósito: a mesma pessoa não precisa ver a tela de novo. O custo é uma
  chave booleana por conta que já entrou naquele aparelho.

## Fora de escopo

edição do `momento` nesta tela, gêneros vindos do servidor, ordem de preferência entre os
gêneros.
