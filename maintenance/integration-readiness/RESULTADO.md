# Fechamento dos bloqueios de integração — 20/10/2026

Baseline preservado: `1f469d46648a921c28be940af993b66a2eff1dcc`.

Prontidão técnica de recebimento e staging: **PASS**. O JSON final ainda não foi fornecido nem importado. Nenhuma aprovação médica real foi criada por esta execução e nenhum conteúdo foi publicado.

## Cinco falhas: causa e correção fundamentada

| Arquivo/teste pendente | Asserção que falhava | Contrato atual e causa | Correção |
|---|---|---|---|
| `test/ai_stream/gpt_sse_client_test.dart`: converte structuredOutput | 4 eventos/ClinicalStructuredOutput, recebeu AiFailed | Desde `6c10a8bd9ab67e8796e83d5a3bc4d13fa4a5bb12`, Plantão exige handshake canônico do catálogo. A fixture de geração usava modo default plantao e endpoint genérico | Declarar `mode: study` para o transporte legado preservado; manter todas as expectativas de conteúdo/eventos |
| Mesmo arquivo: structuredOutput inválido | gpt_sse_invalid_structured_output, recebeu gpt_sse_stream_error | A rejeição ocorria antes da validação do structuredOutput por incompatibilidade de modo | Mesma correção de modo; mantém falha não recuperável e parcial esperados |
| Mesmo arquivo: transport_done legado | AiCompleted null structured | Mesmo uso indevido do modo default Plantão | Declarar Study, mantendo texto/provedor e fechamento |
| `study_30turn_verbatim_memory_contract_test.dart`: timeout Plantao-only | string literal da condição em uma linha | Condição funcional preservada; `dart format` dividiu as linhas | Regex da condição com whitespace flexível, preservando todos os predicados |
| Mesmo arquivo: minimal policy | constante literal em uma linha e strategy=thread_minimal | Desde `86180a3814f687b46ddf64d2dd5629d1c8265b5d`, a política preserva âncora do caso + dois pares recentes; Study mantém 30 pares | Assert da constante pública e teste comportamental da âncora/turnos e do histórico vazio em caso novo |

Não foi encontrado defeito de implementação nesses cinco casos. Nenhum teste foi excluído. Não houve mudança em GptSseClient ou ClinicalThreadManager.

Quatro testes complementares exercitam Plantão PT/ES: rejeição de geração legada fora do handshake e preservação de referência integral por SSE. São fixtures técnicas não clínicas, não homologação médica.

## Validador histórico recuperado

Fonte: `/Users/brunorodrigues/Desktop/PACOTE/02_REIMPORTACAO/validar_decisoes.py`.
SHA-256: `00334284f74bcef0e1edb28b6ff3e614e4d44ab4ddaa4ba55f634555f10f26e3`.
Cópia local idêntica: `tool/clinical_catalog/medical_review/validar_decisoes.py`.
Os 10 testes históricos passaram; somente a localização do import no teste foi tornada relativa para portabilidade.

Preparador, schema funcional e allowlist schema 2 existentes também foram reunidos no mesmo diretório, sem alterar seus bytes. A proveniência dos quatro arquivos está em `evidence/recovered-sources.json`. Isso elimina a dependência de paths externos para executar o novo adaptador; não cria outro catálogo.

## Fluxo implementado

`JSON HOMOLOGADO → VALIDAÇÃO SCHEMA 2 → IDENTIDADE CANÔNICA → HASHES → APROVAÇÃO MÉDICA → STAGING → ELEGIBILIDADE`.

Entrypoint: `tool/clinical_catalog/stage_reviewed_protocols.py`.
Contrato e comando: `tool/clinical_catalog/README.md`.

O adaptador reutiliza a validação histórica de revisão, artefatos, assinatura aceita por pessoa, matrizes, versão e catálogo corrente. O complemento vincula o escopo transcrito ao ID, versão, payload, projeções PT/ES por modo e conjunto completo de registros da identidade. A aceitação humana precisa cobrir o hash do formulário completo; alterações posteriores invalidam o vínculo.

Não se exige nova assinatura quando o documento histórico já cobre o mesmo conteúdo/escopo. A transcrição e sua correspondência à evidência precisam ser verificadas por uma pessoa; a ferramenta não presume essa comprovação e não autentica assinatura por IA.

Parecer bilíngue e pareceres independentes PT/ES são suportados. Aprovação PT isolada não aprova ES. Escopo de doses/condições e tradução é explícito. Números de lista, aliases ambíguos, versões conflitantes, falta de evidência, pendências e alterações são recusados individualmente; os demais registros permanecem elegíveis para staging.

A saída é um delta local; não substitui o catálogo inteiro. O recibo mantém publicationAuthorized=false e remoteWrites=0. Publicação futura requer mescla contra o catálogo corrente, revalidação e autorização própria pelo fluxo já existente. Não há cliente Firestore ou chamada de rede no adaptador.

## Testes finais

| Gate | Resultado real | Evidência |
|---|---|---|
| Cinco casos pendentes e casos existentes dos dois arquivos | PASS (7 testes antes de complementar a fronteira) | five-cases.log |
| Regressão dirigida SSE, memória, continuidade, âncora e parser | 79/79 PASS | directed-regression.log |
| SSE final, após remover import desnecessário de crypto | 7/7 PASS, subconjunto da regressão | sse-final.log |
| Validador histórico | 10/10 PASS | historical-validator.log |
| Staging schema 2 / vínculos / rejeição individual / CLI | 32/32 PASS | schema2-staging.log |
| Preparador schema 2 existente e transações em modelo local | 10/10 PASS | schema2-core.log |
| Analyzer afetado | No issues found | analyzer-affected.log |
| Sintaxe Python e Node, diff --check | PASS | execução local |
| Web build | NOT_REQUIRED | nenhum lib/pubspec/asset/backend/nativo alterado; build aprovado do baseline preservado |

131 testes únicos PASS. Reexecuções de subconjuntos não foram somadas novamente. Fixtures e modelos de transação não substituem homologação clínica nem integração produtiva.

## Integridade e rollback

Arquivos de runtime, backend, conteúdo, configurações nativas e dependências não mudaram frente ao baseline. 223 hashes externos protegidos e 1.869 hashes da candidata 1721 conferem sem divergência (`evidence/protected-integrity.json`). Nenhuma escrita produtiva, push, deploy ou nova build comercial.

O commit de entrega tem o baseline como pai; seu SHA está no recibo final externo e na resposta de entrega. Rollback local: `git revert <commit-de-entrega>` nesta branch, depois de verificar working tree limpo. Isso preserva o commit de limpeza anterior. Não usar reset/clean em checkouts originais.

## Alcance da prontidão

READY_TO_RECEIVE_FINAL_1000_JSON=YES significa que há contrato, comando local e testes para receber, validar e isolar registros no schema nativo. Não significa que um JSON arbitrário ou todo o lote será aprovado. Projeções ausentes e aprovações incompletas terão negativas específicas; os textos não serão inferidos. O primeiro lote real deverá ser executado pelo comando documentado com seus artefatos e evidências existentes. As 1.000 entradas antigas não foram reimportadas.
