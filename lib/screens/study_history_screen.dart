// MEDCASES_PRODUCTIVE_SECOND_BRAND_B1_V2_R1_STUDY_HISTORY
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/study_workspace_model.dart';
import '../services/study/study_library_service.dart';
import 'study_workspace_screen.dart';

class StudyHistoryScreen extends StatefulWidget {
  const StudyHistoryScreen({super.key, required this.isEs});
  final bool isEs;

  @override
  State<StudyHistoryScreen> createState() => _StudyHistoryScreenState();
}

class _StudyHistoryScreenState extends State<StudyHistoryScreen> {
  List<Study> _studies = const <Study>[];
  bool _loading = true;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final studies = await StudyLibraryService.loadAll();
    if (!mounted) return;
    setState(() {
      _studies = studies;
      _loading = false;
    });
  }

  Future<void> _openStudy(Study study) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _SavedStudyWorkspaceRoute(
          isEs: widget.isEs,
          study: study,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _delete(Study study) async {
    if (_deleting) return;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF252930) : Colors.white;
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111318);
    final sub = dark ? const Color(0xFFC6CED9) : const Color(0xFF52606D);
    const destructive = Color(0xFFDC2626);
    final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            title: Text(
              widget.isEs ? 'Eliminar del historial' : 'Excluir do histórico',
              style: TextStyle(
                color: text,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: Text(
              widget.isEs
                  ? 'El estudio también se eliminará de la biblioteca.'
                  : 'O estudo também será excluído da biblioteca.',
              style: TextStyle(color: sub, fontSize: 11, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text('Cancelar', style: TextStyle(color: sub)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(
                  widget.isEs ? 'Eliminar' : 'Excluir',
                  style: const TextStyle(
                    color: destructive,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok || !mounted) return;
    setState(() => _deleting = true);
    try {
      await StudyLibraryService.deleteById(study.id);
      await _load();
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  String _date(DateTime value) {
    final d = value.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final page = dark ? const Color(0xFF1A1D23) : const Color(0xFFECF1F3);
    final surface = dark ? const Color(0xFF252930) : Colors.white;
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111318);
    final sub = dark ? const Color(0xFFC6CED9) : const Color(0xFF59636E);
    const accent = Color(0xFF0D6B57);
    const destructive = Color(0xFFDC2626);
    return ColoredBox(
      color: page,
      child: RefreshIndicator(
        onRefresh: _load,
        color: accent,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            16,
            10,
            16,
            112 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isEs
                            ? 'Historial de estudios'
                            : 'Histórico de estudos',
                        style: TextStyle(
                          color: text,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        widget.isEs
                            ? 'Toca un estudio para continuar y generar nuevos productos.'
                            : 'Toque em um estudo para continuar e gerar novos produtos.',
                        style: TextStyle(color: sub, fontSize: 10.2),
                      ),
                    ],
                  ),
                ),
                if (!_loading)
                  Text(
                    '${_studies.length}',
                    style: TextStyle(
                      color: sub,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (_loading)
              const LinearProgressIndicator(
                minHeight: 2,
                color: accent,
                backgroundColor: Colors.transparent,
              )
            else if (_studies.isEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: border, width: 0.7),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.history_rounded, size: 27, color: accent),
                    const SizedBox(height: 8),
                    Text(
                      widget.isEs
                          ? 'Sin estudios guardados'
                          : 'Nenhum estudo salvo',
                      style: TextStyle(
                        color: text,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.isEs
                          ? 'Los estudios guardados aparecerán aquí automáticamente.'
                          : 'Os estudos salvos aparecerão aqui automaticamente.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: sub,
                        fontSize: 10.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: border, width: 0.7),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < _studies.length; i++) ...[
                      InkWell(
                        onTap: _deleting ? null : () => _openStudy(_studies[i]),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(11, 9, 5, 9),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.auto_stories_outlined,
                                size: 17,
                                color: accent,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _studies[i].title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: text,
                                        fontSize: 11.3,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_date(_studies[i].createdAtUtc)} · ${_studies[i].sources.length} ${widget.isEs ? "fuentes" : "fontes"} · ${_studies[i].artifacts.length} ${widget.isEs ? "productos" : "produtos"}',
                                      style:
                                          TextStyle(color: sub, fontSize: 9.4),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: widget.isEs ? 'Eliminar' : 'Excluir',
                                onPressed: _deleting
                                    ? null
                                    : () => _delete(_studies[i]),
                                visualDensity: VisualDensity.compact,
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 17,
                                  color: _deleting ? sub : destructive,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (i < _studies.length - 1)
                        Divider(
                          height: 1,
                          thickness: 0.7,
                          color: border,
                          indent: 12,
                          endIndent: 12,
                        ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SavedStudyWorkspaceRoute extends StatelessWidget {
  const _SavedStudyWorkspaceRoute({
    required this.isEs,
    required this.study,
  });

  final bool isEs;
  final Study study;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final topPad = MediaQuery.viewPaddingOf(context).top;
    final page = dark ? const Color(0xFF1A1D23) : const Color(0xFFECF1F3);
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111318);
    final topbarSurface = dark
        ? const Color(0xFF252930).withValues(alpha: 0.70)
        : Colors.white.withValues(alpha: 0.70);
    final divider = dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);

    return Scaffold(
      backgroundColor: page,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: 14,
                  sigmaY: 14,
                ),
                child: Container(
                  height: topPad + 48,
                  padding: EdgeInsets.only(top: topPad),
                  decoration: BoxDecoration(
                    color: topbarSurface,
                    border: Border(
                      bottom: BorderSide(
                        color: divider,
                        width: 0.7,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 48,
                        child: IconButton(
                          tooltip: isEs ? 'Volver' : 'Voltar',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 17,
                            color: text,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          isEs ? 'Estudio guardado' : 'Estudo salvo',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: text,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: StudyWorkspaceScreen(
                isEs: isEs,
                initialStudy: study,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
