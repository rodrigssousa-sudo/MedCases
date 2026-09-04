// MEDCASES_PRODUCTIVE_SECOND_BRAND_BATCH_3A_V2_B_R1_GENERIC_CONTEXTS
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

  // MEDCASES_HC_NEW_HISTORY_WORKSPACE_V1_B_R0_RECORDER_ROUTE_API
  // Reutiliza o _RecorderPage produtivo; não duplica STT, SOAP ou revisão.
  static Future<void> openContinuousRecorder(
    BuildContext context, {
    required void Function(SoapData) onSoapData,
  }) {
    return _openRecorderMode(
      context,
      mode: RecorderMode.continuous,
      onSoapData: onSoapData,
    );
  }

  static Future<void> openSoapBlocksRecorder(
    BuildContext context, {
    required void Function(SoapData) onSoapData,
  }) {
    return _openRecorderMode(
      context,
      mode: RecorderMode.soapBlocks,
      onSoapData: onSoapData,
    );
  }

  static Future<void> _openRecorderMode(
    BuildContext context, {
    required RecorderMode mode,
    required void Function(SoapData) onSoapData,
  }) async {
    final lang = context.read<AppProvider>().lang;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _RecorderPage(
          mode: mode,
          lang: lang,
          onSoapData: onSoapData,
        ),
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
    // MEDCASES_HC_CAPTURE_PREMIUM_CHOOSER_V1_B_R0
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF1A1D23) : const Color(0xFFECF1F3);
    final textColor = dark ? const Color(0xFFF1F5F9) : const Color(0xFF05070A);
    final subColor = dark ? const Color(0xFFA8B2C1) : const Color(0xFF59636E);
    final handleColor =
        dark ? const Color(0xFF4B5563) : const Color(0xFFC7D0D8);
    final media = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: media.size.height * 0.86,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        9,
        16,
        12 + media.padding.bottom + media.viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 3,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: handleColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              lang == 'es' ? 'Nueva Historia Clínica' : 'Nova História Clínica',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.15,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              lang == 'es'
                  ? 'Seleccione cómo desea capturar la historia clínica.'
                  : 'Selecione como deseja capturar a história clínica.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: subColor,
                fontSize: 12.5,
                height: 1.3,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 14),
            _FlowOption(
              iconData: Icons.mic_rounded,
              title: lang == 'es'
                  ? 'Grabar consulta y transcribir todo'
                  : 'Gravar consulta e transcrever tudo',
              subtitle: lang == 'es'
                  ? 'Flujo continuo médico-paciente — IA estructura el SOAP automáticamente'
                  : 'Fluxo contínuo médico-paciente — IA estrutura o SOAP automaticamente',
              showIaBadge: true,
              onTap: () {
                Navigator.pop(context);
                _openRecorder(context, RecorderMode.continuous);
              },
            ),
            const SizedBox(height: 8),
            _FlowOption(
              iconData: Icons.edit_outlined,
              title: lang == 'es'
                  ? 'Completar manualmente'
                  : 'Preencher manualmente',
              subtitle: lang == 'es'
                  ? 'Formulario tradicional con campos SOAP'
                  : 'Formulário tradicional com campos SOAP',
              showIaBadge: false,
              onTap: () {
                Navigator.pop(context);
                onManual();
              },
            ),
            const SizedBox(height: 8),
            _FlowOption(
              iconData: Icons.view_agenda_outlined,
              title: lang == 'es'
                  ? 'Grabar por bloques SOAP'
                  : 'Gravar por blocos SOAP',
              subtitle: lang == 'es'
                  ? 'Dictado segmentado por categoría clínica'
                  : 'Ditado segmentado por categoria clínica',
              showIaBadge: false,
              onTap: () {
                Navigator.pop(context);
                _openRecorder(context, RecorderMode.soapBlocks);
              },
            ),
          ],
        ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Card de opção de fluxo — Design Apple/Stripe Premium (Build 332+)
// Fundo cinza-escuro uniforme 0xFF1C2232, borda fina 0xFF2C354A 0.5px,
// ícone vetorial 22px, tipografia hierárquica, badge IA discreto.
// ─────────────────────────────────────────────────────────────────────────────
class _FlowOption extends StatelessWidget {
  // LIGHT_MODE_PREMIUM_V1_A_R14_FLOW_OPTION
  final IconData iconData;
  final String title;
  final String subtitle;
  final bool showIaBadge;
  final VoidCallback onTap;

  const _FlowOption({
    required this.iconData,
    required this.title,
    required this.subtitle,
    required this.showIaBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // MEDCASES_HC_CAPTURE_PREMIUM_FLOW_OPTION_V1_B_R0
    final dark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final subtitleColor =
        dark ? const Color(0xFFA8B2C1) : const Color(0xFF64748B);
    final iconColor = showIaBadge
        ? const Color(0xFF0E8000)
        : (dark ? const Color(0xFFD1D5DB) : const Color(0xFF475569));
    final chevronColor =
        dark ? const Color(0xFF7D8794) : const Color(0xFF94A3B8);
    final dividerColor =
        dark ? const Color(0xFF374151) : const Color(0xFFE2E8F0);
    final surfaceColor = showIaBadge
        ? (dark ? const Color(0xFF202A29) : const Color(0xFFF4FAF7))
        : (dark ? const Color(0xFF252930) : Colors.white);
    final borderColor = showIaBadge
        ? const Color(0xFF0E8000).withOpacity(dark ? 0.42 : 0.30)
        : dividerColor;
    final iconSurface = showIaBadge
        ? const Color(0xFF0E8000).withOpacity(dark ? 0.12 : 0.09)
        : (dark ? const Color(0xFF2D3340) : const Color(0xFFEFF2F5));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: const Color(0xFF0E8000).withOpacity(0.08),
        highlightColor: const Color(0xFF0E8000).withOpacity(0.04),
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 10, 9, 10),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: borderColor,
              width: showIaBadge ? 0.8 : 0.7,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(
                  iconData,
                  size: 20,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                              color: titleColor,
                            ),
                          ),
                        ),
                        if (showIaBadge) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0E8000)
                                  .withOpacity(dark ? 0.11 : 0.08),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color:
                                    const Color(0xFF0E8000).withOpacity(0.42),
                                width: 0.7,
                              ),
                            ),
                            child: const Text(
                              'IA',
                              style: TextStyle(
                                color: Color(0xFF0E8000),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.35,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.3,
                        fontWeight: FontWeight.w400,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: chevronColor,
              ),
            ],
          ),
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

// HISTORY_CLINICAL_V1_D_R6_RECORDER_GRAPHITE
class _RecorderPageState extends State<_RecorderPage>
    with WidgetsBindingObserver {
  final ClinicalRecorderService _recorder = ClinicalRecorderService();
  StreamSubscription<String>? _transcriptSub;
  StreamSubscription<bool>? _stateSub;
  StreamSubscription<double>? _soundLevelSub;

  String _transcript = '';
  String _confirmedTranscript = '';
  String _partialTranscript = '';
  double _soundLevel = 0.0;
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isProcessing = false;
  int _elapsedSec = 0;
  Timer? _uiTimer;

  /// Wall-clock anchor: momento em que a gravação foi (re)iniciada.
  /// Permite recalcular [_elapsedSec] corretamente após suspensão de background.
  DateTime? _timerStartTime;

  /// Segundos acumulados antes da pausa atual (para suportar pause/resume).
  int _elapsedSecBeforePause = 0;

  // Para modo soapBlocks
  SoapBlock _currentBlock = SoapBlock.subjective;
  final Map<SoapBlock, String> _blockTexts = {
    for (final b in SoapBlock.values) b: '',
  };

  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // BUILD 335: lifecycle observer
    _transcriptSub = _recorder.transcriptStream.listen((text) {
      if (!mounted) return;
      setState(() {
        _transcript = text;
        _confirmedTranscript = _recorder.fullTranscript;
        _partialTranscript = _recorder.partialTranscript;
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
    _soundLevelSub = _recorder.soundLevelStream.listen((level) {
      if (!mounted) return;
      if ((level - _soundLevel).abs() < 0.025) return;
      setState(() => _soundLevel = level);
    });
    // Inicia imediatamente
    _startRecording();
  }

  // ── BUILD 335: LifecycleObserver ─────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _synchronizeTimer();
    }
  }

  /// Recalcula [_elapsedSec] a partir do timestamp absoluto de início.
  /// Chamado ao retornar do background — imune a suspensão do Event Loop.
  void _synchronizeTimer() {
    final start = _timerStartTime;
    if (start == null || _isPaused || !mounted) return;
    final realElapsed =
        _elapsedSecBeforePause + DateTime.now().difference(start).inSeconds;
    setState(() => _elapsedSec = realElapsed.clamp(0, 900));
  }
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // BUILD 335
    _transcriptSub?.cancel();
    _stateSub?.cancel();
    _soundLevelSub?.cancel();
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
      // BUILD 335: ancorar wall-clock ao iniciar
      _elapsedSecBeforePause = 0;
      _timerStartTime = DateTime.now();
      _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        // Wall-clock delta — imune a suspensão do OS
        final start = _timerStartTime;
        if (start != null && !_isPaused) {
          final real = _elapsedSecBeforePause +
              DateTime.now().difference(start).inSeconds;
          setState(() => _elapsedSec = real.clamp(0, 900));
        }
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
      // BUILD 335: re-ancorar wall-clock ao retomar
      _timerStartTime = DateTime.now();
      _recorder.resume();
    } else {
      // BUILD 335: acumular tempo decorrido antes de pausar
      final start = _timerStartTime;
      if (start != null) {
        _elapsedSecBeforePause = (_elapsedSecBeforePause +
                DateTime.now().difference(start).inSeconds)
            .clamp(0, 900);
      }
      _timerStartTime = null;
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
    // MEDCASES_HC_LIVE_RECORDER_FINAL_R1_V1_B_R1
    // MEDCASES_HC_CAPTURE_PREMIUM_LIVE_RECORDER_V1_B_R0
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF1A1D23) : const Color(0xFFECF1F3);
    final cardBg = dark ? const Color(0xFF252930) : Colors.white;
    final textColor = dark ? const Color(0xFFF1F5F9) : const Color(0xFF05070A);
    final subColor = dark ? const Color(0xFFA8B2C1) : const Color(0xFF59636E);

    // HISTORY_CLINICAL_INTERNAL_TABS_V1_C_R11_R2_SOAP_LIGHT_SHELL
    final soapShellBackground =
        dark ? const Color(0xFF1A1D23) : const Color(0xFFECF1F3);
    final soapShellPrimary = dark ? Colors.white : const Color(0xFF05070A);
    final soapShellDivider =
        dark ? const Color(0xFF374151) : const Color(0xFFD8E0E7);

    final isBlocks = widget.mode == RecorderMode.soapBlocks;
    final blocks = SoapBlock.values;
    final blockIdx = blocks.indexOf(_currentBlock);
    final isLastBlock = blockIdx == blocks.length - 1;
    final hasTranscript = _transcript.trim().isNotEmpty ||
        _blockTexts.values.any((text) => text.trim().isNotEmpty);
    final safeBottom = MediaQuery.of(context).padding.bottom;

    final statusColor = _isProcessing
        ? const Color(0xFFF59E0B)
        : (_isPaused
            ? const Color(0xFF8B95A3)
            : (_isRecording
                ? const Color(0xFF10B981)
                : const Color(0xFF8B95A3)));

    final statusLabel = _isProcessing
        ? (widget.lang == 'es' ? 'PROCESANDO IA' : 'PROCESSANDO IA')
        : (_isPaused
            ? 'PAUSADO'
            : (_isRecording
                ? (widget.lang == 'es' ? 'ESCUCHANDO' : 'ESCUTANDO')
                : (widget.lang == 'es' ? 'PREPARANDO' : 'PREPARANDO')));

    final liveLabel = _isProcessing
        ? 'IA'
        : (_isPaused ? 'PAUSA' : (widget.lang == 'es' ? 'EN VIVO' : 'AO VIVO'));

    final visibleSoundLevel = (!_isProcessing && !_isPaused && _isRecording)
        ? _soundLevel.clamp(0.0, 1.0).toDouble()
        : 0.0;

    double meterHeight(int index) {
      if (visibleSoundLevel <= 0.02) return 3.0;
      final amplified =
          (visibleSoundLevel * (1.1 + index * 0.28)).clamp(0.0, 1.0).toDouble();
      return 3.0 + amplified * (index.isEven ? 8.0 : 11.0);
    }

    final confirmedText =
        isBlocks ? _transcript.trim() : _confirmedTranscript.trim();
    final partialText = isBlocks ? '' : _partialTranscript.trim();
    final hasVisibleSpeech = confirmedText.isNotEmpty || partialText.isNotEmpty;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        toolbarHeight: 48,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leadingWidth: 52,
        backgroundColor: soapShellBackground,
        foregroundColor: soapShellPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Center(
          child: SizedBox(
            width: 36,
            height: 36,
            child: IconButton(
              constraints: const BoxConstraints.tightFor(
                width: 36,
                height: 36,
              ),
              padding: EdgeInsets.zero,
              tooltip: widget.lang == 'es' ? 'Cerrar' : 'Fechar',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.close_rounded,
                size: 20,
              ),
            ),
          ),
        ),
        title: Text(
          isBlocks
              ? '${_currentBlock.emoji} ${_currentBlock.label}'
              : (widget.lang == 'es'
                  ? 'Grabación Clínica'
                  : 'Gravação Clínica'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.7),
          child: Container(
            height: 0.7,
            color: soapShellDivider,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
            decoration: BoxDecoration(
              color: soapShellBackground,
              border: Border(
                bottom: BorderSide(
                  color: soapShellDivider,
                  width: 0.7,
                ),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.55,
                      ),
                    ),
                    if (!_isProcessing && !_isPaused && _isRecording) ...[
                      const SizedBox(width: 9),
                      SizedBox(
                        height: 14,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: List.generate(5, (index) {
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 90),
                              curve: Curves.easeOut,
                              width: 2.5,
                              height: meterHeight(index),
                              margin: EdgeInsets.only(
                                right: index == 4 ? 0 : 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(
                                  visibleSoundLevel > 0.04 ? 0.95 : 0.34,
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      ClinicalRecorderService.formatTime(_elapsedSec),
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (_elapsedSec / 900).clamp(0.0, 1.0),
                    backgroundColor: dark ? Colors.white12 : soapShellDivider,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _elapsedSec > 750
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: dark
                                  ? (isActive
                                      ? const Color(0xFF2D3340)
                                      : (isDone
                                          ? const Color(0xFF374151)
                                          : Colors.white10))
                                  : (isActive
                                      ? const Color(0xFFD8E0E7)
                                      : const Color(0xFFECF1F3)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${i + 1}. ${b.emoji}',
                              style: TextStyle(
                                color: dark
                                    ? (isActive || isDone
                                        ? Colors.white
                                        : Colors.white54)
                                    : (isActive
                                        ? const Color(0xFF05070A)
                                        : const Color(0xFF4B5563)),
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
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: soapShellDivider,
                  width: 0.7,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.lang == 'es'
                              ? 'Transcripción en tiempo real'
                              : 'Transcrição em tempo real',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(
                            dark ? 0.10 : 0.07,
                          ),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: statusColor.withOpacity(0.30),
                            width: 0.7,
                          ),
                        ),
                        child: Text(
                          liveLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.lang == 'es'
                        ? 'Se actualiza mientras habla. La hipótesis se consolida automáticamente.'
                        : 'Atualiza enquanto você fala. A hipótese é consolidada automaticamente.',
                    style: TextStyle(
                      color: subColor,
                      fontSize: 10.5,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollCtrl,
                      physics: const BouncingScrollPhysics(),
                      child: hasVisibleSpeech
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (confirmedText.isNotEmpty)
                                  SelectableText(
                                    confirmedText,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 14,
                                      height: 1.5,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                if (confirmedText.isNotEmpty &&
                                    partialText.isNotEmpty)
                                  const SizedBox(height: 4),
                                if (partialText.isNotEmpty)
                                  Text(
                                    partialText,
                                    style: TextStyle(
                                      color: const Color(0xFF10B981)
                                          .withOpacity(dark ? 0.88 : 0.92),
                                      fontSize: 14,
                                      height: 1.5,
                                      fontWeight: FontWeight.w500,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            )
                          : Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(
                                  11,
                                  11,
                                  11,
                                  10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981)
                                      .withOpacity(dark ? 0.055 : 0.045),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFF10B981)
                                        .withOpacity(0.18),
                                    width: 0.7,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color:
                                            const Color(0xFF10B981).withOpacity(
                                          dark ? 0.10 : 0.08,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _isPaused
                                            ? Icons.pause_rounded
                                            : Icons.mic_none_rounded,
                                        size: 18,
                                        color: statusColor,
                                      ),
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _isPaused
                                                ? (widget.lang == 'es'
                                                    ? 'Grabación pausada'
                                                    : 'Gravação pausada')
                                                : (widget.lang == 'es'
                                                    ? 'Escuchando…'
                                                    : 'Escutando…'),
                                            style: TextStyle(
                                              color: textColor,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _isPaused
                                                ? (widget.lang == 'es'
                                                    ? 'Toque el micrófono para continuar.'
                                                    : 'Toque no microfone para continuar.')
                                                : (widget.lang == 'es'
                                                    ? 'Hable normalmente con el paciente. El texto aparecerá aquí.'
                                                    : 'Fale normalmente com o paciente. O texto aparecerá aqui.'),
                                            style: TextStyle(
                                              color: subColor,
                                              fontSize: 10.5,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              safeBottom + 10,
            ),
            decoration: BoxDecoration(
              color: soapShellBackground,
              border: Border(
                top: BorderSide(
                  color: soapShellDivider,
                  width: 0.7,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ControlBtn(
                  icon: Icons.close_rounded,
                  label: widget.lang == 'es' ? 'Cancelar' : 'Cancelar',
                  color: const Color(0xFFEF4444),
                  onTap: () => Navigator.pop(context),
                ),
                Semantics(
                  button: true,
                  label: _isPaused
                      ? (widget.lang == 'es'
                          ? 'Reanudar grabación'
                          : 'Retomar gravação')
                      : (widget.lang == 'es'
                          ? 'Pausar grabación'
                          : 'Pausar gravação'),
                  child: GestureDetector(
                    onTap: _isProcessing ? null : _togglePause,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isProcessing
                            ? (dark
                                ? const Color(0xFF2D3340)
                                : const Color(0xFFD8E0E7))
                            : (_isPaused
                                ? (dark
                                    ? const Color(0xFF252930)
                                    : Colors.white)
                                : const Color(0xFF10B981)),
                        border: Border.all(
                          color: _isProcessing
                              ? soapShellDivider
                              : const Color(0xFF10B981),
                          width: _isPaused ? 1 : 0.8,
                        ),
                      ),
                      child: Icon(
                        _isPaused ? Icons.mic_rounded : Icons.pause_rounded,
                        color: _isProcessing
                            ? subColor
                            : (_isPaused
                                ? const Color(0xFF10B981)
                                : Colors.white),
                        size: 27,
                      ),
                    ),
                  ),
                ),
                if (isBlocks && !isLastBlock)
                  _ControlBtn(
                    icon: Icons.skip_next_rounded,
                    label: widget.lang == 'es' ? 'Próximo' : 'Próximo',
                    color: const Color(0xFF0D6B57),
                    onTap: _isProcessing ? null : _nextSoapBlock,
                  )
                else
                  _ControlBtn(
                    icon: Icons.check_rounded,
                    label: widget.lang == 'es' ? 'Procesar' : 'Processar',
                    color: const Color(0xFF0D6B57),
                    onTap: _isProcessing || !hasTranscript
                        ? null
                        : _finishRecording,
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
    // MEDCASES_HC_CAPTURE_PREMIUM_CONTROL_BUTTON_V1_B_R0
    final enabled = onTap != null;
    final effectiveColor = enabled ? color : color.withOpacity(0.36);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: effectiveColor.withOpacity(0.10),
                border: Border.all(
                  color: effectiveColor.withOpacity(0.46),
                  width: 0.8,
                ),
              ),
              child: Icon(
                icon,
                color: effectiveColor,
                size: 20,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: effectiveColor,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
      'subjective': TextEditingController(text: widget.soap.subjective),
      'objective': TextEditingController(text: widget.soap.objective),
      'assessment': TextEditingController(text: widget.soap.assessment),
      'plan': TextEditingController(text: widget.soap.plan),
      'medications': TextEditingController(text: widget.soap.medications),
      'exams': TextEditingController(text: widget.soap.exams),
    };
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) c.dispose();
    super.dispose();
  }

  void _confirm() {
    final confirmed = SoapData(
      subjective: _ctrls['subjective']!.text.trim(),
      objective: _ctrls['objective']!.text.trim(),
      assessment: _ctrls['assessment']!.text.trim(),
      plan: _ctrls['plan']!.text.trim(),
      medications: _ctrls['medications']!.text.trim(),
      exams: _ctrls['exams']!.text.trim(),
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
            icon: const Icon(Icons.check_rounded, color: Color(0xFF0D6B57)),
            label: Text(
              l == 'es' ? 'Confirmar' : 'Confirmar',
              style: const TextStyle(
                  color: Color(0xFF0D6B57), fontWeight: FontWeight.w700),
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
              border:
                  Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
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
                    style:
                        const TextStyle(fontSize: 13, color: Color(0xFF818CF8)),
                  ),
                ),
              ],
            ),
          ),
          _SoapField(
              label: '🗣️ ${l == 'es' ? 'Subjetivo' : 'Subjetivo'}',
              ctrl: _ctrls['subjective']!,
              dark: dark),
          _SoapField(
              label: '🩺 ${l == 'es' ? 'Objetivo' : 'Objetivo'}',
              ctrl: _ctrls['objective']!,
              dark: dark),
          _SoapField(
              label: '🧠 ${l == 'es' ? 'Evaluación' : 'Avaliação'}',
              ctrl: _ctrls['assessment']!,
              dark: dark),
          _SoapField(
              label: '📋 ${l == 'es' ? 'Plan' : 'Plano'}',
              ctrl: _ctrls['plan']!,
              dark: dark),
          _SoapField(
              label: '💊 ${l == 'es' ? 'Medicaciones' : 'Medicações'}',
              ctrl: _ctrls['medications']!,
              dark: dark),
          _SoapField(
              label: '🔬 ${l == 'es' ? 'Exámenes' : 'Exames'}',
              ctrl: _ctrls['exams']!,
              dark: dark),
          const SizedBox(height: 16),

          // Transcrição bruta (colapsável)
          if (widget.soap.rawTranscript.isNotEmpty)
            _RawTranscriptCard(
                raw: widget.soap.rawTranscript, dark: dark, lang: l),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D6B57),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.save_rounded),
              label: Text(
                l == 'es'
                    ? 'Confirmar e ingresar al prontuario'
                    : 'Confirmar e inserir no prontuário',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
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

  const _SoapField(
      {required this.label, required this.ctrl, required this.dark});

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
  const _RawTranscriptCard(
      {required this.raw, required this.dark, required this.lang});

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
          color:
              widget.dark ? const Color(0xFF2D3340) : const Color(0xFFE5E7EB),
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
      setState(() {
        _isProcessing = true;
        _result = '';
      });

      final text = await SoapAiProcessor.ocrExam(bytes, lang: widget.lang);

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _result = text;
      });
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
    final bg = dark ? const Color(0xFF1A1D23) : Colors.white;
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
            width: 40,
            height: 4,
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
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: textColor),
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
            _OcrSourceBtn(
              icon: Icons.camera_alt_outlined,
              label: l == 'es' ? 'Tomar foto' : 'Tirar foto',
              subtitle: l == 'es' ? 'Usar la cámara' : 'Usar a câmera',
              onTap: () => _pickAndProcess(ImageSource.camera),
            ),
            const Divider(
              height: 1,
              thickness: 0.6,
              indent: 36,
              color: Color(0xFF374151),
            ),
            _OcrSourceBtn(
              icon: Icons.photo_library_outlined,
              label: l == 'es' ? 'Elegir de la galería' : 'Escolher da galeria',
              subtitle: l == 'es'
                  ? 'Seleccionar una imagen existente'
                  : 'Selecionar imagem existente',
              onTap: () => _pickAndProcess(ImageSource.gallery),
            ),
          ] else if (_isProcessing) ...[
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              l == 'es'
                  ? 'Analizando examen con IA...'
                  : 'Analisando exame com IA...',
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
                  color:
                      dark ? const Color(0xFF1E2330) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: dark
                        ? const Color(0xFF2D3340)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _result,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
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
                    onPressed: () => setState(() {
                      _result = '';
                    }),
                    icon: const Icon(Icons.refresh_rounded),
                    label:
                        Text(l == 'es' ? 'Nuevo escaneo' : 'Novo escaneamento'),
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
                      backgroundColor: const Color(0xFF0D6B57),
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
  final String subtitle;
  final VoidCallback onTap;

  const _OcrSourceBtn({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 21,
                color: const Color(0xFF0D6B57),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE8F0EC),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF8D9A94),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
