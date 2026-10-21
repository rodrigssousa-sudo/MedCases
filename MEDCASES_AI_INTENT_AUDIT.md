# Auditoria dirigida de intenção — 20/10/2026

Baseline: `923ff75e8eef6a1e5b352d166217de95be624ff8`. Escopo local; nenhum deploy.

## Fluxo efetivamente examinado

`AiScreen → AppProvider/classificador existente → PlantaoCanonicalRequest → GptSseClient → handler R15 preparado → resolvedor/catalogo ou adaptador MCC1 → CanonicalClinicalSnapshot → renderer existente → Histórico`.

O checkout Web não contém a implantação completa do backend R15. O resolvedor e o adaptador examinados estão nos artefatos congelados `RECOVERY-R15` e `MEDCASES-R15-COMMERCIAL-PATCH/candidate/functions`. Esses arquivos não foram alterados. Nenhum teste local prova qual revisão está atualmente em produção.

## Correções demonstradas

- Nome de fármaco conhecido no catálogo existente é classificado deterministicamente em Plantão antes da classificação genérica; não adicionamos um classificador ou catálogo.
- Nome isolado não herda intoxicação/paciente da mensagem anterior e não dispara recuperação clínica genérica redundante.
- Intoxicação/sobredose explícita e caso com população permanecem contextualizados; “Sobredosis” deixava de ser caso porque continha “dosis”.
- “E quanto ao ajuste renal?” / “¿Y el ajuste renal?” mantêm o tópico, preservando precedência de novo caso e troca de fármaco.
- O Modo Estudo conserva sua classificação e memória existentes.

## Evidências e limite

`intent-final.log`: 22 PASS no compilador real de requisição. `intent-audio-negative-final.log`: 50 PASS no classificador, continuidade e áudio (suítes sobrepostas; não somar contagens). `provider-intent-reproduction.log` contém falhas anteriores à correção.

O resolvedor real preparado, com o snapshot histórico de catálogo, resolve Hipocalemia/Hipopotasemia e Sepse. Nesse snapshot, a consulta explícita de intoxicação retorna ABSENT; não foi fabricado alias ou autorização para obter PASS. A correção da intenção não comprova abertura de um protocolo toxicológico autorizado. Ver `prepared-resolver-matrix.json`.

Não foram medidas chamadas/tokens produtivos. O ensaio HTTP local comprova uma requisição por cenário, sem IA ou franquias reais.
