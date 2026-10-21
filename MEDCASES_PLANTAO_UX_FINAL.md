# Apresentação Plantão PT/ES — resultado local

## Alterações

Foi corrigido o retorno antecipado do renderer existente que eliminava as ações das referências verificadas. O contrato de apresentação e a reconciliação R12/1721 foram reutilizados; não foi criada outra interface clínica.

EXECUTIVE aprovado e compatível apresenta quatro blocos, conserva dose, unidade, via, intervalo, estratégia, duração, condições e limites. Tratamento concomitante permanece associado, nunca alternativa equivalente. FULL sem executivo permanece disponível imediatamente, sem resumo automaticamente homologado. Fonte desconhecida ou contrato inválido mantém FULL.

Uma seção de referências recolhível, inicialmente fechada; uma expansão/recolhimento; cópia integral com referências; áudio e cancelamento no rodapé existente. Metadados técnicos são retirados somente da apresentação. Fonte integral permanece intacta. Verde institucional preservado. Alvos de ação têm pelo menos 48 pixels.

## Conferência humana e visual

Preview Flutter local usa o renderer e o serviço TTS reais, sem Firebase, modelo, consulta clínica ou consumo de franquia. Aprovações das fixtures A/B são explicitamente sintéticas. C/D usam documento farmacológico histórico e hidratação real local; não representam nova homologação médica.

O operador confirmou cópia integral com FULL_SENTINEL e referência, e ouviu a leitura. Relatou voz robótica/travamentos: a primeira correção de velocidade melhorou, mas não eliminou travamentos. O serviço Web encaminhava 0,47 diretamente ao motor cuja escala natural é 1,0. Adaptador agora envia 0,94 no Web e mantém 0,47 nativo. Seleção feminina é prioritária quando declarada ou reconhecida no catálogo de vozes instalado, sem inventar gênero para vozes desconhecidas.

O plugin Web também força pause/resume a cada 14 segundos para voz remota/padrão. A leitura Web foi dividida em cláusulas curtas, preservando integralmente a sequência de texto e números. Sem pitch artificial, serviços pagos, dependências novas ou mudança no iOS 1721. Qualidade humana final e disponibilidade de voz feminina dependem de confirmação no navegador/aparelho; a primeira reprodução atualizada reportou voz padrão, não uma voz feminina identificada.

A aba Fármacos comercial não foi auditada, conforme orientação expressa: sua WebView temporária não foi considerada defeito do produto.

Capturas e recibos: `maintenance/r15-ux/evidence/`. O clipboard virtual da ferramenta retornou vazio; a prova de cópia é a confirmação do operador, separadamente registrada.

## Fechamento do áudio — confirmação real

Na revisão C, o Chrome expôs e selecionou Luciana. O serviço resolve a voz antes da segmentação: voz selecionada recebe passagens contínuas de até 900 caracteres, respeitando frases; apenas o padrão Web não identificado usa cláusulas menores. Uma demonstração não clínica com títulos e parágrafos foi efetivamente reproduzida; o operador confirmou “Sim, ficou adequada”. Não se tratou a fixture com marcadores técnicos como avaliação de naturalidade.

`AUDIO_PLAYBACK=PASS` e qualidade aprovada no Chrome local. `audio-continuous-verified.log`: 33 PASS, incluindo continuidade da primeira reprodução com voz feminina. O navegador interno não expôs voz PT identificável; sua qualidade padrão não foi aprovada. Não foi alterada a voz global do sistema nem instalado serviço de síntese pago. Teste físico iOS de áudio não executado.

## Adendos finais — rodapé e fontes somente sob ação

O rodapé compartilhado existente foi consolidado: hora real da mensagem à esquerda, referências e expansão quando disponíveis; ouvir e copiar à direita. Alvos de 48 px, rótulos adaptativos e ícones com tooltip/semântica em 320/375 px; sem emojis nos controles. Verde institucional #009C3B apenas ativo. Há uma única linha superior sutil; a linha inferior redundante do preview foi removida.

Fontes técnicas, URLs e seções de referências são projetadas somente no botão de referências, inicialmente fechado, também no FULL e no Modo Estudo. Rótulos de citação comprovadamente ligados às fontes são retirados apenas do corpo visível; códigos clínicos desconhecidos permanecem. Texto clínico de links e seções posteriores à bibliografia são preservados. O original salvo, hashes e cópia integral mantêm a fonte intacta. Referências relacionadas ao caso usam o mesmo controle, sem bloco duplicado fora do rodapé.

A restauração mantém o horário persistido, não a hora de reabertura. Mensagens antigas sem horário recuperável mostram “—”. Não há nova consulta na hidratação. O preview é um instrumento local, sem produção ou consumo de franquia.

`references-footer-delivery-tests.log`: 70 PASS na regressão final de referências, rodapé, renderização e hidratação. `audio-continuous-verified.log`: 33 PASS de áudio. `loopback-sse-final.log`: 8 PASS HTTP/SSE em localhost. As suítes se sobrepõem e não são somadas.

A confirmação humana da voz feminina Luciana adequada continua válida no Chrome local. Não comprova voz ou áudio no iOS. A aba Fármacos comercial continua excluída conforme instrução do operador.

## Entrega verificada

Build final do preview PASS (83,4 s); build Web comercial local PASS (96,3 s). Logs `preview-build-final-source.log` e `web-build-final-source.log`. Após o último refinamento do rótulo “Fonte técnica:”, os 25 testes do rodapé passaram em `references-technical-label-final.log`; não foi repetida a suíte de 70 casos sem necessidade.

Conferência visual real do Flutter no navegador interno Chromium: 320, 375, 768 e 1200 px, botão único, fontes inicialmente ocultas no Estudo e no integral, revelação somente sob ação e nenhuma linha inferior. Capturas finais `final-desktop-1200.png`, `final-mobile-es-375.png`, `final-mobile-pt-320.png`, `final-tablet-768.png`, `final-full-references-closed.png`, `final-study-references-closed.png` e `final-study-references-open.png`. Capturas anteriores sem prefixo `final-` documentam estados intermediários, não o resultado final.

O áudio foi aprovado pelo operador no Chrome; a tentativa de nova conferência do rodapé pelo aplicativo nativo Chrome não terminou. A prova visual final do rodapé é do Flutter no navegador interno, sem converter essa limitação em PASS de Chrome nativo.

A matriz completa, incluindo limites ainda não comprovados em produção, está em `maintenance/r15-ux/RESULTADO.json`. Resultado global PARTIAL: conectividade MCC1 atual, relação autorizada do protocolo toxicológico e revisão editorial ES permanecem fora da comprovação desta entrega. O pedido visual de referências e rodapé passou localmente. Nenhum deploy foi executado.

## Adendo farmacológico posterior

A evolução local posterior ao commit inicial está documentada em `MEDCASES_R15_DRUG_MINIMAL.md`, com manifesto próprio. O recibo `MEDCASES_R15_UX_FINAL_SHA256.json` continua referindo-se ao commit original; não deve ser comparado ao código posterior como se fosse a mesma revisão. Fontes clínicas, cálculo, direitos e iOS 1721 permanecem preservados.
