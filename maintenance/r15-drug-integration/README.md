# Integração farmacológica comercial — entrega local

Baseline: `f7409fb57db5cd4e78028e6f8c2bfc93e8b96151`, branch
`maintenance/code-cleanup-20261020`. Missão autorizada iniciada às
00:43:28 UTC de 21/10/2026, com prazo máximo até 02:43:28 UTC.
Não houve push, deploy, mudança IAM, escrita remota, importação de protocolos
ou alteração da candidata iOS 1721.

## Resultado e limite real

**PARTIAL.** A correção comercial está implementada e testada localmente.
A conexão MCC1 autenticada atual ainda não foi comprovada: não foi
disponibilizada uma sessão comercial legítima nesta execução. O GET sem
credenciais retornou 401, como deve; não é uma falha clínica. Não foram
copiados tokens, criadas contas, concedidos direitos ou reutilizadas sessões
expiradas. A pergunta ao operador sobre sessão legítima permanece pendente.

A leitura da fonte publicada atual foi comprovada separadamente. A origem
não foi substituída silenciosamente por snapshots históricos.

`RESULTADO.json` contém a matriz completa. Os PASS de HTTP/SSE, Histórico,
ledger, Free/Premium/Trial e renderer são regressões locais, não produção nem
homologação física nova.

## Fonte vigente e inventário reconciliado

- Aplicação existente DigitalOcean `56c8a039-10e9-4136-b546-599aa5cff529`,
  deployment ACTIVE `50aaa8c9-84ba-42c6-b8d4-239563f2def8`.
- Fonte: `rodrigssousa-sudo/medcases-calculadora`, commit publicado
  `79b73f43453f50339fea550c217ca11bb985624c`.
- Autoridade de runtime preservada: emissor existente
  `https://medcasespro.com/api/calculator/session` e
  `https://plankton-app-9dgnu.ondigitalocean.app/api/drugs/{id}`.
- **1.018 arquivos/IDs únicos**, 1.018 PT e 1.018 ES disponíveis. Todos os
  1.018 recibos de leitura anteriores foram reconciliados com os Git blobs
  da árvore publicada consultada nesta missão; zero divergências.
- **827 registros** possuem a declaração existente de homologação/publicação,
  owner/sourceField, 33 campos, hash de aprovação e cálculo não autorizado.
  **191** não satisfazem esse contrato e ficam pendentes. Não há nova
  aprovação médica nesta entrega. O contador `DRUG_APPROVED_VERIFIED` refere-se
  a essas declarações rastreáveis da fonte atual, não a 827 assinaturas novas.
- Paracetamol, Noradrenalina, Ceftriaxona e Metformina foram também confrontados
  com seus payloads de origem atuais: aprovação referenciada correspondente,
  publicação autorizada e PT/ES idênticos. Os quatro arquivos completos
  usados nos testes têm bytes correspondentes aos blobs publicados atuais.
- Zero colisões de ID. O índice bruto possui 2.682 rótulos/aliases e 44 rótulos
  ambíguos; ambiguidades não são resolvidas por aproximação. O gateway não
  expõe todos os keywords do índice bruto; runtime usa apenas rótulos efetivamente
  retornados pela autoridade. O índice completo continua exigindo capability
  Premium. Não se expandiram permissões Free para contornar essa limitação.
- Os números 838/881/43 do manifesto agregado anterior não representam o
  índice privado atual de 1.018. O bundle AI shadow de 838 registros é outro
  artefato, sem autorização de cálculo determinístico, e não substitui o MCC1.

Os valores de disponibilidade ES não significam tradução clínica integral
correta. A fonte atual ainda contém português em campos ES, inclusive nas
amostras verificadas. Os 29 campos anteriormente apontados continuam revisão
editorial separada; não foi realizado censo linguístico dos 1.018 nesta missão.
Não foram inferidas traduções de doses, alertas ou contraindicações.

## Delta implementado

Reutilizou-se o handler comercial já preparado; o pacote original permanece
intacto. `backend-delta/` e os patches unificados alteram somente:

1. `plantao_drug_reference.js`: identidade farmacológica antes de patologias;
   nome/força nominal, perguntas de campos PT/ES e contexto salvo. Intoxicação
   e dose individualizada não viram ficha geral. Estados pendentes não viram
   WEB. Fonte completa, direitos MCC1, expiração e ausência de cálculo mantidos.
2. `plantao_public_restore.js`: contexto do último intercâmbio validado no
   Histórico do próprio usuário; hash, proveniência e correspondência de
   sessão/requestId. Reconsulta da fonte antes da entrega e commit atômico no
   ledger existente. Nenhuma coleção/counter novo. A ficha farmacológica não
   depende artificialmente do ponteiro do catálogo de patologias.

No Flutter existente:

- O renderer reutiliza `lookupField` validado, inclusive após restauração, e
  filtra ajuste renal/hepático ou preparo/infusão sem criar dados. FULL e
  fonte/hash permanecem intactos.
- O loader shadow existente apontava para um domínio que retornou 404. Seu
  endereço padrão foi corrigido para o gateway efetivamente publicado; não se
  ativou o shadow como autoridade de doses ou cálculo.
- O gerenciador de conversa perdia “¿Cuáles son las interacciones?” por plural
  e pontuação. A regressão demonstrou a falha; o delta lexical mínimo passou.
  Novo paciente/outro medicamento continuam separando contextos. Foi removida
  uma variável local sem uso no mesmo arquivo, sem mudança de comportamento.
- O adaptador também aceita os conectores “E quanto ao ajuste renal?” e
  “¿Y el ajuste renal?” usando o mesmo ID validado, sem outra busca semântica.

Não houve modificação da Calculadora, gateway MCC1, modelos de IA, Safe Area
geral, fontes clínicas ou catálogo farmacológico. Não existe segunda base de
doses no backend; as poucas fichas em fixtures são exclusivas dos testes/preview.

## Evidência técnica

| Execução dirigida | Resultado | Limite |
|---|---:|---|
| Handler comercial real + HTTP/SSE + Firestore Emulator | 32/32 | Firebase Auth/MCC1 substituídos explicitamente; documentos reais atuais |
| Continuidade após ajuste dos conectores | 5/5 | Reexecutados somente os cenários afetados |
| Intenção no adaptador existente | 7/7 | Zero rede em negativas; separação de intoxicação/dose infantil |
| Renderer, SSE real loopback, hidratação e loader | 67/67 | Flutter local, sem sessão produtiva |
| Intenção no provider/gerenciador reais | 27/27 | Inclui falha ES reproduzida e corrigida |
| Continuidade/Modo Estudo afetados | 11/11 | Memória e fronteiras preservadas |
| Preparador schema 2 existente | 10/10 | Fixtures técnicas; nenhuma aprovação real criada |
| Validador histórico de decisões existente | 10/10 | Implementação recuperada preservada |
| Importador offline com rejeição individual | 32/32 | Sem importar os 1.000 antigos ou publicar |

Analyzer dirigido: zero erros/warnings; oito infos preexistentes, executado com
`--no-fatal-infos`. Preview Flutter Release e build Web comercial Release PASS.
O checkout mantém os metadados existentes **7.0.2+1704**; não foi rotulado como
nova build iOS 1721. A candidata iOS congelada é um artefato separado e intacto.

Os logs das falhas anteriores às correções foram preservados. Não se alterou
expectativa para forçar PASS. A ausência de posologia, apresentações ou preparo
em fixtures negativas permanece ausência explícita; não há dose por inferência.

## Conferência visual no Flutter real

- `evidence/A-paracetamol-quick-pt.png` e `A-paracetamol-full-pt.png`.
- `evidence/B-noradrenalina-quick-pt.png` — condições/limites de infusão presentes.
- `evidence/C-contraindications-es-source-limitation.png` — campo solicitado,
  incluindo a limitação linguística real da fonte.
- `evidence/D-history-es-sources.png` — hidratação pelo mecanismo real, fontes
  abertas apenas após o botão, ficha/cópia/áudio no rodapé.
- `evidence/C-mobile-footer-375.png` — rodapé adaptativo sem overflow.

Essas capturas são do componente Flutter preparado para release e dos bytes
verificados da fonte. Não são HTML fictício, consulta MCC1 autenticada ou novo
teste físico no aplicativo comercial. A aba Fármacos/WebView não foi auditada.

Cópia e áudio continuam recebendo a fonte integral, com referências; a
localização de `q6h` etc. é só apresentação/leitura. A UI atual confirmou a
execução da cópia, mas o leitor de clipboard do IAB retornou vazio: não se usa
esse recibo isolado para declarar nova conferência do clipboard. A conferência
humana anterior da cópia integral e da voz Luciana permanece evidência anterior,
não uma nova audição nesta missão. Não se alterou o motor de áudio nesta entrega.

## Reprodução e rollback

1. `python3 maintenance/r15-drug-integration/prepare-local-integration.py`
   verifica hashes do pacote original e amostras; monta cópia temporária do
   handler existente e aplica os dois deltas. Não baixa dependências nem credenciais.
2. `python3 maintenance/r15-drug-integration/run-http-integration.py`
   exige porta 8187 livre, inicia somente emulator loopback e o encerra em finally.
   Auth/MCC1 continuam sintéticos; não é um teste remoto.
3. O mesmo comando aceita filtro de teste como argumento; os cinco cenários
   afetados foram executados com `CATALOG authenticated drug continuation`.
4. `node --test maintenance/r15-drug-integration/intent-regression.test.cjs`.
5. Demais comandos e testes constam dos logs/nomes da tabela e caminhos no repo.

`backend-delta-manifest.json` vincula hashes antes/depois. Rollback local do
backend: descartar a cópia temporária ou restaurar os dois arquivos do pacote
original cujo hash `before` corresponde. Nada exige rollback produtivo porque
nada foi publicado. Rollback do checkout: reverter o commit desta entrega,
preservando o baseline f7409fb e os commits UX anteriores.

## Preservação e menor pendência externa

223 arquivos protegidos externos e 1.869 arquivos da candidata 1721 conferidos,
zero divergências. AOT 1721:
`34858dd43cac6286573c02e27cdde9bbd308a933aa863ce9c4b6aedc0d1d5b2f`.
Produção read-only: 100% em `plantaoproxystream-00012-dak`; revisão pronta
`00014-tul` não recebeu tráfego por esta execução. Emulator local encerrado.

Para completar o gate real falta uma sessão comercial legítima disponível ao
operador, autenticada diretamente no aplicativo, permitindo a leitura pelo
fluxo MCC1 existente e registro sanitizado de fonte/tier/capabilities/versão/hash.
Nenhuma senha/token deve ser enviada ao Codex. O problema editorial ES é
independente do roteamento e permanece isolado; não autoriza traduzir medicina.

O schema 2 e o validador histórico estão preservados e tecnicamente prontos
para receber o JSON final no formato documentado. Isso não aprova os 1.000
protocolos nem autoriza publicação. **READY_FOR_DRUG_RELEASE=NO** até comprovar
o fluxo real e resolver o escopo editorial necessário à liberação PT/ES.
