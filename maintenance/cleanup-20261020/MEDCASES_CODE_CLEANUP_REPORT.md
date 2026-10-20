# Relatório de limpeza real e regressões

## Resultado

Resultado PARCIAL: limpeza local executada e build Web aprovado; existem cinco testes preexistentes falhando e a cadeia completa de importação clínica ainda não está pronta. Não houve publicação, push, IAM, consulta clínica ou acesso a contas reais.

## Mudanças efetivas

- `lib/screens/internacion/components/soap/soap_evaluacion.dart`: remove um import med_typography sem uso.
- `lib/screens/internacion/components/soap/soap_plan.dart`: remove o mesmo import sem uso.
- `lib/screens/internacion/components/soap/soap_subjetivo.dart`: remove o mesmo import sem uso.
- `lib/screens/library_screen.dart`: remove quatro variáveis locais de cores não utilizadas (primary, secondary, surface, border), com expressões puras.

Total: 4 arquivos de código, 7 linhas removidas, 0 arquivos apagados, 0 duplicações funcionais resolvidas. Não houve alteração de expressão clínica, dose, texto PT/ES, runtime de IA ou proteção comercial. `evidence/removals.json` relaciona a justificativa; `cleanup.patch` é o delta completo de código.

## Testes realmente executados

| Execução | Resultado | Evidência |
|---|---|---|
| Flutter pub get | PASS; lockfile não alterado | pub-get.log |
| Estudo/continuação/parser SSE/biblioteca/SOAP | 76 PASS | regression.log |
| Transporte legado/entitlement/apresentação/estado compartilhado | 57 PASS, 3 FAIL | shared-regression.log |
| Memória Estudo/didática/histórico/apresentação | 15 PASS, 2 FAIL | modes-regression.log |
| Resolvedor e farmacologia R15, fontes históricas/transportes simulados | 80 PASS | backend-routing.log |
| Preparador schema 2 REAL com fixtures não clínicas e modelo transacional local | 10 PASS | schema2-tests.log |
| Web Release, optimization-level=1, no-tree-shake-icons | PASS | web-build.log |
| git diff --check / reverse patch --check / git fsck connectivity | PASS | fechamento local |

Total: 238 testes PASS, 5 FAIL. Nenhuma falha foi convertida em PASS. Os testes de fonte/contrato e mocks NÃO comprovam integração produtiva, nova aprovação clínica ou MCC1 real.

As três falhas SSE esperam transport_done legado em fixtures que recebem AiFailed no contrato atual. As duas falhas de Estudo exigem trechos antigos da política de memória/continuação. GptSseClient, AppProvider e os testes respectivos estão byte a byte iguais ao baseline; a limpeza não tocou nesses contratos. Não foram modificadas as expectativas. Este resultado impede afirmar regressão global PASS.

## Analyzer

Antes: {'error': 418, 'warning': 237, 'info': 2531}; depois: {'error': 418, 'warning': 230, 'info': 2531}. Total 3.186 → 3.179; sem novos erros. Os avisos removidos são os sete comprovados; outros avisos/infos e erros de componentes antigos permanecem documentados, sem exclusão ou ignore novo. Os arquivos editados não têm erros; possuem avisos preexistentes fora do delta.

## Proteções e baseline

3.378 arquivos rastreados comparados: somente os quatro acima mudaram. 223 arquivos externos (backend R15 e ferramentas schema 2) tiveram hashes conferidos sem alteração. A candidata 1721 teve 1.869 hashes de fonte iguais ao manifesto congelado; seu ZIP AOT mantém SHA-256 `34858dd43cac6286573c02e27cdde9bbd308a933aa863ce9c4b6aedc0d1d5b2f`.

Os diretórios originais não foram editados. Não houve operação remota produtiva. Isso comprova ausência de mutação por esta execução; não é uma auditoria de alterações feitas por terceiros no servidor.

Checkout de trabalho completo fora do iCloud: `/Users/brunorodrigues/Developer/MedCases-Cleanup-20261020`. Branch `maintenance/code-cleanup-20261020`. Base `67d0e3589d1657f9a33999b214faccedb05db1e3`. A base veio do checkout comercial preparado; não se afirmou que todas as mudanças não commitadas de outros worktrees estão nele.

Nenhum processo Flutter/build desta missão ficou pendente. As primeiras leituras Git/analyzer que aguardavam placeholders foram encerradas pelo PID específico da própria execução; processos alheios foram preservados.

## Rollback local

Somente nesta cópia de manutenção:

```sh
cd /Users/brunorodrigues/Developer/MedCases-Cleanup-20261020
git apply --reverse --check maintenance/cleanup-20261020/cleanup.patch
git apply --reverse maintenance/cleanup-20261020/cleanup.patch
```

O check passou; rollback não aplicado. Se houver mudanças concorrentes, não forçar. Alternativa após commit: git revert do commit local de limpeza, sem push. Não usar reset/clean em worktrees originais. O commit final e a matriz estão no recibo de entrega externo, evitando referência circular do próprio SHA.

## Prazo

Início registrado conservadoramente em 2026-10-20 20:22 UTC. Missão encerrada antes do primeiro checkpoint T+30; T+60/90/110/120 não atingidos. Não houve renovação do prazo. Duração final no recibo.
