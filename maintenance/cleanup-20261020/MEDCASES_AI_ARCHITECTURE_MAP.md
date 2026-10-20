# Mapa das duas IAs e fontes — 20/10/2026

## Baseline e limites de autoridade

Checkout de manutenção: `/Users/brunorodrigues/Developer/MedCases-Cleanup-20261020`. Branch `maintenance/code-cleanup-20261020`.
Base Git comercial preparada: `67d0e3589d1657f9a33999b214faccedb05db1e3`, branch original `codex/landing-prelogin-refinement-r1`, remote original `https://github.com/rodrigssousa-sudo/MedCases.git`.
É a base comercial preparada localmente; não foi feita consulta para afirmar qual revisão está publicada hoje.
A pasta inicial da conversa não contém Git. O checkout comercial em Documents tinha 1.440 arquivos dataless; o worktree MedCases-Plantao-R8 tinha 41 e numerosas mudanças locais. Ambos foram preservados.
Uma cópia Git independente, sem hardlinks, materializou os 3.378 arquivos rastreados fora do iCloud. Nenhum arquivo faltou. Não foi criado novo aplicativo ou nova arquitetura.
O backend R15 usado para mapear o contrato é `/Users/brunorodrigues/Library/Developer/MedCases-R8-Homologation/RECOVERY-R15/functions`. O `functions/` desta base Web NÃO substitui automaticamente esse pacote. Não houve integração ou deploy de backend.

## FEATURE → ENTRYPOINT → SERVICE → SOURCE → CONTRACT → RENDERER → HISTORY → TEST

| Feature | Entrypoint → service | Source → contract | Renderer → history | Teste/limite |
|---|---|---|---|---|
| Plantão nominal | ai_screen → AppProvider → ProviderRouterService → GptSseClient → handler R15 | app_config/clinical_content → clinical_content_versions → identidades/projeções → approved_protocol | CanonicalClinicalSnapshot → GuardiaClinicalResponseView → exchanges por requestId/hydrator | 80 testes locais de resolução R15; SSE legado tem 3 falhas |
| Executivo/FULL | plantao_public_restore → plantao_dynamic_catalog | approvedSources + executives; hash e escopo do review → EXECUTIVE ou integral autorizado | presentation/fullProtocolRef; sem alteração do integral | Verificação de contrato; não confundir síntese nova com aprovação |
| Estudo curto/profundo | ai_screen → AppProvider → PromptModules.estudo → router | contexto conversacional/material fornecido, fontes e referências → SSE e modelo textual | Markdown, continuação → finalizador/histórico | chunker, resolver, botão, didática; 2 testes de memória falham |
| Ficha farmacológica | Plantão → plantao_drug_reference | MCC1 session → /api/drugs/:id (fallback catálogo sob capability) → drug_reference | snapshot preserva sourceJson/hash/idioma → mesma persistência de referência | Fixture PT/ES e negativa de permissão; nenhuma chamada MCC1 real |
| Copiar/ouvir/fontes | ai_screen + ActionButtonsRow | texto efetivamente exibido, referências, ClinicalTtsService | Clipboard/áudio/UI; não autoriza tratamento | Testes técnicos e build; não houve escuta física |
| Histórico | AppProvider → FirestoreService/hydrator | exchanges salvos, requestId e proveniência | pergunta + resposta; não gerar ao reabrir | Deduplicação e contratos; nenhuma conta real acessada |
| Direitos | AuthService → EntitlementService; servidor/ledger | sessão e documento autoritativo, nunca campo arbitrário do cliente | Estados de erro/carregamento | Contratos Free/Premium; sem alteração de quotas |

## Componentes

O inventário `component-inventory.csv` contém 35 componentes com caminho absoluto, responsabilidade, evidência de uso, consumidores/dependências, testes, compartilhamento, proteção e decisão de remoção. `evidence/dart-import-graph.json` registra imports/exports/parts. Ausência de referência textual NÃO foi usada para remover arquivos.

## Fontes e regras preservadas

- O índice normaliza aliases, mas identidade clínica não pode ser criada apenas por semelhança. Conflitos, negativas, paciente e simulação conservam seus gates.
- O servidor verifica manifesto completo, hash de cada chunk, payload aprovado, revisão e projeções PT/ES. Reconhecimento de identidade pendente não permite desvio para pesquisa externa.
- EXECUTIVE exige review próprio, hash de apresentação e vínculo ao FULL exato. Ausente, o integral continua disponível dentro do escopo autorizado; reorganização lossless é distinta de resumo com omissões.
- Medicamentos preservam dose, unidade, via, frequência, duração quando presente, conditions/alternatives/clinicalLimits e relação conditional/alternative/concomitant. Não se transformou combinação em alternativa.
- MCC1 usa direitos reais e mantém cálculo/prescrição não autorizados como false. sourceJson é preservado. Os 29 campos ES previamente apontados permanecem revisão editorial separada, não corrigidos nesta missão.
- Plantão/Estudo compartilham UI, sessão, stream e persistência; prompts, contexto e seleção de endpoint diferem. Profundidade didática não autoriza prescrição.

## Cobertura e lacunas reais

Mapa dos caminhos principais concluído; inventário exaustivo de toda ramificação histórica/shadow é parcial. Não houve validação física, leitura do catálogo produtivo atual ou execução de IA paga. Cinco testes existentes falharam em contratos não alterados. O build Web Release passou; analyzer global já continha erros em componentes antigos.

