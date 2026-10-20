# Recebimento local de protocolos revisados — schema 2

Este diretório reúne o preparador schema 2 **já existente**, seu allowlist
histórico e o validador de decisões recuperado de
`Desktop/PACOTE/02_REIMPORTACAO/validar_decisoes.py`. As quatro fontes foram
copiadas byte a byte; a proveniência está em
`maintenance/integration-readiness/evidence/recovered-sources.json`.
Nenhuma delas é um catálogo paralelo.

`stage_reviewed_protocols.py` é o adaptador de entrada e elegibilidade offline.
Ele não contém cliente Firebase, credenciais, conexão de rede ou publicação.
O preparador existente conserva suas APIs; este comando usa somente validação
e preparação local, nunca `writeDraft`, `activate` ou `rollback` remoto.

## Fluxo e arquivos necessários

`JSON homologado → schema 2 → identidade canônica → hashes → decisão médica → staging → elegibilidade`

Pré-requisitos: Python 3.10+ e Node.js 18+. Não requer instalar pacotes.

1. **input.json**: objeto com `schemaVersion: 2`, `contentVersion` novo e
   `registries`. As oito coleções nativas são as mesmas de `publication.mjs`:
   `clinical_identity_registry`, `clinical_protocols`,
   `clinical_classification_registry`, `clinical_management_rules`,
   `clinical_action_registry`, `clinical_content_registry`,
   `clinical_projection_registry`, `clinical_legacy_protocols`.
   Cada coleção é um array; coleções sem entradas são arrays vazios.
2. **current-catalog.json**: snapshot local `{manifest, chunks, pointer}` do
   catálogo atual, sem credenciais. O ponteiro ACTIVE e os hashes devem
   corresponder. Identidades desabilitadas são preservadas no snapshot para
   detectar conflitos e impedir sua reativação implícita.
3. **Pacote de revisão existente**: `artefatos_revisaveis.json`, os artefatos
   revisados, matrizes quando existentes, e
   `00_CONTROLE_E_FONTES/ponteiro_produtivo.json`.
4. **decisions.json**: array de formulários históricos; **signature-acceptances.json**:
   array de verificações humanas da assinatura/autoria e da transcrição, conforme
   o mecanismo histórico. As evidências assinadas ficam sob `--evidence-root`.

O número de uma lista não vira ID. Cada grupo requer identidade canônica única,
projeção única, versão coerente e aliases sem colisão com outro owner. Não há
correspondência por distância ortográfica nem reescrita automática de variantes.

## Vínculo verificável da decisão

Os campos históricos permanecem obrigatórios: `identity`, `sourceVersion`,
`catalogVersion`, `manifestSha256`, `reviewer` (nome, registro, jurisdição),
`decidedAt` com timezone e `decisions`. Cada decisão identifica
`<canonicalId>:FULL:pt` ou `:es`, idioma, hash do artefato, estado real e hash da
evidência assinada. Matrizes de omissão são verificadas quando presentes.

O adaptador exige ainda o escopo transcrito da evidência existente, sem inferi-lo:

```json
{
  "recordId": "IDENTIFICADOR_REAL_DO_PARECER",
  "pendingClinicalIssues": [],
  "approvalScope": {
    "canonicalId": "ID_CANONICO",
    "sourceVersion": "VERSAO_EXATA",
    "level": "FULL",
    "use": "general_protocol_reference",
    "languages": ["pt", "es"],
    "payloadSha256": "SHA256_DOS_BYTES_ORIGINAIS_DO_PAYLOAD",
    "projectionSha256": {
      "plantao": {"pt": "SHA256_PT", "es": "SHA256_ES"},
      "study": {"pt": "SHA256_ESTUDO_PT", "es": "SHA256_ESTUDO_ES"}
    },
    "registriesSha256": "HASH_CANONICO_DOS_REGISTROS_DESTA_IDENTIDADE",
    "covers": ["clinical_text", "medications_doses_conditions", "translations"]
  }
}
```

Os valores acima são placeholders inválidos, não uma aprovação de exemplo.
O schema 2 de autoria atualmente exige projeções Plantão/Estudo PT/ES. O
adaptador não fabrica as projeções ausentes. Uma futura entrada incompleta
será rejeitada individualmente com seu motivo, preservando as demais.

Pode haver um parecer bilíngue ou dois pareceres independentes, um por idioma.
Em pareceres separados, `languages` e cada mapa de hashes contêm somente o
idioma aprovado. A cobertura conjunta precisa incluir PT e ES; aprovação PT
não cobre tradução ES. A ordem das listas não altera o significado do escopo.

Cada aceite humano acrescenta `decisionFormSha256` (hash canônico do formulário
completo), `reviewerRegistration` e `reviewerJurisdiction`. Isso vincula a
transcrição do escopo à mesma evidência, inclusive contra alterações posteriores.
Não exige nova assinatura médica se o parecer histórico já cobre comprovadamente
os mesmos bytes e uso; exige que essa cobertura tenha sido efetivamente verificada
por uma pessoa, como no contrato histórico. O programa não realiza essa avaliação.

Hash de texto/payload: SHA-256 dos bytes UTF-8 exatos. Hash canônico de formulário
e registros: função `canonical()` do validador histórico (JSON ordenado, UTF-8,
sem espaços). Hash de chunk e manifesto: implementação existente de publicação.
As doses, condições, via, intervalo e relações terapêuticas permanecem no texto
e nos registros originais, inteiramente vinculados ao escopo. Não há tradução,
extração clínica ou preenchimento de dados faltantes por inferência.

## Executar sem publicação

```sh
python3 tool/clinical_catalog/stage_reviewed_protocols.py \
  --package /caminho/PACOTE \
  --input /caminho/input.json \
  --current-catalog /caminho/current-catalog.json \
  --decisions /caminho/decisions.json \
  --signature-acceptances /caminho/signature-acceptances.json \
  --evidence-root /caminho/evidencias \
  --output /caminho/novo-staging
```

O diretório de saída deve ser novo. `staging.json` preserva os registros válidos
e seus vínculos, lista os rejeitados e mantém `publicationAuthorized: false`.
`LOCAL_STAGING_ONLY` é um estado do recibo local, não um estado novo do catálogo.
`input-sha256.json` registra os hashes dos inputs. Não há sobrescrita silenciosa,
ativação, cópia para produção ou descarte dos registros válidos por uma falha
individual. Conflito global no snapshot interrompe toda a operação antes da saída.

Os registros elegíveis são um **delta de staging**; não substituem sozinhos o
catálogo inteiro. Uma publicação futura deverá mesclá-los com o catálogo vigente,
preservar os demais registros, revalidar hashes/revisões e usar o fluxo transacional
já existente com autorização de publicação. EXECUTIVE não é aprovado por uma
decisão FULL; continua exigindo sua decisão específica e vínculo ao integral.

## Testes locais

```sh
python3 -m unittest discover -s tool/clinical_catalog/medical_review -p test_historical_decisions.py -v
python3 -m unittest discover -s tool/clinical_catalog -p test_stage_reviewed_protocols.py -v
MEDCASES_CATALOG_TOOL_ROOT="$PWD/tool/clinical_catalog" node --test maintenance/cleanup-20261020/schema2-readiness.test.mjs
```

As fixtures são sintéticas e não clínicas. PASS comprova o comportamento técnico
do validador/importador; não significa homologação médica real dos 1.000 protocolos.
