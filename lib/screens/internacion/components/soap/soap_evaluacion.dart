// ─────────────────────────────────────────────────────────────────────────────
// A — EVALUACIÓN
// Seletores de estado clínico + problemas ativos.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../../models/evolucion_model.dart';
import '../internacion_theme.dart';

import '../../../../design_system/foundation/med_typography.dart';
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
  // MEDCASES_SOAP_EVALUACION_COMPACT_CONSOLE_V2
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
    // MEDCASES_SOAP4_TRUE_INNER_EVALUATION_SEGMENTED_V1
    final d = widget.data;
    final dark = widget.dark;
    final theme = InternacionTheme(dark);
    final border = dark ? const Color(0xFF3A4350) : const Color(0xFFD5DCE5);
    final muted = dark ? const Color(0xFF9AA5B4) : const Color(0xFF667085);
    final text = dark ? const Color(0xFFE8EDF3) : const Color(0xFF1F2937);

    Widget sectionTitle(String value) => Row(
      children: [
        Text(value.toUpperCase(), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.76, color: theme.labelColor)),
        const SizedBox(width: 9),
        Expanded(child: Container(height: 0.7, color: border.withOpacity(0.82))),
      ],
    );

    final states = <EstadoClinical>[
      EstadoClinical.mejorando,
      EstadoClinical.estable,
      EstadoClinical.empeorando,
    ];
    final labels = isEs
        ? <String>['Mejorando', 'Estable', 'Empeorando']
        : <String>['Melhorando', 'Estável', 'Piorando'];
    const colors = <Color>[
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionTitle(isEs ? 'Evolución clínica' : 'Evolução clínica'),
        const SizedBox(height: 8),
        Container(
          height: 36,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: border, width: 0.7),
          ),
          child: Row(
            children: List.generate(5, (index) {
              if (index.isOdd) return Container(width: 0.55, color: border.withOpacity(0.82));
              final i = index ~/ 2;
              final state = states[i];
              final active = d.estado == state;
              final color = colors[i];
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onChanged(d.copyWith(estado: state)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    alignment: Alignment.center,
                    color: active ? color.withOpacity(dark ? 0.18 : 0.10) : Colors.transparent,
                    child: Text(labels[i], maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.3, fontWeight: active ? FontWeight.w800 : FontWeight.w500, color: active ? color : muted)),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 14),
        sectionTitle(isEs ? 'Problemas activos' : 'Problemas ativos'),
        const SizedBox(height: 7),
        if (d.problemasActivos.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: d.problemasActivos.asMap().entries.map((e) {
              return Container(
                padding: const EdgeInsets.fromLTRB(8, 5, 5, 5),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: border, width: 0.65),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(e.value, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: text)),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _removeProblema(e.key),
                      child: Icon(Icons.close_rounded, size: 14, color: muted),
                    ),
                  ],
                ),
              );
            }).toList(),
          )
        else
          Text(isEs ? 'Sin problemas activos agregados' : 'Nenhum problema ativo adicionado',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w400, color: muted.withOpacity(0.75))),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: border, width: 0.7))),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _problemaCtrl,
                  onSubmitted: _addProblema,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: text),
                  decoration: InputDecoration(
                    hintText: isEs ? 'Agregar problema clínico…' : 'Adicionar problema clínico…',
                    hintStyle: TextStyle(fontSize: 12.3, color: muted.withOpacity(0.62)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 7),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _addProblema(_problemaCtrl.text),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(7),
                  child: Icon(Icons.add_rounded, size: 18, color: Color(0xFF0D6B57)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        sectionTitle(isEs ? 'Impresión clínica' : 'Impressão clínica'),
        const SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: border, width: 0.7))),
          child: TextField(
            controller: _notasCtrl,
            maxLines: 4,
            minLines: 1,
            onChanged: (v) => widget.onChanged(d.copyWith(notasEvaluacion: v)),
            style: TextStyle(fontSize: 13.3, height: 1.34, fontWeight: FontWeight.w500, color: text),
            decoration: InputDecoration(
              hintText: isEs ? 'Paciente evoluciona favorablemente…' : 'Paciente evolui favoravelmente…',
              hintStyle: TextStyle(fontSize: 12.4, height: 1.3, color: muted.withOpacity(0.62)),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 7),
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
