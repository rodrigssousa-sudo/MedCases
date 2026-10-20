# Limpeza pendente — preservação explícita

Nenhum arquivo foi apagado. Nenhuma deduplicação de fontes clínicas foi realizada. Cópias de release, rollback, testes, fixtures, versões PT/ES e arquivos nativos não são lixo.

## REVISÃO NECESSÁRIA

- `lib/home_v2/migration_blocks/_QuickShortcuts.dart` — preservado; referência textual/analyzer não demonstra remoção segura considerando integrações e histórico.
- `lib/home_v2/migration_blocks/_HomeCalculadoraFarmacosCard.dart` — preservado; referência textual/analyzer não demonstra remoção segura considerando integrações e histórico.
- `lib/home_v2/migration_blocks/_HomeBibliotecaHClinicaRow.dart` — preservado; referência textual/analyzer não demonstra remoção segura considerando integrações e histórico.
- `lib/home_v2/migration_blocks/_HomeMiGuardiaSection.dart` — preservado; referência textual/analyzer não demonstra remoção segura considerando integrações e histórico.
- `lib/home_v2/migration_blocks/_HistorialCompactCard.dart` — preservado; referência textual/analyzer não demonstra remoção segura considerando integrações e histórico.
- `lib/home_v2/migration_blocks/_HomeAdultoPediatriaRow.dart` — preservado; referência textual/analyzer não demonstra remoção segura considerando integrações e histórico.
- `lib/home_v2/migration_notes_reference.dart` — preservado; referência textual/analyzer não demonstra remoção segura considerando integrações e histórico.
- `lib/services/ai_gateway_service.dart` — preservado; referência textual/analyzer não demonstra remoção segura considerando integrações e histórico.
- `lib/services/auth_service.dart` — preservado; referência textual/analyzer não demonstra remoção segura considerando integrações e histórico.
- `lib/services/firestore_service.dart` — preservado; referência textual/analyzer não demonstra remoção segura considerando integrações e histórico.
- `lib/screens/library_screen.dart` — preservado; referência textual/analyzer não demonstra remoção segura considerando integrações e histórico.

## PROTEGIDO / MANTER

- Candidata 1721: 1.869 hashes conferidos, sem divergência.
- Backend R15, catálogos, aprovações, MCC1, Calculadora, ledger, auth/entitlements, Firestore, fontes PT/ES.
- Pacotes e checkouts comerciais anteriores; alterações não commitadas no Plantão-R8 e trabalhos de outras conversas.
- Schema 1 antigo e schema 2: finalidade diferente; não fundir ou remover por nomes parecidos.
- Imports condicionais native/web, assets, rotas por strings, scripts operacionais e evidências.

## REMOÇÃO SEGURA EXECUTADA

Três imports med_typography sem uso nos componentes SoapEvaluacion/SoapPlan/SoapSubjetivo e quatro variáveis locais de cores puras em library_screen. Ver removals.json e cleanup.patch. Não há aprovação para remover os candidatos acima.

## Falhas preexistentes registradas

O analyzer inicial apresentou 3.186 diagnósticos, incluindo blocos de migração e getters/parâmetros antigos. Não foi feito silenciamento ou exclusão de pastas. Os testes legados de transport_done e dois contratos de memória Estudo falham; os arquivos envolvidos estão byte a byte iguais ao baseline desta missão. Não foram alteradas expectativas para obter PASS.

