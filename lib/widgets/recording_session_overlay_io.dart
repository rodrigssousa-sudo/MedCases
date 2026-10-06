import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../screens/durable_recording_screen.dart';
import '../services/audio/recording_session_controller.dart';
import '../services/notification_service.dart';

/// Above all routes; capture and completion survive recorder widget disposal.
class RecordingSessionOverlay extends StatefulWidget {
  const RecordingSessionOverlay(
      {super.key, required this.child, required this.navigatorKey});
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  @override
  State<RecordingSessionOverlay> createState() =>
      _RecordingSessionOverlayState();
}

class _RecordingSessionOverlayState extends State<RecordingSessionOverlay> {
  RecordingSessionController? controller;
  RecordingSessionData? completed;
  Timer? retry;
  bool opening = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bind());
  }

  void _bind() {
    if (!mounted) return;
    if (Firebase.apps.isEmpty) {
      retry = Timer(const Duration(seconds: 1), _bind);
      return;
    }
    controller = RecordingSessionController.instance;
    controller!.addListener(_refresh);
    controller!.completion.addListener(_complete);
    NotificationService.recordingTap.addListener(_tap);
    unawaited(NotificationService.init());
    _tap();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _complete() {
    completed = controller?.completion.value;
    _refresh();
  }

  Future<void> _tap() async {
    final payload = NotificationService.recordingTap.value;
    if (payload == null || opening) return;
    final parts = payload.split(':');
    if (parts.length != 3) {
      NotificationService.recordingTap.value = null;
      return;
    }
    // Login may still be restoring. Keep safe metadata pending until a rebuild.
    if (FirebaseAuth.instance.currentUser == null) return;
    opening = true;
    try {
      final session = await controller?.loadCompleted(parts[1], parts[2]);
      NotificationService.recordingTap.value = null;
      if (session != null && mounted) _showTranscript(session);
    } finally {
      opening = false;
    }
  }

  void _showTranscript(RecordingSessionData s) {
    if (FirebaseAuth.instance.currentUser?.uid != s.ownerUid) return;
    completed = null;
    widget.navigatorKey.currentState?.push(
        MaterialPageRoute<void>(builder: (_) => _CompletedTranscript(s: s)));
    _refresh();
  }

  @override
  void dispose() {
    retry?.cancel();
    controller?.removeListener(_refresh);
    controller?.completion.removeListener(_complete);
    NotificationService.recordingTap.removeListener(_tap);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = controller?.session;
    final result = completed?.ownerUid ==
            (Firebase.apps.isEmpty
                ? null
                : FirebaseAuth.instance.currentUser?.uid)
        ? completed
        : null;
    final show = (controller?.capturing == true &&
            controller?.recorderVisible != true) ||
        result != null;
    if (NotificationService.recordingTap.value != null && controller != null)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tap();
      });
    final es = (result ?? s)?.language.startsWith('es') == true;
    return Stack(children: [
      widget.child,
      if (show && s != null)
        Positioned(
            left: 16,
            right: 16,
            top: MediaQuery.paddingOf(context).top + 4,
            child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Material(
                        elevation: 5,
                        borderRadius: BorderRadius.circular(16),
                        color:
                            Theme.of(context).colorScheme.surfaceContainerHigh,
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                              result != null ? Icons.task_alt : Icons.mic,
                              color: Theme.of(context).colorScheme.primary),
                          title: Text(result != null
                              ? (es
                                  ? 'Transcripción concluida'
                                  : 'Transcrição concluída')
                              : (es
                                  ? 'Grabación en curso'
                                  : 'Gravação em andamento')),
                          subtitle: result != null
                              ? Text(es
                                  ? 'La grabación está lista para revisar.'
                                  : 'A gravação está pronta para revisão.')
                              : null,
                          trailing: result != null
                              ? IconButton(
                                  tooltip: es ? 'Cerrar' : 'Fechar',
                                  onPressed: () {
                                    completed = null;
                                    _refresh();
                                  },
                                  icon: const Icon(Icons.close))
                              : const Icon(Icons.chevron_right),
                          onTap: () {
                            if (result != null) {
                              _showTranscript(result);
                            } else {
                              widget.navigatorKey.currentState?.push(
                                  MaterialPageRoute<void>(
                                      builder: (_) => DurableRecordingScreen(
                                          isEs: es, mode: s.mode)));
                            }
                          },
                        ))))),
    ]);
  }
}

class _CompletedTranscript extends StatelessWidget {
  const _CompletedTranscript({required this.s});
  final RecordingSessionData s;
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, _) {
        final allowed = FirebaseAuth.instance.currentUser?.uid == s.ownerUid;
        return Scaffold(
            appBar: AppBar(
                title: Text(s.language.startsWith('es')
                    ? 'Transcripción'
                    : 'Transcrição')),
            body: SafeArea(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: allowed
                        ? SelectableText(s.transcript ?? '')
                        : const SizedBox.shrink())));
      });
}
