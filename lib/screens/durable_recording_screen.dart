import '../services/audio/recording_start_failure.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../services/transcription_quota.dart';
import 'upgrade_screen.dart';
import '../services/audio/transcription_diagnostics.dart';
import 'package:flutter/material.dart';
import '../services/audio/recording_session_controller.dart';
import '../services/audio/recording_transcription_driver.dart';
import '../services/notification_service.dart';
import 'package:flutter/services.dart';
import '../widgets/recording_intelligence_hero.dart';

class DurableRecordingScreen extends StatefulWidget {
  const DurableRecordingScreen(
      {super.key,
      required this.isEs,
      required this.mode,
      this.onRecorded,
      this.onTranscript,
      this.controller});
  final bool isEs;
  final String mode;
  final VoidCallback? onRecorded;
  final ValueChanged<String>? onTranscript;
  final RecordingSessionController? controller;
  @override
  State<DurableRecordingScreen> createState() => _DurableRecordingScreenState();
}

class _DurableRecordingScreenState extends State<DurableRecordingScreen>
    with WidgetsBindingObserver {
  late final RecordingSessionController service;
  String? uiError;
  String tr(String pt, String es) => widget.isEs ? es : pt;
  String _clock(Duration duration) {
    final seconds = (duration.inMilliseconds / 1000).ceil();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    service = widget.controller ?? RecordingSessionController.instance;
    service.attachRecorderView();
    service.addListener(_changed);
    final reattaching = service.capturing;
    unawaited(_command(() async {
      await service.open();
      // Optional balance display cannot block local capture or show a paywall.
      unawaited(service.refreshQuota().catchError((Object _) {}));
    }));
    if (reattaching)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(tr('Gravação retomada nesta tela',
                  'Grabación recuperada en esta pantalla')),
              duration: const Duration(seconds: 2)));
      });
  }

  bool _quotaPresentationPending = false;
  Future<void> _quotaPaywall({required bool explicitAttempt}) async {
    if (_quotaPresentationPending || !mounted || service.capturing) return;
    final session = service.session;
    if (session == null || session.segments.isEmpty) return;
    _quotaPresentationPending = true;
    try {
      await TranscriptionQuotaService.instance.exhausted(
          sessionId: session.sessionId,
          audioPersisted: await service.audioRetained(session.sessionId),
          explicitAttempt: explicitAttempt,
          present: () async {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(tr(
                    'Seu tempo gratuito de transcrição terminou. O áudio foi salvo. Assine o Premium para continuar transcrevendo.',
                    'Tu tiempo gratuito de transcripción terminó. El audio fue guardado. Pásate a Premium para seguir transcribiendo.'))));
            await showUpgradeScreen(context, lang: widget.isEs ? 'es' : 'pt');
          });
      await service.refreshAvailability();
    } finally {
      _quotaPresentationPending = false;
    }
  }

  bool _recoveryAnnounced = false;
  final Set<String> _warningsShown = {};
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _warning;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(service.refreshQuota().catchError((Object _) {}));
    }
  }

  void _changed() {
    if (!mounted) return;
    if (service.phase != RecordingPhase.recording) {
      _warning?.close();
      _warning = null;
    } else {
      final message =
          service.durationPolicy.warning(service.elapsed, isEs: widget.isEs);
      final key = '${service.session?.sessionId}:$message';
      if (message != null && _warningsShown.add(key)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || service.phase != RecordingPhase.recording) return;
          _warning?.close();
          _warning = ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(message), duration: const Duration(seconds: 3)));
        });
      }
    }
    if (!_recoveryAnnounced &&
        service.session?.recoveryAvailable == true &&
        service.session?.transcriptionState == 'idle') {
      _recoveryAnnounced = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(tr('Gravação recuperada', 'Grabación recuperada')),
              duration: const Duration(seconds: 3)));
      });
    }
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    service.removeListener(_changed);
    service.detachRecorderView();
    super.dispose();
  }

  Future<void> _command(Future<void> Function() action) async {
    try {
      await action();
      unawaited(HapticFeedback.selectionClick());
      if (mounted) setState(() => uiError = null);
    } catch (error) {
      if (TranscriptionFailure.classify(error).code == 'NETWORK_FAILURE') {
        if (mounted)
          setState(() => uiError = tr(
              'Áudio salvo. Aguarde a conexão e tente transcrever novamente.',
              'Audio guardado. Espera la conexión y vuelve a intentar transcribir.'));
        return;
      }
      if (error is TranscriptionFailure &&
          error.code == 'REMOTE_PROCESSING_PENDING') {
        if (mounted)
          setState(() => uiError = tr(
              'O áudio continua sendo processado em segundo plano. Você pode sair desta tela.',
              'El audio sigue procesándose en segundo plano. Puedes salir de esta pantalla.'));
        return;
      }
      if (error is TranscriptionFailure &&
          {
            'MEDIA_PROOF_FAILED',
            'UPLOAD_STALLED',
            'TRANSCRIPT_PERSIST_FAILED',
            'ACCOUNTING_FINALIZATION_FAILED',
            'WORKER_FAILURE'
          }.contains(error.code)) {
        if (mounted)
          setState(() => uiError = tr(
              'A transcrição foi interrompida. Seu áudio está salvo. Tente novamente para retomar.',
              'La transcripción se interrumpió. Tu audio está guardado. Reintenta para continuar.'));
        return;
      }
      if (error is TranscriptionFailure &&
          {
            'TRANSCRIPTION_LIMIT_REACHED',
            'RATE_LIMITED',
            'CONCURRENT_RESERVATION_LIMIT',
            'MONTHLY_USAGE_LIMIT'
          }.contains(error.code)) {
        if (mounted)
          setState(() => uiError =
              RecordingStartFailure.from(StateError(error.code), 'usage')
                  .message(isEs: widget.isEs));
        return;
      }
      if (error is StateError &&
          {
            'TRANSCRIPTION_LIMIT_REACHED',
            'RATE_LIMITED',
            'CONCURRENT_RESERVATION_LIMIT',
            'TECHNICAL_RECORDING_LIMIT',
            'MONTHLY_USAGE_LIMIT'
          }.contains(error.message)) {
        if (mounted)
          setState(() => uiError = RecordingStartFailure.from(error, 'usage')
              .message(isEs: widget.isEs));
        return;
      }
      if (error is RecordingStartFailure) {
        if (!mounted) return;
        setState(() => uiError = error.message(isEs: widget.isEs));
        if (error.microphone) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.message(isEs: widget.isEs)),
            action: SnackBarAction(
                label: tr('Ajustes', 'Ajustes'),
                onPressed: () {
                  unawaited(openAppSettings());
                }),
          ));
        }
        return;
      }
      if (error.toString().contains('MONTHLY_USAGE_LIMIT')) {
        try {
          await _quotaPaywall(explicitAttempt: true);
        } catch (_) {}
      }
      if (mounted)
        setState(() => uiError = tr(
            'Não foi possível concluir. O áudio existente foi preservado.',
            'No se pudo completar. El audio existente se conserva.'));
    }
  }

  Future<void> _cancel() async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: Text(tr('Cancelar gravação?', '¿Cancelar grabación?')),
                content: Text(tr(
                    'A sessão será encerrada. O áudio salvo será preservado.',
                    'La sesión terminará. El audio guardado se conservará.')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: Text(
                          tr('Continuar gravação', 'Continuar grabación'))),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: Text(tr(
                          'Confirmar cancelamento', 'Confirmar cancelación')))
                ]));
    if (yes == true) await _command(() => service.cancel(confirmed: true));
  }

  Future<void> _transcribe() async {
    if (mounted) setState(() => uiError = null);
    await _command(() async {
      await service.refreshAvailability();
      if (service.providerBlocked) return;
      if (service.quota?.remainingMs == 0) {
        await _quotaPaywall(explicitAttempt: true);
        if (service.quota?.remainingMs == 0)
          throw StateError('TRANSCRIPTION_LIMIT_REACHED');
      }
      await service.transcribe(RecordingTranscriptionDriver.execute);
      final s = service.session;
      if (s != null) {
        try {
          await RecordingTranscriptionDriver.settle(s);
        } catch (_) {
          /* Durable result stays available; settlement retries later. */
        }
      }
    });
  }

  Widget _preview(String text) => Card(
      child: Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('Último trecho transcrito', 'Último fragmento transcrito'),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Text(text, maxLines: 4, overflow: TextOverflow.ellipsis),
            TextButton(
                onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (context) => SafeArea(
                        child: SizedBox(
                            height: MediaQuery.sizeOf(context).height * .75,
                            child: SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                child: SelectableText(
                                    service.session?.transcript ??
                                        Map<String, dynamic>.from(service
                                                    .session
                                                    ?.job['segmentTexts'] ??
                                                {})
                                            .values
                                            .join('\n\n')))))),
                child: Text(tr('Ver transcrição', 'Ver transcripción'))),
          ])));
  Future<void> _details() => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Detalhes da sessão', 'Detalles de la sesión'),
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    Text(
                        '${tr('Segmentos salvos', 'Segmentos guardados')}: ${service.session?.segments.where((e) => e['completed'] == true).length ?? 0}'),
                    Text('AAC · 24 kHz · mono'),
                    Text(
                        '${tr('Pico medido', 'Pico medido')}: ${service.inputLevel.value.dbfs?.toStringAsFixed(1) ?? '—'} dBFS'),
                    const SizedBox(height: 12),
                    Text(tr(
                        'O original é preservado. Níveis indicam a captação, não uma avaliação clínica.',
                        'El original se conserva. Los niveles indican la captación, no una evaluación clínica.')),
                  ]))));

  @override
  Widget build(BuildContext context) {
    final s = service.session;
    final phase = service.phase;
    final active = service.capturing;
    final preparing =
        phase == RecordingPhase.preparing || phase == RecordingPhase.stopping;
    final status = switch (phase) {
      RecordingPhase.recording => tr('GRAVANDO', 'GRABANDO'),
      RecordingPhase.paused => tr('Gravação pausada', 'Grabación pausada'),
      RecordingPhase.transcribing ||
      RecordingPhase.transcriptionQueued =>
        tr('TRANSCREVENDO', 'TRANSCRIBIENDO'),
      RecordingPhase.recoverableError =>
        s?.transcriptionState == 'terminalError'
            ? tr('TRANSCRIÇÃO NÃO CONCLUÍDA', 'TRANSCRIPCIÓN NO COMPLETADA')
            : s?.transcriptionState == 'idle'
                ? tr('GRAVAÇÃO INTERROMPIDA', 'GRABACIÓN INTERRUMPIDA')
                : s?.lastErrorCategory == 'REMOTE_PROCESSING_PENDING'
                    ? tr('PROCESSANDO EM SEGUNDO PLANO',
                        'PROCESANDO EN SEGUNDO PLANO')
                    : tr('TRANSCRIÇÃO NÃO CONCLUÍDA',
                        'TRANSCRIPCIÓN NO COMPLETADA'),
      RecordingPhase.recorded => tr('ÁUDIO CAPTADO', 'AUDIO CAPTURADO'),
      RecordingPhase.transcribed ||
      RecordingPhase.completed =>
        (s?.job['remainingUntranscribedMs'] as int? ?? 0) > 0
            ? tr('TRANSCRIÇÃO PARCIAL', 'TRANSCRIPCIÓN PARCIAL')
            : tr('CONCLUÍDO', 'COMPLETADO'),
      RecordingPhase.preparing ||
      RecordingPhase.stopping =>
        tr('ORGANIZANDO A GRAVAÇÃO', 'ORGANIZANDO LA GRABACIÓN'),
      _ => tr('PRONTO PARA COMEÇAR', 'LISTO PARA EMPEZAR'),
    };
    final label = service.providerBlocked && !active
        ? TranscriptionFailure.unavailableMessage(isEs: widget.isEs)
        : service.processing
            ? (s?.job['progress']?['currentStage'] == 'uploading'
                ? tr('Enviando áudio', 'Enviando audio')
                : tr('Processando áudio', 'Procesando audio'))
            : phase == RecordingPhase.recoverableError
                ? tr('Seu áudio está seguro.', 'Tu audio está seguro.')
                : phase == RecordingPhase.paused
                    ? tr('Retome quando estiver pronto.',
                        'Continúa cuando estés listo.')
                    : '';
    final partials = Map<String, dynamic>.from(s?.job['segmentTexts'] ?? {});
    final preview = s?.transcript ??
        (partials.isEmpty ? null : partials.values.last.toString());
    return Scaffold(
        appBar: AppBar(
            title: Text(tr('Gravação Inteligente', 'Grabación Inteligente'),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            actions: [
              if (phase == RecordingPhase.recording)
                Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Center(
                        child: Text(tr('AO VIVO', 'EN VIVO'),
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color:
                                    Theme.of(context).colorScheme.primary)))),
              PopupMenuButton<String>(
                  tooltip: tr('Opções da sessão', 'Opciones de sesión'),
                  onSelected: (value) {
                    if (value == 'notifications') {
                      unawaited(NotificationService.requestPermission());
                    } else if (value == 'cancelTranscription') {
                      unawaited(_command(service.cancelTranscription));
                    } else if (value == 'cancel') {
                      _cancel();
                    } else {
                      _details();
                    }
                  },
                  itemBuilder: (_) => [
                        PopupMenuItem(
                            value: 'notifications',
                            child: Text(tr('Permitir notificações',
                                'Permitir notificaciones'))),
                        PopupMenuItem(
                            value: 'details',
                            child: Text(tr('Sessão e diagnóstico',
                                'Sesión y diagnóstico'))),
                        if (service.processing)
                          PopupMenuItem(
                              value: 'cancelTranscription',
                              child: Text(tr('Cancelar transcrição',
                                  'Cancelar transcripción'))),
                        if (s != null && !service.processing && !preparing)
                          PopupMenuItem(
                              value: 'cancel',
                              child: Text(tr(
                                  'Cancelar gravação', 'Cancelar grabación'))),
                      ])
            ],
            leading: IconButton(
                tooltip: tr('Voltar sem interromper', 'Volver sin interrumpir'),
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (active)
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(tr(
                            'A gravação continuará em segundo plano.',
                            'La grabación continuará en segundo plano.'))));
                  Navigator.maybePop(context);
                })),
        bottomNavigationBar: SafeArea(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      if (service.canStart)
                        FilledButton.icon(
                            onPressed: () => _command(() => service.start(
                                language: widget.isEs ? 'es' : 'pt',
                                mode: widget.mode)),
                            icon: const Icon(Icons.mic_rounded),
                            label: Text(
                                tr('Iniciar gravação', 'Iniciar grabación'))),
                      if (active)
                        OutlinedButton.icon(
                            onPressed: () => _command(
                                phase == RecordingPhase.paused
                                    ? service.resume
                                    : service.pause),
                            icon: Icon(phase == RecordingPhase.paused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded),
                            label: Text(phase == RecordingPhase.paused
                                ? tr('Continuar', 'Continuar')
                                : tr('Pausar', 'Pausar'))),
                      if (active)
                        FilledButton.icon(
                            onPressed: () async {
                              await HapticFeedback.mediumImpact();
                              await _command(service.stop);
                            },
                            icon: const Icon(Icons.stop_rounded),
                            label: Text(tr(
                                'Finalizar gravação', 'Finalizar grabación'))),
                    ]))),
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                        children: [
                          RecordingIntelligenceHero(
                              level: service.inputLevel,
                              duration: service.elapsed,
                              recording: phase == RecordingPhase.recording,
                              status: status,
                              subtitle: label,
                              processing: service.processing,
                              isEs: widget.isEs),
                          if (service.quotaRefreshing) ...[
                            const SizedBox(height: 12),
                            Text(
                                tr('Atualizando saldo de transcrição…',
                                    'Actualizando saldo de transcripción…'),
                                textAlign: TextAlign.center),
                          ] else if (service.quota != null) ...[
                            const SizedBox(height: 12),
                            Semantics(
                                liveRegion: true,
                                child: Text(
                                    tr('Transcrição disponível: ',
                                            'Transcripción disponible: ') +
                                        service.quota!.remainingTime,
                                    textAlign: TextAlign.center)),
                          ],
                          Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                  tr('Você pode gravar sem limite do MedCases. A transcrição utiliza o saldo do plano.',
                                      'Podés grabar sin límite de MedCases. La transcripción utiliza el saldo del plan.'),
                                  textAlign: TextAlign.center)),
                          if (s?.job['durationLimitReached'] == true)
                            Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                    service.durationPolicy
                                        .completion(isEs: widget.isEs),
                                    textAlign: TextAlign.center)),
                          if (s != null &&
                              service.quota?.remainingMs == 0 &&
                              !active)
                            Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                    service.quota!.premium
                                        ? tr(
                                            'Você utilizou todo o tempo de transcrição disponível neste período.',
                                            'Has utilizado todo el tiempo de transcripción disponible en este período.')
                                        : tr(
                                            'Áudio salvo — transcrição indisponível no plano gratuito.',
                                            'Audio guardado — transcripción no disponible en el plan gratuito.'),
                                    textAlign: TextAlign.center)),
                          if (s != null) ...[
                            const SizedBox(height: 16),
                            Text(
                                active
                                    ? tr('A gravação está protegida',
                                        'La grabación está protegida')
                                    : tr('Áudio salvo', 'Audio guardado'),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                          if (service.processing) ...[
                            const SizedBox(height: 16),
                            Text(
                                '${partials.length} ${tr('de', 'de')} ${s?.segments.length ?? 0} ${tr('trechos concluídos', 'fragmentos completados')}',
                                textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            Text(
                                tr('Você pode sair desta tela. Avisaremos quando terminar.',
                                    'Puedes salir de esta pantalla. Te avisaremos cuando termine.'),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            OutlinedButton(
                                onPressed: () => Navigator.maybePop(context),
                                child: Text(tr('Ocultar', 'Ocultar'))),
                          ],
                          if (s?.mode == 'soapBlocks') ...[
                            const SizedBox(height: 16),
                            Text(
                                (widget.isEs
                                    ? const [
                                        'Subjetivo',
                                        'Objetivo',
                                        'Evaluación',
                                        'Plan',
                                        'Medicamentos',
                                        'Exámenes'
                                      ]
                                    : const [
                                        'Subjetivo',
                                        'Objetivo',
                                        'Avaliação',
                                        'Plano',
                                        'Medicações',
                                        'Exames'
                                      ])[s!.blockIndex.clamp(0, 5)],
                                style: Theme.of(context).textTheme.titleMedium),
                            if (active && s.blockIndex < 5)
                              OutlinedButton(
                                  onPressed: () => _command(service.nextBlock),
                                  child: Text(
                                      tr('Próximo bloco', 'Siguiente bloque'))),
                          ],
                          if (phase == RecordingPhase.recoverableError &&
                              s?.transcriptionState == 'idle')
                            Wrap(spacing: 12, children: [
                              OutlinedButton(
                                  onPressed: () => _command(service.resume),
                                  child: Text(tr('Continuar gravação',
                                      'Continuar grabación'))),
                              TextButton(
                                  onPressed: () => _command(service.stop),
                                  child: Text(tr('Finalizar gravação',
                                      'Finalizar grabación'))),
                            ]),
                          if (uiError != null && !service.processing)
                            Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(uiError!)),
                          if (service.canTranscribe) ...[
                            const SizedBox(height: 20),
                            FilledButton.icon(
                                onPressed: _transcribe,
                                icon: const Icon(Icons.text_snippet_outlined),
                                label: Text(phase ==
                                        RecordingPhase.recoverableError
                                    ? (s?.lastErrorCategory ==
                                            'REMOTE_PROCESSING_PENDING'
                                        ? tr('Atualizar transcrição',
                                            'Actualizar transcripción')
                                        : tr('Tentar novamente', 'Reintentar'))
                                    : ((s?.job['remainingUntranscribedMs']
                                                    as int? ??
                                                0) >
                                            0
                                        ? tr('Transcrever o restante',
                                            'Transcribir el resto')
                                        : tr('Transcrever áudio',
                                            'Transcribir audio'))))
                          ],
                          if (preview != null && s?.transcript == null) ...[
                            const SizedBox(height: 16),
                            _preview(preview)
                          ],
                          if ((s?.job['remainingUntranscribedMs'] as int? ??
                                  0) >
                              0)
                            Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                    tr('Seu áudio completo foi salvo. Foram transcritos ${_clock(Duration(milliseconds: s?.job["transcribedUntilMs"] as int? ?? 0))}. Os ${_clock(Duration(milliseconds: s?.job["remainingUntranscribedMs"] as int? ?? 0))} restantes continuam salvos neste dispositivo. Transcreva o restante quando houver saldo disponível.',
                                        'Tu audio completo quedó guardado. Se transcribieron ${_clock(Duration(milliseconds: s?.job["transcribedUntilMs"] as int? ?? 0))}. Los ${_clock(Duration(milliseconds: s?.job["remainingUntranscribedMs"] as int? ?? 0))} restantes siguen guardados en este dispositivo. Transcribí el resto cuando tengas saldo disponible.'),
                                    textAlign: TextAlign.center)),
                          if (s?.transcript != null) ...[
                            const SizedBox(height: 20),
                            _preview(s!.transcript!),
                            if (widget.onTranscript != null)
                              FilledButton(
                                  onPressed: () =>
                                      widget.onTranscript!(s.transcript!),
                                  child: Text(tr('Revisar transcrição',
                                      'Revisar transcripción')))
                          ],
                          if (widget.onRecorded != null &&
                              s?.transcript == null &&
                              service.handoff != null &&
                              !service.processing &&
                              phase != RecordingPhase.cancelled) ...[
                            const SizedBox(height: 16),
                            OutlinedButton(
                                onPressed: widget.onRecorded,
                                child: Text(tr('Usar áudio sem transcrição',
                                    'Usar audio sin transcripción')))
                          ],
                          if (phase == RecordingPhase.transcribed ||
                              phase == RecordingPhase.recorded) ...[
                            TextButton(
                                onPressed: () => _command(service.complete),
                                child: Text(
                                    tr('Concluir sessão', 'Completar sesión')))
                          ],
                        ])))));
  }
}
