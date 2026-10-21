# Fonte farmacológica e apresentação

## Conectividade

`DRUG_SOURCE_CONNECTION=NOT_VERIFIED` para a sessão comercial atual. A WebView temporária da aba Fármacos foi excluída da auditoria por determinação do usuário. Nenhuma nova chamada MCC1, token, credencial, entitlement, cálculo ou prescrição foi criada.

Existe recibo real histórico de 16/10 em `MEDCASES-R15-COMMERCIAL-PATCH/P0-MCC1-SERVER-REAL.json`: emissor e ficha HTTP 200, com direitos Premium existentes. Isso não prova conectividade atual. Adaptador MCC1 existente foi exercitado localmente com transporte sintético e documentos históricos reais, claramente separado de MCC1 real.

## Conteúdo preservado

Paracetamol PT/ES: snapshots históricos reais. Noradrenalina, Ceftriaxona e Metformina: documentos gerados pelo adaptador existente a partir das fontes congeladas, sem rede ou inferência clínica. Identificadores, versões e hashes constam de `named-drug-fixture-provenance.json`. Versão histórica `clinical-data-v1-b2437901deb78b1e`.

Projeção inicial NOME/USO/POSOLOGIA/CONTRAINDICAÇÕES preserva condições e populações, inclusive ajustes renais/hepáticos, preparo, infusão, precauções e limites. Campo novo/desconhecido implica FULL; não se presume omissão segura. Apenas campos literalmente duplicados são deduplicados.

## Espanhol

Rótulos PT/ES e preservação dos valores passaram nos testes. A fonte histórica ES contém 29 campos em português, pendência editorial independente já documentada. Não foram traduzidas doses, contraindicações ou condições por inferência. Não declarar tradução clínica ES integralmente aprovada.

As 18 verificações do renderer incluem os quatro fármacos e preservação dos dados. São testes de implementação, não revisão médica ou autorização comercial.

## Limite de apresentação preservado

Fontes do documento histórico são exibidas somente pelo botão de referências; os valores originais, doses, condições e idioma da fonte não foram reescritos. Os 29 campos ES em português continuam pendência editorial separada. Nenhuma conexão MCC1 atual foi declarada verificada por fixture, nem a WebView temporária foi revisada. A apresentação compacta não omite condições farmacológicas para atingir arbitrariamente 80–150 palavras.
