# Auditoria e correção de apresentação — IA/Plantão

## Auditoria read-only (antes do patch)

O workspace `medcases-calculadora` não contém o chat. O fluxo foi localizado no repositório Flutter `/Users/brunorodrigues/MedCases`, inicialmente sem alterações locais.

- `EntitlementService.consumeAiAllowance` emite `FREE_PLANTAO_DAILY_LIMIT_REACHED` (ou a variante Estudo). `AppProvider.sendAiMessage` verifica entitlement antes do pipeline clínico e chama `onError` com o código. Essa ordem e seus limites não foram alterados.
- `ai_screen.dart`: `onError` reconhecia somente códigos exatos de quota e abria upgrade. As demais strings eram atribuídas diretamente a `_ChatMsg.text`. O fluxo de exceção não fornecia fallback na bolha.
- `onDone` aceitava texto antes de transformações clínicas/Markdown; códigos recebidos nessa via não tinham um mapeamento de apresentação. O histórico também era renderizado sem esse filtro. Isso permite exposição de identificadores e perda de separadores. Não houve reprodução em produção; a causa foi identificada por inspeção do código.
- Bloqueios clínicos chegam por `PIPELINE_RESULT_REJECTED_AFTER_START`, mensagens de validação interrompida e `ClinicalRequestContext.safeMessage`. Não se alteraram os validadores nem as mensagens de solicitação de dados clínicos faltantes.

## Patch

1. `lib/screens/ai/widgets/ai_failure_message.dart`: mapeamento central PT/ES, tolerância às variantes de quota com underscores escapados/ausentes e slug; fallback sem interpolar o erro original; bolha de texto simples.
2. `lib/screens/ai_screen.dart`: aplica o mapeamento antes da formatação clínica, no callback de erro, nas exceções e na apresentação de histórico legado. Reutiliza o índice da bolha da requisição, descarta streaming/DTO e desativa banners concorrentes quando apresenta um erro. Persiste somente a mensagem amigável dos novos erros. O código bruto permanece no log `[AI_PRESENTATION_ERROR]`.
3. `test/ai_failure_message_test.dart`: 24 testes de mapeamento/widget e ligação com a tela.

Prioridade: quota (Plantão/Estudo) > paywall/quota genérica > validação clínica > desconhecido. Erros posteriores substituem o mesmo slot apenas se tiverem maior prioridade; callbacks clínicos posteriores não reabrem a resposta bloqueada. O modal automático de upgrade foi substituído pela mensagem de quota, para manter um único estado de erro visível. O fluxo existente de autenticação permanece.

## Verificação

Análise estática: sem erros ou warnings; apenas 23 avisos informativos preexistentes de estilo/depreciação na tela. `git diff --check` aprovado.

65 testes aprovados:

```sh
flutter test --no-pub test/ai_failure_message_test.dart \
  test/services/entitlement_service_contract_test.dart \
  test/services/ai/safety/clinical_safety_flow_integration_test.dart \
  test/widgets/message_render_policy_test.dart
```

Cobertura: PT/ES; quota canônica/escapada/compacta/slug; quota junto de validação; ordem inversa de callbacks; validação clínica; erro desconhecido; ausência de identificadores técnicos no texto do widget; histórico; preservação de texto clínico normal e de solicitação de dados faltantes.

Limite da validação: testes de widget da bolha e estado de prioridade, mais contrato de ligação por inspeção do código da tela; não foi realizado E2E autenticado contra serviços de produção.

Regras clínicas, prompts, conteúdo clínico, provider e contratos de entitlement não foram modificados. Sem commit, push ou deploy.
