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
//   • InternacionPersistence.loadAllSessions() — SharedPreferences, acesso assíncrono
//   • PacienteInternacaoData — campos demográficos: nome, cama, idade, sexo, diagnostico
//
// NOTA ARQUITETURAL:
//   • Labs são free-text em ExamenesComplementarios.laboratorio → NÃO mapeáveis
//   • Autofill limitado a: idade → ageCtrl, sexo → isFemale, nome/cama como label
//   • Callback onSelected(PacienteSession) — cada tela implementa seu próprio mapeamento
//
// DESIGN SYSTEM:
//   • Paleta canônica MedCases Pro (dark-first) com suporte a modo claro
//   • Border ciano sutil, fundo translúcido, ícone ⚡ de ação
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import 'internacion/services/internacion_persistence.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paleta de cores local (dark-first, idêntica ao design system das tool screens)
// ─────────────────────────────────────────────────────────────────────────────
const _kBg      = Color(0xFF0F1116);
const _kSurface = Color(0xFF1A1D23);
const _kBorder  = Color(0xFF2D3340);
const _kCyan    = Color(0xFF00E5FF);
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
    final surf   = dark ? _kSurface : Colors.white;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: _kCyan.withOpacity(0.12),
          highlightColor: _kCyan.withOpacity(0.06),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: surf.withOpacity(dark ? 0.80 : 0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _kCyan.withOpacity(0.45),
                width: 1.3,
              ),
              boxShadow: dark
                  ? [
                      BoxShadow(
                        color: _kCyan.withOpacity(0.06),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '⚡',
                  style: TextStyle(fontSize: 15),
                ),
                const SizedBox(width: 8),
                Text(
                  isEs
                      ? 'Importar datos del Paciente'
                      : 'Importar dados do Paciente',
                  style: TextStyle(
                    color: _kCyan,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _kCyan.withOpacity(0.80),
                  size: 18,
                ),
              ],
            ),
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

  Future<void> _loadSessions() async {
    try {
      final sessions = await InternacionPersistence.loadAllSessions();
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _loading  = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _sessions = [];
          _loading  = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEs   = widget.isEs;
    final dark   = widget.dark;
    final bg     = dark ? _kSurface : Colors.white;
    final handleColor = dark ? _kBorder : const Color(0xFFCBD5E1);
    final txt    = dark ? Colors.white : const Color(0xFF0F1116);
    final sub    = dark ? _kTextSub   : const Color(0xFF64748B);
    final itemBg = dark ? _kBg        : const Color(0xFFF8FAFC);
    final itemBorder = dark ? _kBorder : const Color(0xFFE2E8F0);

    return DraggableScrollableSheet(
      initialChildSize: 0.50,
      minChildSize:     0.35,
      maxChildSize:     0.85,
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
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _kCyan.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text('⚡', style: TextStyle(fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 10),
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
                              color: _kCyan,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isEs ? 'Cargando pacientes…' : 'Carregando pacientes…',
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
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final session = _sessions![i];
                            return _PatientListItem(
                              session: session,
                              dark:    dark,
                              isEs:    isEs,
                              txt:     txt,
                              sub:     sub,
                              itemBg:  itemBg,
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
// _PatientListItem — item de cada paciente na lista
// ─────────────────────────────────────────────────────────────────────────────
class _PatientListItem extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    final p = session.paciente;

    // Label secundária: Leito · Idade · Sexo
    final parts = <String>[];
    if (p.cama.isNotEmpty) {
      parts.add('${isEs ? "Cama" : "Leito"} ${p.cama}');
    }
    if (p.idade.isNotEmpty) {
      parts.add('${p.idade} ${isEs ? "años" : "anos"}');
    }
    if (p.sexo.isNotEmpty) {
      final sexLabel = p.sexo.toUpperCase() == 'F'
          ? (isEs ? 'Femenino' : 'Feminino')
          : (isEs ? 'Masculino' : 'Masculino');
      parts.add(sexLabel);
    }
    final subtitle = parts.join(' · ');

    // Inicial do nome para avatar
    final initial = p.nome.isNotEmpty ? p.nome[0].toUpperCase() : '?';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: _kCyan.withOpacity(0.10),
        highlightColor: _kCyan.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: itemBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: itemBorder, width: 1),
          ),
          child: Row(
            children: [
              // ── Avatar ──────────────────────────────────────────────────
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _kCyan.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: _kCyan,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // ── Texto ─────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.nome.isEmpty
                          ? (isEs ? 'Sin nombre' : 'Sem nome')
                          : p.nome,
                      style: TextStyle(
                        color: txt,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: sub,
                          fontSize: 11.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (p.diagnostico.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        p.diagnostico,
                        style: TextStyle(
                          color: sub.withOpacity(0.75),
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // ── Ícone de ação ─────────────────────────────────────────
              const SizedBox(width: 8),
              Icon(
                Icons.input_rounded,
                color: _kCyan.withOpacity(0.70),
                size: 20,
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
