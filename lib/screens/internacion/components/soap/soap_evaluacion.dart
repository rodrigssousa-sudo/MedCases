// ─────────────────────────────────────────────────────────────────────────────
// A — EVALUACIÓN
// Seletores de estado clínico + problemas ativos.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../../models/evolucion_model.dart';
import '../internacion_theme.dart';

class SoapEvaluacion extends StatefulWidget {
  final EvaluacionData data;
  final ValueChanged<EvaluacionData> onChanged;
  final bool dark;
  final String lang;

  const SoapEvaluacion({
    super.key,
    required this.data,
    required this.onChanged,
    required this.dark,
    required this.lang,
  });

  @override
  State<SoapEvaluacion> createState() => _SoapEvaluacionState();
}

class _SoapEvaluacionState extends State<SoapEvaluacion> {
  late final TextEditingController _notasCtrl;
  late final TextEditingController _problemaCtrl;

  bool get isEs => widget.lang == 'es';

  @override
  void initState() {
    super.initState();
    _notasCtrl = TextEditingController(text: widget.data.notasEvaluacion)
      ..selection = TextSelection.collapsed(
          offset: widget.data.notasEvaluacion.length);
    _problemaCtrl = TextEditingController();
    // Build 205 FIX: addListener captura mudanças programáticas (.text = valor)
    // que NÃO disparam onChanged do TextField (ex: injeção IA).
    _notasCtrl.addListener(_onNotasEvalChanged);
  }

  void _onNotasEvalChanged() {
    final v = _notasCtrl.text;
    if (v != widget.data.notasEvaluacion) {
      widget.onChanged(widget.data.copyWith(notasEvaluacion: v));
    }
  }

  // Build 205 FIX: sincroniza _notasCtrl quando widget.data.notasEvaluacion
  // muda externamente (injeção IA). _problemaCtrl é campo de entrada temporário
  // (não representa estado persistido), portanto não precisa de sync.
  @override
  void didUpdateWidget(SoapEvaluacion oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newNotas = widget.data.notasEvaluacion;
    if (newNotas != oldWidget.data.notasEvaluacion &&
        newNotas != _notasCtrl.text) {
      _notasCtrl.text = newNotas;
      _notasCtrl.selection = TextSelection.collapsed(offset: newNotas.length);
    }
  }

  @override
  void dispose() {
    _notasCtrl.removeListener(_onNotasEvalChanged);
    _notasCtrl.dispose();
    _problemaCtrl.dispose();
    super.dispose();
  }

  void _addProblema(String v) {
    if (v.trim().isEmpty) return;
    final lista = [...widget.data.problemasActivos, v.trim()];
    widget.onChanged(widget.data.copyWith(problemasActivos: lista));
    _problemaCtrl.clear();
  }

  void _removeProblema(int idx) {
    final lista = [...widget.data.problemasActivos]..removeAt(idx);
    widget.onChanged(widget.data.copyWith(problemasActivos: lista));
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final dark = widget.dark;
    final theme = InternacionTheme(dark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Estado clínico ───────────────────────────────────────────────────
        Text(
          (isEs ? '¿CÓMO EVOLUCIONA EL PACIENTE?' : 'COMO O PACIENTE EVOLUI?').toUpperCase(),
          style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8,
            color: theme.labelColor,
          ),
        ),
        const SizedBox(height: 10),
        Row(children: EstadoClinical.values.map((estado) {
          final isSelected = d.estado == estado;
          final col = Color(estado.colorValue);
          return Expanded(
            child: GestureDetector(
              onTap: () => widget.onChanged(
                d.copyWith(estado: isSelected ? null : estado),
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: EdgeInsets.only(
                  right: estado != EstadoClinical.empeorando ? 8 : 0,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? col.withValues(alpha: dark ? 0.18 : 0.12)
                      : (dark ? const Color(0xFF1E2330) : const Color(0xFFF3F4F6)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? col : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _iconForEstado(estado),
                      size: 20,
                      color: isSelected ? col : theme.textSecondary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      estado.label(widget.lang),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                        color: isSelected ? col : theme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList()),
        const SizedBox(height: 16),

        // ── Problemas activos ────────────────────────────────────────────────
        Text(
          (isEs ? 'PROBLEMAS ACTIVOS' : 'PROBLEMAS ATIVOS').toUpperCase(),
          style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8,
            color: theme.labelColor,
          ),
        ),
        const SizedBox(height: 8),

        // Lista de problemas
        if (d.problemasActivos.isNotEmpty) ...[
          ...d.problemasActivos.asMap().entries.map((e) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF1E2330) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: dark ? const Color(0xFF2D3340) : const Color(0xFFDDE1E6),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(e.value, style: TextStyle(
                    fontSize: 13,
                    color: dark ? Colors.white : const Color(0xFF1A1D23),
                  )),
                ),
                GestureDetector(
                  onTap: () => _removeProblema(e.key),
                  child: Icon(Icons.close_rounded, size: 14,
                      color: theme.textSecondary),
                ),
              ],
            ),
          )),
          const SizedBox(height: 6),
        ],

        // Input para adicionar problema
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF1A1D23) : const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: dark ? const Color(0xFF2D3340) : const Color(0xFFDDE1E6),
                    width: 0.8,
                  ),
                ),
                child: TextField(
                  controller: _problemaCtrl,
                  onSubmitted: _addProblema,
                  style: TextStyle(
                    fontSize: 13,
                    color: dark ? Colors.white : const Color(0xFF1A1D23),
                  ),
                  decoration: InputDecoration(
                    hintText: isEs
                        ? 'Agregar problema activo…'
                        : 'Adicionar problema ativo…',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: dark ? Colors.white24 : Colors.black26,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _addProblema(_problemaCtrl.text),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: InternacionTheme.cyan,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── Notas de avaliação ───────────────────────────────────────────────
        Text(
          (isEs ? 'IMPRESIÓN CLÍNICA' : 'IMPRESSÃO CLÍNICA').toUpperCase(),
          style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8,
            color: theme.labelColor,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF1A1D23) : const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: dark ? const Color(0xFF2D3340) : const Color(0xFFDDE1E6),
              width: 0.8,
            ),
          ),
          child: TextField(
            controller: _notasCtrl,
            maxLines: 3,
            minLines: 2,
            onChanged: (v) => widget.onChanged(d.copyWith(notasEvaluacion: v)),
            style: TextStyle(
              fontSize: 13,
              color: dark ? Colors.white : const Color(0xFF1A1D23),
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: isEs
                  ? 'Paciente evoluciona favorablemente…'
                  : 'Paciente evolui favoravelmente…',
              hintStyle: TextStyle(
                fontSize: 13,
                color: dark ? Colors.white24 : Colors.black26,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  IconData _iconForEstado(EstadoClinical e) {
    switch (e) {
      case EstadoClinical.mejorando:  return Icons.trending_up_rounded;
      case EstadoClinical.estable:    return Icons.trending_flat_rounded;
      case EstadoClinical.empeorando: return Icons.trending_down_rounded;
    }
  }
}
