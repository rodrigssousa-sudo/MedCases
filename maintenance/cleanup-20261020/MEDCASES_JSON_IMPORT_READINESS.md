# Contrato de integração futura — schema real, sem importação clínica

## Caminho único a reutilizar

`JSON homologado → validação de identidade/revisão → mapeamento para registries existentes → prepare(..., {schemaVersion:2}) em DRAFT → gates técnicos e clínicos → versão canônica → publicação futura autorizada`.

Preparador existente: `/Users/brunorodrigues/Developer/MedCases-1718-Android/tool/clinical_catalog/publication.mjs`. Validador schema 2: `/Users/brunorodrigues/Developer/MedCases-1718-Android/tool/clinical_catalog/functional_schema.mjs`. Allowlist histórica: `/Users/brunorodrigues/Developer/MedCases-1718-Android/tool/clinical_catalog/migration-baseline-allowlist.json`. Foram reutilizados por import ES module no teste local; não copiados nem modificados. Os hashes estão em evidence/external-protected-sha256.json.
Não usar o `build_remote_clinical_content.dart` schema 1 como substituto do catálogo Firestore schema 2. Ele é outra fundação opt-in. Não portar ferramentas indiscriminadamente para o cliente Web.

## Entrada e armazenamento existentes

`prepare(version, registries, {schemaVersion:2})` espera arrays: clinical_identity_registry, clinical_protocols, clinical_classification_registry, clinical_management_rules, clinical_action_registry, clinical_content_registry, clinical_projection_registry, clinical_legacy_protocols.

- Identidade: canonicalKey e aliases na identity registry; canonicalPathologyKey nos registros associados. Número de lista não é ID. Ambiguidades ficam em staging fora da versão ativável, sem associação forçada.
- Projeção: payload.pt/payload.es com plantaoProjection e studyProjection; markdown deve corresponder ao campo Markdown original. Se estruturado, preservar IDs/tipos das seções e referências. Não fabricar tradução ou campos ausentes.
- Integridade: approvedClinicalPayloadJson preservado como string exata e SHA-256 em payload e registro; chunk.json hash dos bytes UTF-8; manifesto hash canônico completo distinto do hash embutido de autoria.
- Versão: clinical_content_versions/{contentVersion}/chunks/{id}. Ponteiro: app_config/clinical_content com schemaVersion=2, status=ACTIVE, activeVersion, manifestSha256.
- Preparação/publicação usa DRAFT/ACTIVE. Não inventar PENDING/APPROVED como estados de manifesto. Status de decisão médica e do executivo são conceitos distintos.
- `writeDraft` reserva versão create-only. `activate` verifica versão anterior, manifesto e chunks dentro da transação. `rollback` exige versão corrente esperada e revalida alvo/chunks. Nenhuma dessas funções foi chamada com Firestore remoto.

## Aprovação não é uma flag

O empacotador estrutural não verifica autenticidade de parecer médico e não basta para publicar. O teste inclui fixture estrutural válida SEM clinicalReleaseRegistry, demonstrando essa distinção.
A cadeia deve preservar registry.approvedSources por owner/version/activeVersion/chunkId/sourceKey/payloadSha256, idiomas e review.recordId/reviewerId/reviewedAt/evidenceSha256. O guard atual revalida fonte e projeção de ambos idiomas. Review humano deve efetivamente cobrir os bytes e o escopo; hashes não provam assinatura por si sós.
EXECUTIVE adicional exige sourceVersion/sourceHash/locale, presentation.contentHash, review.contentHash, fullProtocolRef e clinicalApproval ligados ao FULL. `medical_approval_status=APPROVED` isolado não satisfaz esse contrato.
O registro de revisão global anterior referencia `Downloads/MEDCASES_CLINICAL_GLOBAL_REVIEW_2026/PACOTE/02_REIMPORTACAO/validar_decisoes.py`, ausente neste computador na busca realizada. O teste histórico correspondente foi preservado; não se inventou validação de assinatura substituta.

## Tratamentos e campos ausentes

Preservar texto e unidades, não traduzir dose por inferência. Executivo exige name/dose/unit/route/frequency/strategy e arrays conditions/alternatives/clinicalLimits; relation deve ser conditional, alternative ou concomitant; duration, quando fornecida, não pode ser vazia. Regras de primeira linha/escalonamento dependem da aprovação da fonte, não de uma ordenação automática.
Campos clínicos faltantes ou ES não aprovado ficam pendentes; não completar com IA. Integral aprovado pode continuar consultável sem aprovação de novo executivo. Não modificar protocolos já aprovados para satisfazer um schema.

## Validação executada

10/10 testes do preparador REAL (fixtures não clínicas): DRAFT, PT/ES Plantão/Estudo, adulteração de chunk e payload, ausência de ES, referência divergente, ID duplicado, coleção ausente, ausência de aprovação implícita, ativação/rollback e conflito em modelo de transação local.
80/80 testes do resolvedor R15 existente: fontes de snapshot histórico, contexto nominal/individual, negativas e farmacologia com transporte simulado. Não são nova homologação médica.

Comando reproduzível, exclusivamente local:

```sh
cd /Users/brunorodrigues/Developer/MedCases-Cleanup-20261020
MEDCASES_CATALOG_TOOL_ROOT=/Users/brunorodrigues/Developer/MedCases-1718-Android/tool/clinical_catalog node --test maintenance/cleanup-20261020/schema2-readiness.test.mjs
```

## Prontidão

O contrato técnico schema 2 está identificado e exercitado. O JSON final dos 1.000 não foi fornecido, lido, importado, aprovado ou publicado. Não existe neste checkout comercial um importador end-to-end com revisão humana vinculada que possa ser declarado pronto sem recuperar o validador externo e confrontar o formato final. Por isso `JSON_IMPORT_CONTRACT=NOT_READY` para execução completa e `READY_TO_RECEIVE_FINAL_1000_JSON=NO` para importação automática; não por incapacidade de receber um arquivo para revisão.
Menor pendência: recuperar o validador de decisões existente e ligar o parecer/hashes ao mapeamento schema 2, sem criar catálogo paralelo. Executar os gates sobre o JSON final quando disponibilizado; publicação permanece separadamente autorizada.

