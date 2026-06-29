// clinical_recorder_sheet.dart
//
// Gravador Clínico Inteligente Multimodal — MedCases Pro Build 331+
//
// Fluxo completo em 4 fases:
//   Fase 0 — FlowSelectionModal: 3 opções de entrada
//   Fase 1 — ClinicalRecorderPage: UI de gravação com texto crescendo em tempo real
//   Fase 2 — SoapReviewPage: revisão dos campos SOAP antes de injetar
//   Fase 3 — OcrScannerPage: OCR de exame (acessível de fora ou dentro do fluxo)
//
// Entry points:
//   ClinicalRecorderSheet.showFlowSelection(context, onManual, onSoapData)
//   ClinicalRecorderSheet.showOcrScanner(context, onResult)
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/clinical_recorder_service.dart';
import '../services/soap_ai_processor.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// ENTRY POINTS ESTÁTICOS
// ═══════════════════════════════════════════════════════════════════════════════
class ClinicalRecorderSheet {

  /// Exibe modal de seleção de fluxo.
  /// [onManual] → usuário escolheu digitar manualmente
  /// [onSoapData] → retorna SoapData após gravar + processar IA
  static Future<void> showFlowSelection(
    BuildContext context, {
    required VoidCallback onManual,
    required void Function(SoapData) onSoapData,
  }) async {
    final lang = context.read<AppProvider>().lang;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FlowSelectionModal(
        lang: lang,
        onManual: onManual,
        onSoapData: onSoapData,
      ),
    );
  }

  /// Exibe scanner OCR direto.
  /// [onResult] → texto estruturado extraído do exame
  static Future<void> showOcrScanner(
    BuildContext context, {
    required void Function(String) onResult,
  }) async {
    final lang = context.read<AppProvider>().lang;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OcrScannerModal(lang: lang, onResult: onResult),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FASE 0 — Modal de Seleção de Fluxo
// ═══════════════════════════════════════════════════════════════════════════════
class _FlowSelectionModal extends StatelessWidget {
  final String lang;
  final VoidCallback onManual;
  final void Function(SoapData) onSoapData;

  const _FlowSelectionModal({
    required this.lang,
    required this.onManual,
    required this.onSoapData,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF1A1F2E) : Colors.white;
    final textColor = dark ? Colors.white : const Color(0xFF111111);
    final subColor = dark ? Colors.grey[400]! : Colors.grey[600]!;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 8,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: dark ? Colors.grey[700] : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            lang == 'es' ? 'Nueva Historia Clínica' : 'Nova História Clínica',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textColor),
          ),
          const SizedBox(height: 6),
          Text(
            lang == 'es'
                ? 'Seleccione cómo desea capturar la información del paciente:'
                : 'Selecione como deseja capturar as informações do paciente:',
            style: TextStyle(fontSize: 13, color: subColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Opção 1 — Gravar consulta completa
          _FlowOption(
            emoji: '🎙️',
            title: lang == 'es' ? 'Grabar consulta y transcribir todo' : 'Gravar consulta e transcrever tudo',
            subtitle: lang == 'es'
                ? 'Flujo continuo médico-paciente — IA estructura el SOAP automáticamente'
                : 'Fluxo contínuo médico-paciente — IA estrutura o SOAP automaticamente',
            gradientColors: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            dark: dark,
            onTap: () {
              Navigator.pop(context);
              _openRecorder(context, RecorderMode.continuous);
            },
          ),
          const SizedBox(height: 12),

          // Opção 2 — Digitar manualmente
          _FlowOption(
            emoji: '📝',
            title: lang == 'es' ? 'Digitar manualmente' : 'Digitar manualmente',
            subtitle: lang == 'es'
                ? 'Formulario tradicional con campos SOAP'
                : 'Formulário tradicional com campos SOAP',
            gradientColors: const [Color(0xFF0F766E), Color(0xFF14B8A6)],
            dark: dark,
            onTap: () {
              Navigator.pop(context);
              onManual();
            },
          ),
          const SizedBox(height: 12),

          // Opção 3 — Blocos SOAP focados
          _FlowOption(
            emoji: '🧱',
            title: lang == 'es' ? 'Grabar por bloques SOAP' : 'Gravar por blocos SOAP',
            subtitle: lang == 'es'
                ? 'Dictado segmentado por categoría clínica'
                : 'Ditado segmentado por categoria clínica',
            gradientColors: const [Color(0xFFEA580C), Color(0xFFF59E0B)],
            dark: dark,
            onTap: () {
              Navigator.pop(context);
              _openRecorder(context, RecorderMode.soapBlocks);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _openRecorder(BuildContext context, RecorderMode mode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _RecorderPage(
          mode: mode,
          lang: lang,
          onSoapData: onSoapData,
        ),
      ),
    );
  }
}

// Botão de opção de fluxo
class _FlowOption extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final bool dark;
  final VoidCallback onTap;

  const _FlowOption({
    required this.emoji, required this.title, required this.subtitle,
    required this.gradientColors, required this.dark, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors.map((c) => c.withOpacity(0.15)).toList(),
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: gradientColors[0].withOpacity(0.4),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: dark ? Colors.white : const Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: dark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: gradientColors[0],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FASE 1 — Página de Gravação
// ═══════════════════════════════════════════════════════════════════════════════
class _RecorderPage extends StatefulWidget {
  final RecorderMode mode;
  final String lang;
  final void Function(SoapData) onSoapData;

  const _RecorderPage({
    required this.mode,
    required this.lang,
    required this.onSoapData,
  });

  @override
  State<_RecorderPage> createState() => _RecorderPageState();
}

class _RecorderPageState extends State<_RecorderPage> {
  final ClinicalRecorderService _recorder = ClinicalRecorderService();
  StreamSubscription<String>? _transcriptSub;
  StreamSubscription<bool>? _stateSub;

  String _transcript = '';
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isProcessing = false;
  int _elapsedSec = 0;
  Timer? _uiTimer;

  // Para modo soapBlocks
  SoapBlock _currentBlock = SoapBlock.subjective;
  final Map<SoapBlock, String> _blockTexts = {
    for (final b in SoapBlock.values) b: '',
  };

  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _transcriptSub = _recorder.transcriptStream.listen((text) {
      if (!mounted) return;
      setState(() {
        _transcript = text;
        if (widget.mode == RecorderMode.soapBlocks) {
          _blockTexts[_currentBlock] = text;
        }
      });
      // Auto-scroll para o fim
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    });
    _stateSub = _recorder.stateStream.listen((recording) {
      if (!mounted) return;
      setState(() => _isRecording = recording);
    });
    // Inicia imediatamente
    _startRecording();
  }

  @override
  void dispose() {
    _transcriptSub?.cancel();
    _stateSub?.cancel();
    _uiTimer?.cancel();
    _recorder.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    // RECORDER-GUARD: erros de permissão de microfone ou inicialização de
    // AVAudioSession não devem causar crash — exibem estado de erro ao usuário.
    try {
      await _recorder.start(lang: widget.lang);
      _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _elapsedSec = _recorder.elapsedSec);
      });
      setState(() {
        _isRecording = true;
        _isPaused = false;
        _transcript = '';
      });
    } catch (e, st) {
      debugPrint('[ClinicalRecorderSheet][_startRecording] exception: $e\n$st');
      if (mounted) {
        setState(() {
          _isRecording = false;
          _transcript = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.lang == 'es'
                  ? 'No se pudo acceder al micrófono. Verifique los permisos.'
                  : 'Não foi possível acessar o microfone. Verifique as permissões.',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _togglePause() {
    if (_isPaused) {
      _recorder.resume();
    } else {
      _recorder.pause();
    }
    setState(() => _isPaused = !_isPaused);
  }

  Future<void> _finishRecording() async {
    final raw = await _recorder.stop();
    _uiTimer?.cancel();
    if (!mounted) return;

    // Monta texto final (modo blocos: concatena blocos com labels)
    String finalText = raw;
    if (widget.mode == RecorderMode.soapBlocks) {
      final buf = StringBuffer();
      for (final block in SoapBlock.values) {
        final t = _blockTexts[block]!.trim();
        if (t.isNotEmpty) {
          buf.writeln('[${block.label}]');
          buf.writeln(t);
          buf.writeln();
        }
      }
      finalText = buf.toString().trim();
    }

    setState(() => _isProcessing = true);

    // Processar com IA
    final soap = await SoapAiProcessor.structure(finalText, lang: widget.lang);

    if (!mounted) return;
    setState(() => _isProcessing = false);

    // Navegar para revisão
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _SoapReviewPage(
          soap: soap,
          lang: widget.lang,
          onConfirm: (confirmed) {
            Navigator.pop(context);
            widget.onSoapData(confirmed);
          },
        ),
      ),
    );
  }

  void _nextSoapBlock() {
    final blocks = SoapBlock.values;
    final idx = blocks.indexOf(_currentBlock);
    if (idx < blocks.length - 1) {
      // Flush bloco atual
      _blockTexts[_currentBlock] = _transcript;
      setState(() {
        _currentBlock = blocks[idx + 1];
        _transcript = _blockTexts[_currentBlock]!;
      });
      // Reinicia gravação para o novo bloco
      _recorder.pause();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        _recorder.resume();
        setState(() => _isPaused = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF111622) : const Color(0xFFF8FAFC);
    final cardBg = dark ? const Color(0xFF1E2330) : Colors.white;
    final textColor = dark ? Colors.white : const Color(0xFF111111);
    final subColor = dark ? Colors.grey[400]! : Colors.grey[600]!;

    final isBlocks = widget.mode == RecorderMode.soapBlocks;
    final blocks = SoapBlock.values;
    final blockIdx = blocks.indexOf(_currentBlock);
    final isLastBlock = blockIdx == blocks.length - 1;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF111622),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          isBlocks
              ? '${_currentBlock.emoji} ${_currentBlock.label}'
              : (widget.lang == 'es' ? 'Grabación Clínica' : 'Gravação Clínica'),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
            )
          else if (_transcript.isNotEmpty && !_isProcessing)
            TextButton(
              onPressed: _finishRecording,
              child: Text(
                widget.lang == 'es' ? 'Finalizar' : 'Finalizar',
                style: const TextStyle(
                  color: Color(0xFF00E5FF), fontWeight: FontWeight.w700, fontSize: 14,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Barra de progresso / tempo ────────────────────────────────────
          Container(
            color: const Color(0xFF111622),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Indicador gravando
                    Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isProcessing
                                ? Colors.amber
                                : (_isPaused ? Colors.grey : Colors.red),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isProcessing
                              ? (widget.lang == 'es' ? 'Procesando IA...' : 'Processando IA...')
                              : (_isPaused
                                  ? (widget.lang == 'es' ? 'PAUSADO' : 'PAUSADO')
                                  : (widget.lang == 'es' ? 'GRAVANDO' : 'GRAVANDO')),
                          style: TextStyle(
                            color: _isProcessing
                                ? Colors.amber
                                : (_isPaused ? Colors.grey : Colors.red),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    // Tempo
                    Text(
                      ClinicalRecorderService.formatTime(_elapsedSec),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Barra de progresso (max 15min)
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (_elapsedSec / 900).clamp(0.0, 1.0),
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _elapsedSec > 750 ? Colors.red : const Color(0xFF00E5FF),
                    ),
                    minHeight: 3,
                  ),
                ),
                // Blocos SOAP: chips de navegação
                if (isBlocks) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 32,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: blocks.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (_, i) {
                        final b = blocks[i];
                        final isActive = b == _currentBlock;
                        final isDone = i < blockIdx;
                        return GestureDetector(
                          onTap: () {
                            if (i <= blockIdx) return; // só avança
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFF6366F1)
                                  : (isDone ? const Color(0xFF10B981).withOpacity(0.3) : Colors.white12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${i + 1}. ${b.emoji}',
                              style: TextStyle(
                                color: isActive || isDone ? Colors.white : Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Área de transcrição em tempo real ─────────────────────────────
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: dark ? const Color(0xFF2D3340) : const Color(0xFFE5E7EB),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.lang == 'es' ? 'Transcripción en tiempo real:' : 'Transcrição em tempo real:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: subColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollCtrl,
                      child: _transcript.isEmpty
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 40),
                                Icon(Icons.mic_rounded, size: 48, color: subColor),
                                const SizedBox(height: 12),
                                Text(
                                  widget.lang == 'es'
                                      ? 'Hable claramente hacia el micrófono...\nEl texto aparecerá aquí en tiempo real.'
                                      : 'Fale claramente para o microfone...\nO texto aparecerá aqui em tempo real.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: subColor, fontSize: 14),
                                ),
                              ],
                            )
                          : SelectableText(
                              _transcript,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.6,
                                color: textColor,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Controles inferiores ───────────────────────────────────────────
          Container(
            padding: EdgeInsets.only(
              left: 24, right: 24, top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF111622) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: dark ? const Color(0xFF2D3340) : const Color(0xFFE5E7EB),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Cancelar
                _ControlBtn(
                  icon: Icons.close_rounded,
                  label: widget.lang == 'es' ? 'Cancelar' : 'Cancelar',
                  color: Colors.red,
                  onTap: () => Navigator.pop(context),
                ),

                // Botão central — Pausar/Retomar
                GestureDetector(
                  onTap: _isProcessing ? null : _togglePause,
                  child: Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isPaused ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      boxShadow: [
                        BoxShadow(
                          color: (_isPaused ? const Color(0xFF10B981) : const Color(0xFFEF4444))
                              .withOpacity(0.4),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isPaused ? Icons.mic_rounded : Icons.pause_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),

                // Próximo bloco (modo SOAP) ou Finalizar
                if (isBlocks && !isLastBlock)
                  _ControlBtn(
                    icon: Icons.skip_next_rounded,
                    label: widget.lang == 'es' ? 'Próximo' : 'Próximo',
                    color: const Color(0xFF6366F1),
                    onTap: _nextSoapBlock,
                  )
                else
                  _ControlBtn(
                    icon: Icons.check_circle_rounded,
                    label: widget.lang == 'es' ? 'Procesar' : 'Processar',
                    color: const Color(0xFF6366F1),
                    onTap: _isProcessing ? null : _finishRecording,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ControlBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.15),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FASE 2 — Revisão SOAP
// ═══════════════════════════════════════════════════════════════════════════════
class _SoapReviewPage extends StatefulWidget {
  final SoapData soap;
  final String lang;
  final void Function(SoapData) onConfirm;

  const _SoapReviewPage({
    required this.soap,
    required this.lang,
    required this.onConfirm,
  });

  @override
  State<_SoapReviewPage> createState() => _SoapReviewPageState();
}

class _SoapReviewPageState extends State<_SoapReviewPage> {
  late final Map<String, TextEditingController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = {
      'subjective':  TextEditingController(text: widget.soap.subjective),
      'objective':   TextEditingController(text: widget.soap.objective),
      'assessment':  TextEditingController(text: widget.soap.assessment),
      'plan':        TextEditingController(text: widget.soap.plan),
      'medications': TextEditingController(text: widget.soap.medications),
      'exams':       TextEditingController(text: widget.soap.exams),
    };
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) c.dispose();
    super.dispose();
  }

  void _confirm() {
    final confirmed = SoapData(
      subjective:    _ctrls['subjective']!.text.trim(),
      objective:     _ctrls['objective']!.text.trim(),
      assessment:    _ctrls['assessment']!.text.trim(),
      plan:          _ctrls['plan']!.text.trim(),
      medications:   _ctrls['medications']!.text.trim(),
      exams:         _ctrls['exams']!.text.trim(),
      rawTranscript: widget.soap.rawTranscript,
    );
    widget.onConfirm(confirmed);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF111622) : const Color(0xFFF8FAFC);
    final l = widget.lang;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF111622),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          l == 'es' ? 'Revisar y Confirmar SOAP' : 'Revisar e Confirmar SOAP',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton.icon(
            onPressed: _confirm,
            icon: const Icon(Icons.check_rounded, color: Color(0xFF10B981)),
            label: Text(
              l == 'es' ? 'Confirmar' : 'Confirmar',
              style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner de info
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Text('✨', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l == 'es'
                        ? 'La IA estructuró la transcripción. Revise y edite los campos antes de confirmar.'
                        : 'A IA estruturou a transcrição. Revise e edite os campos antes de confirmar.',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF818CF8)),
                  ),
                ),
              ],
            ),
          ),
          _SoapField(label: '🗣️ ${l == 'es' ? 'Subjetivo' : 'Subjetivo'}', ctrl: _ctrls['subjective']!, dark: dark),
          _SoapField(label: '🩺 ${l == 'es' ? 'Objetivo' : 'Objetivo'}', ctrl: _ctrls['objective']!, dark: dark),
          _SoapField(label: '🧠 ${l == 'es' ? 'Evaluación' : 'Avaliação'}', ctrl: _ctrls['assessment']!, dark: dark),
          _SoapField(label: '📋 ${l == 'es' ? 'Plan' : 'Plano'}', ctrl: _ctrls['plan']!, dark: dark),
          _SoapField(label: '💊 ${l == 'es' ? 'Medicaciones' : 'Medicações'}', ctrl: _ctrls['medications']!, dark: dark),
          _SoapField(label: '🔬 ${l == 'es' ? 'Exámenes' : 'Exames'}', ctrl: _ctrls['exams']!, dark: dark),
          const SizedBox(height: 16),

          // Transcrição bruta (colapsável)
          if (widget.soap.rawTranscript.isNotEmpty)
            _RawTranscriptCard(raw: widget.soap.rawTranscript, dark: dark, lang: l),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.save_rounded),
              label: Text(
                l == 'es' ? 'Confirmar e ingresar al prontuario' : 'Confirmar e inserir no prontuário',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SoapField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool dark;

  const _SoapField({required this.label, required this.ctrl, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1E2330) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dark ? const Color(0xFF2D3340) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: dark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          TextField(
            controller: ctrl,
            maxLines: null,
            minLines: ctrl.text.isEmpty ? 2 : null,
            style: TextStyle(
              fontSize: 14,
              color: dark ? Colors.white : const Color(0xFF111111),
              height: 1.5,
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              border: InputBorder.none,
              hintText: '(vazio — nenhuma informação detectada)',
              hintStyle: TextStyle(
                color: dark ? Colors.grey[600] : Colors.grey[400],
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RawTranscriptCard extends StatefulWidget {
  final String raw;
  final bool dark;
  final String lang;
  const _RawTranscriptCard({required this.raw, required this.dark, required this.lang});

  @override
  State<_RawTranscriptCard> createState() => _RawTranscriptCardState();
}

class _RawTranscriptCardState extends State<_RawTranscriptCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.dark ? const Color(0xFF1E2330) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.dark ? const Color(0xFF2D3340) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Text('📄', style: TextStyle(fontSize: 20)),
            title: Text(
              widget.lang == 'es' ? 'Transcripción bruta' : 'Transcrição bruta',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SelectableText(
                widget.raw,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: widget.dark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FASE 3 — OCR Scanner de Exames
// ═══════════════════════════════════════════════════════════════════════════════
class _OcrScannerModal extends StatefulWidget {
  final String lang;
  final void Function(String) onResult;

  const _OcrScannerModal({required this.lang, required this.onResult});

  @override
  State<_OcrScannerModal> createState() => _OcrScannerModalState();
}

class _OcrScannerModalState extends State<_OcrScannerModal> {
  bool _isProcessing = false;
  String _result = '';
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickAndProcess(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      setState(() { _isProcessing = true; _result = ''; });

      final text = await SoapAiProcessor.ocrExam(bytes, lang: widget.lang);

      if (!mounted) return;
      setState(() { _isProcessing = false; _result = text; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _result = widget.lang == 'es'
            ? 'Error al procesar la imagen.'
            : 'Erro ao processar a imagem.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF1A1F2E) : Colors.white;
    final textColor = dark ? Colors.white : const Color(0xFF111111);
    final subColor = dark ? Colors.grey[400]! : Colors.grey[600]!;
    final l = widget.lang;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 8,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: dark ? Colors.grey[700] : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            children: [
              const Text('🔬', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Text(
                l == 'es' ? 'Escanear Examen' : 'Escanear Exame',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l == 'es'
                ? 'Capture una foto del examen o selecciónela de la galería. La IA extraerá los resultados automáticamente.'
                : 'Tire uma foto do exame ou selecione da galeria. A IA extrairá os resultados automaticamente.',
            style: TextStyle(fontSize: 12, color: subColor),
          ),
          const SizedBox(height: 20),

          if (!_isProcessing && _result.isEmpty) ...[
            // Botões de origem
            Row(
              children: [
                Expanded(
                  child: _OcrSourceBtn(
                    icon: Icons.camera_alt_rounded,
                    label: l == 'es' ? 'Cámara' : 'Câmera',
                    color: const Color(0xFF6366F1),
                    onTap: () => _pickAndProcess(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _OcrSourceBtn(
                    icon: Icons.photo_library_rounded,
                    label: l == 'es' ? 'Galería' : 'Galeria',
                    color: const Color(0xFF0F766E),
                    onTap: () => _pickAndProcess(ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ] else if (_isProcessing) ...[
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              l == 'es' ? 'Analizando examen con IA...' : 'Analisando exame com IA...',
              style: TextStyle(color: subColor),
            ),
          ] else ...[
            // Resultado OCR
            Flexible(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF1E2330) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: dark ? const Color(0xFF2D3340) : const Color(0xFFE5E7EB),
                  ),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _result,
                    style: TextStyle(
                      fontSize: 13, height: 1.6,
                      color: dark ? Colors.white : const Color(0xFF111111),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() { _result = ''; }),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(l == 'es' ? 'Nuevo escaneo' : 'Novo escaneamento'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onResult(_result);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check_rounded),
                    label: Text(l == 'es' ? 'Insertar' : 'Inserir'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _OcrSourceBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OcrSourceBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
