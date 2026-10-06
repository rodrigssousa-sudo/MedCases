# OB-JIT-2026-10-06-G08-v1.1 — 50 condições relevantes na gestação

Estado: pacote clínico preparado para aprovação humana. Nenhuma publicação em Estudo/Plantão foi executada.

- 34 owners existentes reutilizados (32 presentes no catálogo da build atual, 2 exclusivamente remotos).
- 16 condições novas propostas, sem criação/ativação de owners no runtime.
- 2 cadastros didáticos mantêm seus IDs originais; cistite e enxaqueca com aura não ganham registros duplicados.
- 200 projeções: Estudo PT/ES e Plantão PT/ES, geradas de 50 payloads canônicos.
- Conteúdo específico de gestação é um complemento; não apaga o tratamento geral existente.
- Referências ao final, unidades de tempo por extenso, medicamentos identificados e sem PDF.

Abra `review.html` para comparar os modos e idiomas. `manifest.json` lista os 50 temas, IDs, vínculos e hashes. `entries/001` a `entries/050` contêm payload e projeções. `evidence-ledger.json` liga fatos às fontes oficiais. População: adultas grávidas; doses pediátricas e de lactação não são inferidas.

Na preparação v1.0, os 50 Guias foram salvos como RASCUNHO na coleção real `clinical_guides`: 28 novos documentos e 22 existentes atualizados. Os conteúdos gerais, capas, autores e campos não alterados foram preservados. Readback final dos 50 hashes e status: PASS. Não há publicação automática de Guias. No readback da preparação v1.0, o total foi 329 Guias: 289 rascunhos e 40 publicados. O catálogo de patologias ativo da build continua com 514 entradas; não contabilizamos owners propostos como já publicados.

## Contrato de acesso remoto — limitação técnica identificada

A base clínica versionada deve existir fora dos assets do app. O repositório armazena o pacote de autoria; o runtime deve consumir as projeções aprovadas em uma fonte remota com ativação coordenada por versão/hash. Um push de JSON ao GitHub não demonstra, por si só, consumo pelo app.

Na produção atual (commit 48368c001df277cb8b3bd44f050b809545a840c8), Plantão possui fonte Firestore e fallback local em `lib/services/plantao_machine_native_context_prefetch.dart`. Entretanto, o override `_GiBatch01RegistrySource` força dados bundled para os owners G07. Estudo recebe `protocolsDatabase` local em `lib/data/protocols_database.dart`; `lib/services/gi_batch01_publication_state.dart` contém versão/hashes estáticos do lote G07. Assim, gravar somente CMS ou Firestore não comprova atualização simultânea dos dois modos nem elimina builds para todas as atualizações.

Antes de ativar este lote, é necessário adaptar estritamente os consumidores de Estudo/Plantão: carregar catálogo e quatro projeções remotas por versão/hash; manter última versão íntegra como fallback; ativar apenas quando todas as projeções aprovadas estiverem completas; remover dependência de hashes específicos de G07 para futuras versões. Esse ajuste de carregador pode exigir uma atualização inicial do app instalado. Depois, alterações exclusivamente clínicas devem ocorrer por dados remotos, sem nova build. Não foi implementado nem publicado neste pacote.

READY_FOR_OWNER_REVIEW=YES
GUIDES_ADMIN=DRAFT
RUNTIME_PUBLICATION=NOT_EXECUTED
REMOTE_DUAL_MODE_READINESS=BLOCKED_TECHNICAL_STATIC_STUDY_CONSUMER
APP_BUILD_EXECUTED=NO
HUMAN_APPROVAL=PENDING

## Revisão de tratamentos v1.1

Os 50 tratamentos foram ampliados com alternativas e critérios de seleção, vias sequenciais ou medidas complementares, restrições gestacionais e conduta para falha/contraindicação. Não se exige um segundo fármaco equivalente onde a evidência não sustenta. Hipotireoidismo, tricomoníase, sífilis, gonorreia, colecistite e ectópica rota têm limites explicitados. PT/ES e Estudo/Plantão compartilham todos os fatos. Unidades de tempo seguem por extenso e referências permanecem ao final. Este conteúdo alterado aguarda aprovação do owner; a v1.0 não aprova automaticamente a v1.1.

Revisão v1.1: 50 rascunhos atualizados em commit Firestore atômico e readback integral confirmado, sem publicar Guias nem escrever no runtime; campos não alterados preservados.
