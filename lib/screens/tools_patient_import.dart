// ══════════════════════════════════════════════════════════════════════════════
// tools_patient_import.dart — BUILD 426-MULTI-PATIENT-AUTOFILL
//
// Infraestrutura compartilhada de importação de pacientes para os 4 módulos
// de ferramentas de cálculo científico (Nefrología, Cardio, Electrolitos, Hepatología).
//
// ARQUITETURA:
//   • ToolsPatientImportChip — chip fosco com borda ciano para acionar o modal
//   • showToolsPatientSelectionSheet() — bottom sheet elegante com lista de pacientes
//
// FONTE DE DADOS:
//   • InternacionFirestoreService.sessionsStream(uid) — mesma lista visível de Pacientes
//   • PacienteSession — identidade, demografia e patientKey preservados
//
// NOTA ARQUITETURAL:
//   • Labs são free-text em ExamenesComplementarios.laboratorio → NÃO mapeáveis
//   • Autofill limitado a: idade → ageCtrl, sexo → isFemale, nome/cama como label
//   • Callback onSelected(PacienteSession) — cada tela implementa seu próprio mapeamento
//
// DESIGN SYSTEM:
//   • Paleta canônica MedCases Pro (dark-first) com suporte a modo claro
//   • Border ciano sutil, fundo translúcido, ícone  de ação
// ══════════════════════════════════════════════════════════════════════════════

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'internacion/services/internacion_firestore_service.dart';
import 'internacion/services/internacion_persistence.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paleta de cores local (dark-first, idêntica ao design system das tool screens)
// ─────────────────────────────────────────────────────────────────────────────
const _kBg = Color(0xFF0F1116);
const _kSurface = Color(0xFF1A1D23);
const _kBorder = Color(0xFF2D3340);
const _kAccentBrand = Color(0xFF0D6B57);
// BUILD 450/451: Azul Petróleo — acento no Light Mode
const _kPetroleo = Color(0xFF1A365D);
const _kTextSub = Color(0xFF8B9BB4);

// ═════════════════════════════════════════════════════════════════════════════
// ToolsPatientImportChip — Widget chip reutilizável
// ═════════════════════════════════════════════════════════════════════════════

class ToolsPatientImportChip extends StatelessWidget {
  final bool isEs;
  final bool dark;
  final VoidCallback onTap;

  const ToolsPatientImportChip({
    super.key,
    required this.isEs,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // MEDCASES_FERRAMENTAS_CANONICAL_FLAT_SURFACE_CONVERGENCE_V1_B_R0_IMPORT
    const accent = Color(0xFF0D6B57);
    final border = dark
        ? const Color(0xFF374151)
        : const Color(0xFFD8E0E7);
    final surface = dark
        ? const Color(0xFF252930)
        : const Color(0xFFFFFFFF);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        splashColor: accent.withOpacity(0.10),
        highlightColor: accent.withOpacity(0.05),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: dark ? border : accent.withOpacity(0.55),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  isEs
                      ? 'Importar datos del Paciente'
                      : 'Importar dados do Paciente',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: accent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: accent,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// showToolsPatientSelectionSheet — bottom sheet de seleção de pacientes
//
// Parâmetros:
//   context     — BuildContext da tela chamadora
//   isEs        — idioma (true = Español, false = Português)
//   dark        — modo escuro/claro
//   onSelected  — callback com PacienteSession selecionado
//
// Comportamento:
//   1. Abre o bottom sheet imediatamente com estado de loading
//   2. Carrega InternacionPersistence.loadAllSessions() assincronamente
//   3. Exibe lista de pacientes com nome, leito e idade
//   4. Ao selecionar, fecha o modal e invoca onSelected()
// ═════════════════════════════════════════════════════════════════════════════
Future<void> showToolsPatientSelectionSheet({
  required BuildContext context,
  required bool isEs,
  required bool dark,
  required void Function(PacienteSession session) onSelected,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.55),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) => _PatientSelectionSheet(
      isEs: isEs,
      dark: dark,
      onSelected: (session) {
        Navigator.of(sheetCtx).pop();
        onSelected(session);
      },
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _PatientSelectionSheet — widget interno do bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _PatientSelectionSheet extends StatefulWidget {
  final bool isEs;
  final bool dark;
  final void Function(PacienteSession) onSelected;

  const _PatientSelectionSheet({
    required this.isEs,
    required this.dark,
    required this.onSelected,
  });

  @override
  State<_PatientSelectionSheet> createState() => _PatientSelectionSheetState();
}

class _PatientSelectionSheetState extends State<_PatientSelectionSheet> {
  List<PacienteSession>? _sessions;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  // V1-K-R2: consome exatamente a stream visível usada pela aba Pacientes.
  // Não agrega documentos legados nem aplica uma segunda projeção local.
  //
  // BUILD 454-1: Auth race condition fix.
  // PROBLEMA: FirebaseAuth.currentUser == null nos primeiros ms do boot (Web e iOS
  // cold-start). Se _loadSessions() dispara antes do token ser propagado, uid fica
  // vazio → Firestore retorna permission-denied → lista vazia exibida ao usuário.
  //
  // SOLUÇÃO: _resolveUid() aguarda authStateChanges() com timeout de 5s.
  // Se currentUser já está disponível → retorna imediatamente (zero overhead).
  // Se null → escuta o stream até o primeiro evento não-nulo (token propagado).
  // Timeout: retorna uid vazio e a lista canônica permanece vazia.
  static Future<String> _resolveUid({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    // Caminho feliz: token já disponível (mobile/iOS pós-boot)
    final current = FirebaseAuth.instance.currentUser;
    if (current != null) return current.uid;

    // Web cold-start: aguarda authStateChanges com timeout
    try {
      final user = await FirebaseAuth.instance
          .authStateChanges()
          .where((u) => u != null)
          .first
          .timeout(timeout);
      return user?.uid ?? '';
    } catch (_) {
      // Timeout ou erro — não consulta Firestore sem identidade canônica
      return '';
    }
  }

  Future<void> _loadSessions() async {
    try {
      final uid = await _resolveUid();
      if (uid.isEmpty) {
        if (!mounted) return;
        setState(() {
          _sessions = const <PacienteSession>[];
          _loading = false;
        });
        return;
      }

      // V1-K-R2: mesma fonte visível e mesma semântica da aba Pacientes.
      // Não agrega fonte histórica nem aplica uma segunda projeção local.
      final patientsSessions =
          await InternacionFirestoreService.sessionsStream(uid)
              .firstWhere(
                (_) => FirebaseAuth.instance.currentUser?.uid == uid,
              )
              .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      setState(() {
        _sessions = patientsSessions;
        _loading = false;
      });
      debugPrint(
        '[V1-K-R2-R3][TOOLS_PATIENTS] mesma fonte visual de Pacientes: '
        '${patientsSessions.length}',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sessions = const <PacienteSession>[];
        _loading = false;
      });
      debugPrint(
        '[V1-K-R2-R3][TOOLS_PATIENTS] erro na stream compartilhada: $error',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEs = widget.isEs;
    final dark = widget.dark;
    final bg = dark ? _kSurface : Colors.white;
    final handleColor = dark ? _kBorder : const Color(0xFFCBD5E1);
    final txt = dark ? Colors.white : const Color(0xFF0F1116);
    final sub = dark ? _kTextSub : const Color(0xFF64748B);
    final itemBg = dark ? _kBg : const Color(0xFFF8FAFC);
    final itemBorder = dark ? _kBorder : const Color(0xFFE2E8F0);

    return DraggableScrollableSheet(
      initialChildSize: 0.50,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(dark ? 0.40 : 0.10),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Handle decorativo ────────────────────────────────────────────
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: handleColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // ── Título ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEs ? 'Seleccionar Paciente' : 'Selecionar Paciente',
                        style: TextStyle(
                          color: txt,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        isEs
                            ? 'Lista de pacientes internados activos'
                            : 'Lista de pacientes internados ativos',
                        style: TextStyle(
                          color: sub,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Divider ──────────────────────────────────────────────────────
            Divider(color: itemBorder, height: 1, thickness: 1),

            // ── Conteúdo: loading / vazio / lista ────────────────────────────
            Expanded(
              child: _loading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              // BUILD 451: spinner petróleo no light
                              color: dark ? _kAccentBrand : _kPetroleo,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isEs
                                ? 'Cargando pacientes…'
                                : 'Carregando pacientes…',
                            style: TextStyle(color: sub, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : (_sessions == null || _sessions!.isEmpty)
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person_off_outlined,
                                color: sub,
                                size: 40,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                isEs
                                    ? 'No hay pacientes guardados'
                                    : 'Nenhum paciente salvo',
                                style: TextStyle(
                                  color: sub,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isEs
                                    ? 'Primero registra pacientes en la pestaña Paciente'
                                    : 'Primeiro cadastre pacientes na aba Paciente',
                                style: TextStyle(color: sub, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: _sessions!.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            thickness: 0.6,
                            color: itemBorder.withOpacity(0.55),
                          ),
                          itemBuilder: (_, i) {
                            final session = _sessions![i];
                            return _PatientListItem(
                              session: session,
                              dark: dark,
                              isEs: isEs,
                              txt: txt,
                              sub: sub,
                              itemBg: itemBg,
                              itemBorder: itemBorder,
                              onTap: () => widget.onSelected(session),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PatientListItem — linha plana de paciente na superfície do bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _PatientListItem extends StatelessWidget {
  // V1-L-R1-R5 — linha flat sem raio e sem card aninhado.
  final PacienteSession session;
  final bool dark;
  final bool isEs;
  final Color txt;
  final Color sub;
  final Color itemBg;
  final Color itemBorder;
  final VoidCallback onTap;

  const _PatientListItem({
    required this.session,
    required this.dark,
    required this.isEs,
    required this.txt,
    required this.sub,
    required this.itemBg,
    required this.itemBorder,
    required this.onTap,
  });

  String _explicitSeverityToken() {
    final dynamic dynamicSession = session;
    final dynamic dynamicPatient = session.paciente;
    final readers = <Object? Function()>[
      () => dynamicPatient.gravidade,
      () => dynamicPatient.severity,
      () => dynamicPatient.classificacaoRisco,
      () => dynamicPatient.classificacao,
      () => dynamicPatient.priority,
      () => dynamicPatient.riskLevel,
      () => dynamicPatient.corRisco,
      () => dynamicPatient.riskColor,
      () => dynamicSession.gravidade,
      () => dynamicSession.severity,
      () => dynamicSession.classificacaoRisco,
      () => dynamicSession.classificacao,
      () => dynamicSession.priority,
      () => dynamicSession.riskLevel,
      () => dynamicSession.corRisco,
      () => dynamicSession.riskColor,
    ];

    for (final read in readers) {
      try {
        final token = read()?.toString().trim().toLowerCase() ?? '';
        if (token.isNotEmpty) return token;
      } catch (_) {}
    }
    return '';
  }

  Color _severityColor() {
    final token = _explicitSeverityToken();
    if (token.contains('vermelh') ||
        token.contains('red') ||
        token.contains('critical') ||
        token.contains('crític') ||
        token.contains('critic')) {
      return const Color(0xFFEF4444);
    }
    if (token.contains('laranja') ||
        token.contains('orange') ||
        token.contains('urgent')) {
      return const Color(0xFFF97316);
    }
    if (token.contains('amarel') || token.contains('yellow')) {
      return const Color(0xFFEAB308);
    }
    if (token.contains('verde') ||
        token.contains('green') ||
        token.contains('stable') ||
        token.contains('estável') ||
        token.contains('estavel')) {
      return const Color(0xFF22C55E);
    }
    if (token.contains('azul') || token.contains('blue')) {
      return const Color(0xFF3B82F6);
    }

    // Sem gravidade explícita, usa apenas o acento clínico existente.
    // Nenhuma classificação clínica é inferida pelo diagnóstico.
    return dark ? _kAccentBrand : _kPetroleo;
  }

  @override
  Widget build(BuildContext context) {
    final patient = session.paciente;
    final parts = <String>[];
    if (patient.cama.trim().isNotEmpty) {
      parts.add('${isEs ? "Cama" : "Leito"} ${patient.cama.trim()}');
    }
    if (patient.idade.trim().isNotEmpty) {
      parts.add('${patient.idade.trim()} ${isEs ? "años" : "anos"}');
    }
    if (patient.sexo.trim().isNotEmpty) {
      final sex = patient.sexo.trim().toUpperCase();
      parts.add(
        sex == 'F'
            ? (isEs ? 'Femenino' : 'Feminino')
            : (isEs ? 'Masculino' : 'Masculino'),
      );
    }

    final name = patient.nome.trim().isEmpty
        ? (isEs ? 'Paciente sin nombre' : 'Paciente sem nome')
        : patient.nome.trim();
    final subtitle = parts.join(' · ');
    final diagnosis = patient.diagnostico.trim();
    final severityColor = _severityColor();

    return Material(
      color: itemBg.withOpacity(0),
      child: InkWell(
        onTap: onTap,
        splashColor: severityColor.withOpacity(0.10),
        highlightColor: severityColor.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: ColoredBox(
                  color: severityColor,
                  child: const SizedBox(width: 5, height: 48),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: txt,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: sub,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (diagnosis.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        diagnosis,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: sub.withOpacity(0.78),
                          fontSize: 12.5,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 17,
                color: itemBorder.withOpacity(0.92),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// parseAgeFromString — helper seguro para converter string de idade em int
// Trata casos como "32", "32 anos", "32 años", "32a" → 32
// Retorna null se não parseable.
// ═════════════════════════════════════════════════════════════════════════════
int? parseAgeFromString(String ageStr) {
  if (ageStr.isEmpty) return null;
  try {
    // Remove tudo que não seja dígito e tenta parsear o início numérico
    final cleaned = ageStr.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return null;
    final v = int.tryParse(cleaned);
    if (v == null || v <= 0 || v > 130) return null;
    return v;
  } catch (_) {
    return null;
  }
}
