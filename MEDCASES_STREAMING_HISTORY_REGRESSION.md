# Streaming e Histórico — regressão dirigida

## Evidência executada

- 8 testes com HTTP real em 127.0.0.1 e parser/GptSseClient reais: protocolo e fármaco PT/ES, término completo e interrupção, bytes UTF-8 fragmentados, uma requisição por cenário.
- Eventos verificados não expõem FULL provisório como texto parcial. Sem transport_done não há AiCompleted: a interrupção é erro, não sucesso recuperado.
- A URL nominal de produção aparece em mensagens do cliente, mas o BaseClient do ensaio rejeita destinos fora do loopback e reencaminha a requisição antes do IO. Nenhuma consulta produtiva foi enviada.
- Hidratação farmacológica local exige integridade do documento e correspondência com texto integral, idioma e proveniência. Corrupção conserva o texto original sem promover aprovação.
- Executivo no Histórico exige leitura atual de pointer, manifesto, chunks, identidade, aprovação e hashes; falha/offline/pendência mantém FULL. O documento salvo não autoautoriza sua apresentação.
- Cancelamento por geração e mounted/restoreGeneration evita aplicação tardia em outra conversa.

## Testes

`loopback-sse.log`: 8 PASS. `history-authority.log`: 4 PASS. `audio-renderer-history-final.log`: 53 PASS antes do último ajuste específico de cláusulas Web; `audio-short-web-final.log`: 32 PASS após ele. `renderer-history-last-change.log`: 22 PASS. `focused-regression.log`: 51 PASS anteriores e sobrepostos; inclui memória Estudo e hidratação. `prepared-backend-directed.log`: 18 PASS locais no backend preparado.

Não somar suítes sobrepostas. Não converter transporte localhost em SSE produtivo observado, nem autenticação sintética em prova Free/Premium real. Autorização comercial e regras de áudio existentes foram preservadas e testadas localmente; não houve alteração de direitos.

## Rollback

Baseline anterior preservado em 923ff75e8eef6a1e5b352d166217de95be624ff8. Aplicar reversão do novo commit local, sem reset destrutivo e sem tocar produção. Não há migração, dependência nova ou escrita remota a desfazer. A candidata 1721, fontes clínicas, calculadora e backend R15 congelados foram conferidos por hash.

## Limites

Analyzer estrito não fica verde: 14 warnings preexistentes nos arquivos legados; nenhum erro de compilação. A comparação com cópia exata do baseline está anexada. Não foi feita limpeza geral para eliminar avisos alheios ao delta.

Prontidão técnica para receber o JSON schema 2 permanece preservada; nenhum protocolo novo foi importado, homologado ou publicado nesta missão.

## Complemento do rodapé e restauração

Horário real preservado por mensagem/hidratação; referência recolhida não altera o texto integral salvo. Histórico farmacológico continua condicionado a hash, idioma e proveniência; não há autoaprovação de síntese. Rodapé e referências compartilham as mesmas ações nos renderers Plantão/Estudo. Regressão final de 70 casos: `references-footer-delivery-tests.log`. Não houve alteração no contrato de término SSE depois dos oito casos loopback aprovados.
