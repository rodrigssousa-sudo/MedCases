# Ficha farmacológica canônica — adendo local

Baseline: `d8d77d5912c71a683b2c07e746e7bbc0689e2a04`. Nenhum deploy, consulta clínica, chamada MCC1 atual, alteração de direito ou modificação da candidata 1721.

## Implementação

O renderer e o rodapé existentes foram reutilizados. Nome, apresentação, posologia de referência e alertas essenciais formam a projeção inicial. Classe, mecanismo, farmacocinética, farmacodinâmica, marcas, efeitos comuns extensos, orientações genéricas e diretrizes ficam no integral. Duplicação de apresentações com bytes idênticos é removida da projeção. Valores diferentes nunca são fundidos.

Doses existentes têm destaque visual, conservando indicação, via, peso, população, frequência, máximo, ajustes, administração, preparo e infusão. Campos são compactados em parágrafos com rótulos; não há cálculo ou reconstrução de esquemas. Alertas de monitorização, interações e observações que podem condicionar a dose são mantidos conservadoramente quando a fonte não distingue detalhes opcionais de alertas essenciais. Isso torna algumas fichas mais extensas; não foi usada uma heurística clínica para apagá-los. Uma seleção clínica ainda menor desses avisos exige escopo documental correspondente.

Gestação/lactação específicas são conservadas. Apenas os quatro textos genéricos literais presentes nos documentos históricos foram deslocados para FULL; nenhuma regra semântica presume que um novo aviso seja dispensável. Ausência de dose/apresentação é identificada, sem inventar dados.

Pergunta explícita sobre contraindicações, interações, mecanismo, farmacocinética, gestação ou lactação filtra o campo inteiro solicitado, conservando a expansão do integral. Isso é seleção visual do documento autenticado; não muda intenção, permissões ou fonte.

`q4h`, `q6h`, `q8h`, `q12h` e `q24h` viram “a cada N horas”/“cada N horas” apenas na apresentação e leitura. Intervalos ambíguos, outros intervalos, duração, frequência semanal e unidades de infusão não são convertidos pela regra. O texto original da cópia e Histórico continua intacto, inclusive sua grafia original. Marcador administrativo AUTOMATABLE não aparece na apresentação; as restrições clínicas textuais permanecem.

Rodapé único: horário real, Fontes/Fuentes, Ver ficha completa, Ouvir/Escuchar e Copiar. Fontes ficam inicialmente recolhidas, inclusive no integral. Cópia continua integral e o áudio mantém o serviço feminino previamente aprovado pelo operador.

## Evidência e limitações

`drug-minimal-audio-final.log`: 77 testes PASS — documentos históricos Paracetamol PT/ES, Noradrenalina, Ceftriaxona e Metformina; máximos/peso/populações; pedido de contraindicações; cinco intervalos; infusão contínua, duração e frequência semanal; falta de dose em fixture técnica negativa; avisos reprodutivos específicos; expansão, integridade de Histórico, cópia/áudio e rodapé em 320/375/768/1200 px. Não somar às suítes anteriores sobrepostas.

Paracetamol é o documento real histórico capturado em 16/10, com identidade/sourceJson e hash preservados; as outras fontes históricas passam pelo adaptador já existente. Fixtures sintéticas são usadas somente nos casos negativos de contrato e não comprovam homologação médica. A seleção da fonte é demonstrada por identidade/hash históricos e pelos testes existentes de roteamento; não por nova consulta MCC1 autenticada.

O preview Flutter real mostra a pergunta nominal Paracetamol, projeção inicial e a mesma ficha expandida. Não é uma consulta produtiva nem uma comprovação de conectividade MCC1 atual. A fonte ES contém os 29 campos em português já conhecidos; os rótulos e intervalos foram localizados, sem traduzir conteúdo clínico por inferência. Revisão editorial clínica permanece separada.

A fonte histórica de Noradrenalina não fornece uma diluição numérica completa. A UI conserva o aviso sobre concentração/acesso/bomba/monitorização e o impedimento de extrapolação; não apresenta uma administração IV pronta ou inventa concentração. Preservação técnica não equivale a validação de um preparo ausente.

## Matriz — escopo técnico local

| Critério | Resultado |
|---|---|
| DRUG_LOOKUP_ROUTING | PASS — regressão local existente; MCC1 atual não verificado |
| PARACETAMOL_QUICK_VIEW | PASS — fonte histórica verificável |
| DOSING_CONTEXT_PRESERVED | PASS |
| INTERVAL_NOTATION_PT_ES | PASS |
| DRUG_DUPLICATIONS_REMOVED | PASS — somente duplicatas literais |
| IV_DILUTION_SAFETY | PASS — sem invenção/omissão dos avisos; preparo numérico real incompleto na fonte |
| FULL_DRUG_SHEET_AVAILABLE | PASS |
| PREMIUM_FOOTER | PASS |
| HISTORY_COPY_AUDIO | PASS — regressões locais e confirmação humana anterior da voz; sem novo teste físico iOS |
| DRUG_DATA_UNCHANGED | YES |
| PRODUCTION_MUTATIONS | 0 |

Rollback: reverter o commit local deste adendo. Não há migração ou ação remota a desfazer. O manifesto anterior permanece um recibo do commit anterior, não do working tree posterior; o novo manifesto de delta identifica os hashes atuais.

## Complemento solicitado no preview

A expansão de intervalos foi estendida às referências clínicas e aos dois exemplos sintéticos A/B, tanto na apresentação breve quanto na expandida, em PT/ES. A mesma regra literal não altera o texto original nem a frequência. Os testes dos dois formatos agora exigem ausência de `q8h` e presença de “a cada 8 horas”/“cada 8 horas”.

Capturas reais: `paracetamol-minimal-pt-1200.png`, `paracetamol-full-pt-1200.png` e `paracetamol-minimal-es-375.png`. O conteúdo ES misto é uma limitação da fonte histórica visível na captura, não uma tradução homologada. A apresentação breve foi observada no Flutter real, e sua expansão mostra classe, mecanismo, farmacocinética e demais campos preservados. Isso não é uma nova consulta clínica online.

Fechamento: 77 testes PASS na regressão final, build preview PASS (53,4 s), build Web PASS (80,7 s). Analyzer dos seis arquivos afetados: 0 erros, 0 warnings, os mesmos 8 INFO preexistentes, sem novo diagnóstico. A análise mais ampla ainda contém os 14 warnings legados registrados no relatório anterior. As capturas `synthetic-a-interval-pt.png` e `synthetic-b-interval-pt.png` comprovam visualmente a atualização solicitada, além dos testes PT/ES. Nenhuma alteração produtiva foi realizada.
