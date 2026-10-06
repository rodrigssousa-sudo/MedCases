import 'recording_start_failure.dart';
import 'dart:async';
import 'dart:convert';
import 'recording_live_activity.dart';
import 'dart:io';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/study_long_form_audio_handoff.dart';
import '../entitlement_service.dart';
import '../transcription_quota.dart';
import 'clinical_long_form_audio_contract.dart';
import 'clinical_long_form_durable_store.dart';
import 'record_long_form_audio_provider.dart';
import 'recording_input_level.dart';
import 'recording_derived_audio.dart';
import 'recording_duration_policy.dart';
import 'recording_deletion_store.dart';
import 'recording_transcription_driver.dart';
import 'transcription_attempt_client.dart';
import 'recording_completion_notice.dart';
import 'transcription_diagnostics.dart';
import '../notification_service.dart';
import '../canonical_catalog_cipher.dart' show catalogUidHash;

enum RecordingPhase {
  idle,
  preparing,
  recording,
  paused,
  stopping,
  recorded,
  transcriptionQueued,
  transcribing,
  transcribed,
  recoverableError,
  completed,
  cancelled
}

class RecordingSessionData {
  RecordingSessionData(
      {required this.sessionId,
      required this.ownerUid,
      required this.createdAt,
      required this.language,
      required this.mode})
      : updatedAt = createdAt;
  final String sessionId, ownerUid, language, mode;
  final DateTime createdAt;
  DateTime updatedAt;
  RecordingPhase phase = RecordingPhase.idle;
  int elapsedDurationMs = 0;
  int blockIndex = 0;
  final List<Map<String, dynamic>> segments = [];
  String transcriptionState = 'idle';
  String? transcriptionJobId, lastErrorCategory, transcript;
  bool recoveryAvailable = false, explicitlyCancelled = false;
  Map<String, dynamic> job = {};
  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'sessionId': sessionId,
        'ownerUid': ownerUid,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'language': language,
        'mode': mode,
        'blockIndex': blockIndex,
        'recordingState': phase.name,
        'elapsedDurationMs': elapsedDurationMs,
        'accumulatedRecordedDuration': elapsedDurationMs,
        'recordingStartedAt': job['recordingStartedAt'],
        'pauseStartedAt': job['pauseStartedAt'],
        'lastCheckpointAt': updatedAt.toIso8601String(),
        'audioPath': segments.isEmpty ? null : segments.first['path'],
        'segmentPaths': segments.map((s) => s['path']).toList(),
        'segmentCount': segments.length,
        'segments': segments,
        'transcriptionState': transcriptionState,
        'transcriptionJobId': transcriptionJobId,
        'lastErrorCategory': lastErrorCategory,
        'recoveryAvailable': recoveryAvailable,
        'explicitlyCancelled': explicitlyCancelled,
        'job': job
      };
  factory RecordingSessionData.fromJson(Map<String, dynamic> d) {
    final s = RecordingSessionData(
        sessionId: d['sessionId'],
        ownerUid: d['ownerUid'],
        createdAt: DateTime.parse(d['createdAt']),
        language: d['language'],
        mode: d['mode']);
    s.updatedAt = DateTime.parse(d['updatedAt']);
    s.phase = RecordingPhase.values.byName(d['recordingState']);
    s.elapsedDurationMs = d['elapsedDurationMs'];
    s.blockIndex = d['blockIndex'] ?? 0;
    s.segments.addAll(
        (d['segments'] as List).map((e) => Map<String, dynamic>.from(e)));
    s.transcriptionState = d['transcriptionState'];
    s.transcriptionJobId = d['transcriptionJobId'];
    s.lastErrorCategory = d['lastErrorCategory'];
    s.recoveryAvailable = d['recoveryAvailable'];
    s.explicitlyCancelled = d['explicitlyCancelled'];
    s.job = Map<String, dynamic>.from(d['job'] ?? {});
    return s;
  }
}

typedef RecordingTranscriber = Future<String> Function(
    RecordingSessionData, Future<void> Function());

/// The only capture authority. Routes may observe/command, never dispose it.
class RecordingSessionController extends ChangeNotifier
    with WidgetsBindingObserver {
  RecordingSessionController(
      {required this.currentUid,
      required this.storageRoot,
      required this.captureFactory,
      required this.authorize,
      DateTime Function()? now,
      this.automaticTicks = true,
      this.resolveDurationTier,
      this.resolveQuota,
      this.resolveEligibility,
      this.transcribeAtLimit,
      this.notifyCompletion,
      this.observeAttempts = false})
      : now = now ?? DateTime.now;
  static const captureCapability = MedCasesCapability.audioBasic;
  static RecordingSessionController? _instance;
  static RecordingSessionController get instance {
    if (_instance != null) return _instance!;
    final s = RecordingSessionController(
        currentUid: () => FirebaseAuth.instance.currentUser?.uid,
        storageRoot: getApplicationSupportDirectory,
        captureFactory: () {
          late final RecordLongFormAudioProvider provider;
          provider = RecordLongFormAudioProvider(onQuotaReached: () {
            unawaited(_instance?.rotateForQuota(provider));
          });
          return provider;
        },
        observeAttempts: true,
        resolveQuota: TranscriptionQuotaService.instance.refresh,
        resolveEligibility: () =>
            TranscriptionQuotaService.instance.requireEligibility(),
        resolveDurationTier: () async {
          final service = EntitlementService.instance;
          return service.current.tier;
        },
        transcribeAtLimit: RecordingTranscriptionDriver.execute,
        notifyCompletion: (s) async {
          if (await RecordingDeletionStore.state(s.ownerUid, s.sessionId) !=
              null) return;
          final notice = RecordingCompletionNotice(
              ownerUid: s.ownerUid,
              sessionId: s.sessionId,
              language: s.language);
          await NotificationService.showRecordingCompletion(
              id: notice.id,
              title: notice.title,
              body: notice.body,
              payload: notice.payload);
          if (await RecordingDeletionStore.state(s.ownerUid, s.sessionId) !=
              null) {
            await NotificationService.cancel(notice.id);
          }
        },
        authorize: (mode) async {
          // Native microphone permission is checked by the capture provider.
          // Plan, transcription balance and connectivity do not authorize capture.
        });
    _instance = s;
    final liveActivity = RecordingLiveActivity();
    void syncLiveActivity() {
      final data = s.session;
      final owned = data != null && data.ownerUid == s.currentUid();
      unawaited(liveActivity.update(
          id: owned ? data.sessionId : '',
          owner: s.currentUid() ?? '',
          status: owned && s._engine != null && s.capturing
              ? data.phase.name
              : 'ended',
          elapsedMs: owned ? s.elapsed.inMilliseconds : 0,
          isEs: owned && data.language.startsWith('es'),
          now: s.now()));
    }

    s.addListener(syncLiveActivity);
    syncLiveActivity();
    const MethodChannel('medcases/recording_events_v1')
        .setMethodCallHandler((call) async {
      if (call.method == 'interrupted' || call.method == 'routeChanged')
        await s.interruptCapture();
    });
    WidgetsBinding.instance.addObserver(s);
    s._auth = FirebaseAuth.instance.authStateChanges().listen((_) {
      syncLiveActivity();
      unawaited(s.open());
    });
    return s;
  }

  final String? Function() currentUid;
  final Future<Directory> Function() storageRoot;
  final ClinicalLongFormFileCapture Function() captureFactory;
  final Future<void> Function(String) authorize;
  final DateTime Function() now;
  final bool automaticTicks;
  final Future<EntitlementTier> Function()? resolveDurationTier;
  final Future<TranscriptionQuota> Function()? resolveQuota;
  final bool observeAttempts;
  final Future<void> Function()? resolveEligibility;
  String? _blockedOwner;
  int _availabilityCheck = 0;
  bool get providerBlocked =>
      currentUid() != null &&
      (_blockedOwner == currentUid() ||
          session?.lastErrorCategory ==
              TranscriptionFailure.providerBlockedCode);
  Future<void> refreshAvailability() async {
    final check = ++_availabilityCheck;
    final owner = currentUid();
    final priorSession = session;
    await refreshQuota();
    if (resolveEligibility == null) return;
    try {
      await resolveEligibility!();
      if (owner != currentUid()) throw StateError('USAGE_USER_CHANGED');
      if (check != _availabilityCheck) return;
      _blockedOwner = null;
      // A policy denial is terminal only while the server still denies access.
      // Recover the saved attempt for an explicit retry, never auto-dispatch it.
      if (priorSession != null &&
          _owns(priorSession) &&
          !capturing &&
          !processing &&
          priorSession.transcriptionState == 'terminalError' &&
          priorSession.lastErrorCategory ==
              TranscriptionFailure.providerBlockedCode) {
        priorSession.lastErrorCategory = null;
        priorSession.transcriptionState = 'pending';
        for (final segment in priorSession.segments) {
          if (segment['transcriptionState'] == 'terminalError') {
            segment['transcriptionState'] = 'pending';
          }
        }
        await _save(priorSession);
      }
    } on TranscriptionFailure catch (error) {
      if (owner != currentUid()) throw StateError('USAGE_USER_CHANGED');
      if (check != _availabilityCheck) return;
      if (error.code != TranscriptionFailure.providerBlockedCode) rethrow;
      _blockedOwner = owner;
    }
    notifyListeners();
  }

  TranscriptionQuota? quota;
  Future<TranscriptionQuota>? _latestQuotaRead;
  bool quotaRefreshing = false;

  // UI, start and resume share publication ordering. A slow response from an
  // older refresh must never replace a newer effective allowance.
  Future<TranscriptionQuota> _readEffectiveQuota() async {
    final owner = currentUid();
    if (owner == null) throw StateError('USAGE_AUTH_REQUIRED');
    _latestQuotaRead = Future<TranscriptionQuota>.sync(resolveQuota!);
    quotaRefreshing = true;
    quota = null;
    notifyListeners();
    while (true) {
      final request = _latestQuotaRead!;
      late final TranscriptionQuota result;
      try {
        result = await request;
      } catch (_) {
        if (!identical(request, _latestQuotaRead)) continue;
        quotaRefreshing = false;
        quota = null;
        notifyListeners();
        rethrow;
      }
      if (currentUid() != owner) throw StateError('USAGE_USER_CHANGED');
      if (!identical(request, _latestQuotaRead)) continue;
      if (result.owner != owner) {
        quotaRefreshing = false;
        quota = null;
        notifyListeners();
        throw StateError('USAGE_USER_CHANGED');
      }
      quota = result;
      quotaRefreshing = false;
      notifyListeners();
      return result;
    }
  }

  Future<void> refreshQuota() async {
    if (resolveQuota == null) return; // Injected capture-only test harness.
    await _readEffectiveQuota();
  }

  Future<bool> audioRetained(String id) async {
    final s = session;
    if (s == null ||
        s.sessionId != id ||
        s.ownerUid != currentUid() ||
        capturing ||
        s.segments.isEmpty) return false;
    for (final segment in s.segments) {
      final file = File(segment['path'] as String);
      if (!await file.exists() || await file.length() == 0) return false;
    }
    return currentUid() == s.ownerUid;
  }

  final RecordingTranscriber? transcribeAtLimit;
  RecordingDurationPolicy get durationPolicy =>
      const RecordingDurationPolicy.local();
  final Future<void> Function(RecordingSessionData)? notifyCompletion;
  final completion = ValueNotifier<RecordingSessionData?>(null);
  Future<RecordingSessionData?> loadCompleted(
      String ownerHash, String id) async {
    final uid = currentUid();
    if (uid != null && await RecordingDeletionStore.state(uid, id) != null)
      return null;
    if (uid == null ||
        catalogUidHash(uid) != ownerHash ||
        !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) return null;
    final dir = Directory(
        '${(await storageRoot()).path}/medcases_recordings/${base64Url.encode(utf8.encode(uid))}/$id');
    try {
      final data = RecordingSessionData.fromJson(Map<String, dynamic>.from(
          jsonDecode(await File('${dir.path}/session.json').readAsString())));
      final transcript = Map<String, dynamic>.from(
          jsonDecode(await File('${dir.path}/transcript.json').readAsString()));
      if (currentUid() != uid ||
          data.ownerUid != uid ||
          data.sessionId != id ||
          transcript['ownerUid'] != uid ||
          transcript['sessionId'] != id) return null;
      data.transcript = transcript['text'];
      return data;
    } catch (_) {
      return null;
    }
  }

  RecordingSessionData? _data;
  RecordingSessionData? get session =>
      _data?.ownerUid == currentUid() ? _data : null;
  ClinicalLongFormFileCapture? _engine;
  RecordLongFormAudioProvider? _platformHandoff;
  DateTime? _activeSince;
  DateTime? _lastPeriodicSave;
  Timer? _timer;
  Timer? _durationTimer;
  Timer? _levelTimer;
  StreamSubscription<bool>? _captureState;
  bool get recorderVisible => _visibleObservers > 0;
  bool _readingLevel = false;
  int _visibleObservers = 0;
  bool _foreground = true;
  int _levelTick = 0;
  void attachRecorderView() {
    _visibleObservers++;
  }

  void detachRecorderView() {
    _visibleObservers = max(0, _visibleObservers - 1);
    unawaited(tick(forceCheckpoint: true));
  }

  final inputLevel =
      ValueNotifier<RecordingInputLevel>(const RecordingInputLevel());
  final _levelMonitor = RecordingLevelMonitor();
  void _startLevelMonitoring() {
    _levelTimer?.cancel();
    _levelMonitor.reset();
    _levelTimer = Timer.periodic(const Duration(milliseconds: 120), (_) async {
      if ((_visibleObservers == 0 || !_foreground) && ++_levelTick % 8 != 0)
        return;
      final capture = _engine;
      if (_readingLevel ||
          phase != RecordingPhase.recording ||
          capture is! RecordLongFormAudioProvider) {
        if (phase != RecordingPhase.recording &&
            inputLevel.value.dbfs != null) {
          inputLevel.value = const RecordingInputLevel();
        }
        return;
      }
      _readingLevel = true;
      try {
        final dbfs = await capture.currentAmplitudeDbfs();
        if (identical(capture, _engine) && phase == RecordingPhase.recording) {
          inputLevel.value = _levelMonitor.add(dbfs,
              intervalMs: _visibleObservers > 0 && _foreground ? 120 : 960);
        }
      } catch (_) {
        inputLevel.value = const RecordingInputLevel();
      } finally {
        _readingLevel = false;
      }
    });
  }

  StreamSubscription<User?>? _auth;
  Future<void> _commands = Future.value();
  Future<String>? _transcription;
  Completer<String>? _cancelTranscription;
  String? _transcriptionSessionId;
  bool _tickPending = false;
  String? loadError;
  RecordingPhase get phase => session?.phase ?? RecordingPhase.idle;
  Duration get elapsed => Duration(
      milliseconds: session == null
          ? 0
          : session!.elapsedDurationMs +
              (_activeSince == null
                  ? 0
                  : max(0, now().difference(_activeSince!).inMilliseconds)));
  bool get capturing =>
      phase == RecordingPhase.recording || phase == RecordingPhase.paused;
  bool get processing =>
      phase == RecordingPhase.transcribing ||
      phase == RecordingPhase.transcriptionQueued;
  bool get canStart =>
      session == null ||
      phase == RecordingPhase.completed ||
      phase == RecordingPhase.cancelled ||
      (phase == RecordingPhase.recoverableError &&
          session!.segments.isEmpty &&
          _engine == null);
  bool get canTranscribe =>
      session != null &&
      !providerBlocked &&
      session!.transcriptionState != 'terminalError' &&
      _engine == null &&
      session!.segments.isNotEmpty &&
      !processing &&
      phase != RecordingPhase.cancelled &&
      (session!.transcript == null ||
          (session!.job['remainingUntranscribedMs'] as int? ?? 0) > 0);
  Future<void> _serial(Future<void> Function() f) {
    final r = _commands.catchError((Object _) {}).then((_) => f());
    _commands = r;
    return r;
  }

  bool _owns(RecordingSessionData s) =>
      s.ownerUid == currentUid() &&
      identical(s, _data) &&
      !RecordingDeletionStore.blockedCached(s.ownerUid, s.sessionId);
  void _requireOwner(RecordingSessionData s) {
    if (!_owns(s)) throw StateError('recording_owner_changed');
  }

  Future<Directory> _directory(RecordingSessionData s) async => Directory(
      '${(await storageRoot()).path}/medcases_recordings/${base64Url.encode(utf8.encode(s.ownerUid))}/${s.sessionId}');
  Future<void> _writes = Future.value();
  Future<void> _atomic(File file, Map<String, dynamic> value) {
    final result = _writes
        .catchError((Object _) {})
        .then((_) => _writeAtomic(file, value));
    _writes = result;
    return result;
  }

  Future<void> _writeAtomic(File file, Map<String, dynamic> value) async {
    final uid = value['ownerUid'];
    final sid = value['sessionId'];
    if (uid is String &&
        sid is String &&
        RecordingDeletionStore.blockedCached(uid, sid)) return;
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.writing');
    await tmp.writeAsString(jsonEncode(value), flush: true);
    if (await file.exists()) {
      await file.copy('${file.path}.bak');
    }
    await tmp.rename(file.path);
  }

  Future<void> _save(RecordingSessionData s) async {
    if (RecordingDeletionStore.blockedCached(s.ownerUid, s.sessionId)) return;
    s.updatedAt = now().toUtc();
    await _atomic(
        File('${(await _directory(s)).path}/session.json'), s.toJson());
  }

  static const transitions = <RecordingPhase, Set<RecordingPhase>>{
    RecordingPhase.idle: {RecordingPhase.preparing},
    RecordingPhase.preparing: {
      RecordingPhase.recording,
      RecordingPhase.recoverableError
    },
    RecordingPhase.recording: {
      RecordingPhase.paused,
      RecordingPhase.stopping,
      RecordingPhase.recoverableError
    },
    RecordingPhase.paused: {
      RecordingPhase.recording,
      RecordingPhase.stopping,
      RecordingPhase.recoverableError
    },
    RecordingPhase.stopping: {
      RecordingPhase.recorded,
      RecordingPhase.recoverableError
    },
    RecordingPhase.recorded: {
      RecordingPhase.transcriptionQueued,
      RecordingPhase.cancelled,
      RecordingPhase.completed,
      RecordingPhase.preparing,
      RecordingPhase.recoverableError
    },
    RecordingPhase.transcriptionQueued: {
      RecordingPhase.transcribing,
      RecordingPhase.recoverableError
    },
    RecordingPhase.transcribing: {
      RecordingPhase.transcribed,
      RecordingPhase.recoverableError
    },
    RecordingPhase.transcribed: {
      RecordingPhase.transcriptionQueued,
      RecordingPhase.completed,
      RecordingPhase.cancelled,
      RecordingPhase.recoverableError
    },
    RecordingPhase.recoverableError: {
      RecordingPhase.preparing,
      RecordingPhase.stopping,
      RecordingPhase.recorded,
      RecordingPhase.transcriptionQueued,
      RecordingPhase.cancelled
    },
    RecordingPhase.completed: {},
    RecordingPhase.cancelled: {}
  };
  Future<void> _transition(RecordingSessionData s, RecordingPhase next) async {
    final prior = s.phase;
    if (prior != next && !(transitions[prior]?.contains(next) ?? false))
      throw StateError('invalid_recording_transition');
    if (next == RecordingPhase.recording) {
      s.job['recordingStartedAt'] = now().toUtc().toIso8601String();
      s.job.remove('pauseStartedAt');
    } else if (next == RecordingPhase.paused) {
      s.job['pauseStartedAt'] = now().toUtc().toIso8601String();
    }
    s.phase = next;
    debugPrint('[RecordingSession] ${prior.name}->${next.name}');
    await _save(s);
    notifyListeners();
  }

  void _accumulate(RecordingSessionData s) {
    if (_activeSince == null) return;
    final delta = max(0, now().difference(_activeSince!).inMilliseconds);
    s.elapsedDurationMs += delta;
    if (s.segments.isNotEmpty)
      s.segments.last['durationMs'] =
          (s.segments.last['durationMs'] as int) + delta;
    _activeSince = null;
  }

  Future<void> _error(RecordingSessionData s, String category) async {
    s.lastErrorCategory = category;
    s.recoveryAvailable = true;
    try {
      await _transition(s, RecordingPhase.recoverableError);
    } catch (_) {
      s.phase = RecordingPhase.recoverableError;
    }
    notifyListeners();
  }

  Future<void> openSession(String sessionId) =>
      open(requestedSessionId: sessionId);
  Future<void> open({String? requestedSessionId}) => _serial(() async {
        if (requestedSessionId != null &&
            !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(requestedSessionId))
          throw const TranscriptionFailure('INVALID_SESSION', retryable: false);
        if (requestedSessionId != null &&
            session?.sessionId != requestedSessionId &&
            (_engine != null || _transcription != null))
          throw const TranscriptionFailure('ANOTHER_SESSION_ACTIVE');
        final uid = currentUid();
        if (_data != null && _data!.ownerUid != uid) {
          if (_engine != null) await _stopCapture(_data!);
          if (_engine != null)
            return; // Do not create another engine if stop failed.
          _data = null;
          _activeSince = null;
          notifyListeners();
        }
        if (uid == null ||
            (session != null &&
                (requestedSessionId == null ||
                    session!.sessionId == requestedSessionId))) return;
        loadError = null;
        await _importLegacy(uid);
        final ownerDir = Directory(
            '${(await storageRoot()).path}/medcases_recordings/${base64Url.encode(utf8.encode(uid))}');
        if (!await ownerDir.exists()) return;
        final candidates = <RecordingSessionData>[];
        await for (final entity in ownerDir.list()) {
          if (entity is! Directory) continue;
          try {
            RecordingSessionData s;
            try {
              s = RecordingSessionData.fromJson(jsonDecode(
                  await File('${entity.path}/session.json').readAsString()));
            } catch (_) {
              s = RecordingSessionData.fromJson(jsonDecode(
                  await File('${entity.path}/session.json.bak')
                      .readAsString()));
              s.recoveryAvailable = true;
            }
            if (await RecordingDeletionStore.state(uid, s.sessionId) != null)
              continue;
            if (s.ownerUid != uid ||
                s.explicitlyCancelled ||
                (requestedSessionId == null &&
                    s.phase == RecordingPhase.completed) ||
                (requestedSessionId != null &&
                    s.sessionId != requestedSessionId)) continue;
            if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(s.sessionId)) continue;
            final dir = (await _directory(s)).path;
            if (entity.path != dir ||
                s.segments.any((seg) => !RegExp(s.job['recordingLayout'] ==
                            'single-audio-v1'
                        ? '^${RegExp.escape(dir)}/(?:recording|recovery_[0-9]+)\\.(?:aac|m4a)\$'
                        : '^${RegExp.escape(dir)}/segment_[0-9]+\\.m4a\$')
                    .hasMatch(seg['path'] as String))) continue;
            final f = File('$dir/transcript.json');
            if (await f.exists()) {
              final t = jsonDecode(await f.readAsString());
              if (t['sessionId'] == s.sessionId && t['ownerUid'] == uid)
                s.transcript = t['text'];
            }
            candidates.add(s);
          } catch (_) {
            loadError = 'recovery_metadata_unreadable';
          }
        }
        if (currentUid() != uid) return;
        candidates.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        if (candidates.isEmpty) {
          if (requestedSessionId != null)
            throw const TranscriptionFailure('RECORDING_SESSION_UNAVAILABLE');
          notifyListeners();
          return;
        }
        _data = candidates.first;
        final s = _data!;
        if (s.transcript != null) {
          s.phase = RecordingPhase.transcribed;
          s.transcriptionState =
              (s.job['remainingUntranscribedMs'] as int? ?? 0) > 0
                  ? 'partial'
                  : 'completed';
        } else if ({
          RecordingPhase.preparing,
          RecordingPhase.recording,
          RecordingPhase.paused,
          RecordingPhase.stopping,
          RecordingPhase.transcribing,
          RecordingPhase.transcriptionQueued
        }.contains(s.phase)) {
          s.phase = RecordingPhase.recoverableError;
          s.lastErrorCategory = 'interrupted';
          s.recoveryAvailable = true;
        }
        await _save(s);
        notifyListeners();
      });
  Future<void> _importLegacy(String uid) async {
    // Only UID-scoped prior reconstruction data is attributable. Unscoped
    // historical files are preserved but never assigned to a guessed owner.
    final root = await storageRoot();
    final old =
        Directory('${root.path}/medcases_study_recorded_audio_state/$uid');
    if (!await old.exists()) return;
    final store = FileClinicalLongFormDurableStore(rootDirectory: old);
    await for (final dir in old.list()) {
      if (dir is! Directory) continue;
      try {
        final id = dir.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) continue;
        if (await RecordingDeletionStore.state(uid, id) != null) continue;
        final manifest = await store.loadManifest(id);
        if (manifest == null) continue;
        final s = RecordingSessionData(
            sessionId: id,
            ownerUid: uid,
            createdAt: manifest.createdAtUtc,
            language: manifest.locale,
            mode: 'study');
        final target = await _directory(s);
        if (await File('${target.path}/session.json').exists()) continue;
        await target.create(recursive: true);
        for (final segment in manifest.segments) {
          final source = File(segment.path);
          if (!source.path.startsWith('${dir.path}/audio/') ||
              source.path.contains('..') ||
              !await source.exists()) continue;
          final destination = File(
              '${target.path}/segment_${segment.index.toString().padLeft(4, '0')}.m4a');
          if (!await destination.exists()) await source.copy(destination.path);
          s.segments.add({
            'path': destination.path,
            'durationMs': segment.activeDuration.inMilliseconds,
            'completed': segment.completed
          });
        }
        if (s.segments.isEmpty) continue;
        s.elapsedDurationMs = manifest.totalActiveDuration.inMilliseconds;
        s.phase = RecordingPhase.recoverableError;
        s.recoveryAvailable = true;
        s.lastErrorCategory = 'legacy_recovered';
        await _save(s);
      } catch (_) {
        loadError = 'legacy_recovery_pending';
      }
    }
  }

  // One authority for start/resume. The server balance already includes valid
  // manual credits and subtracts consumption/reservations; do not add elapsed
  // capture here because local recording has not debited that balance.
  // Capture does not read commercial state or contact a remote authority.
  Future<RecordingDurationPolicy> _authorizedCapturePolicy(String uid) async =>
      const RecordingDurationPolicy.local();

  Future<void> start({required String language, required String mode}) =>
      _serial(() async {
        final uid = currentUid();
        debugPrint('RECORDING_START_REQUEST=true');
        if (uid == null)
          throw const RecordingStartFailure('AUTH_REQUIRED', 'owner');
        if (_engine != null || !canStart) {
          debugPrint('RECORDING_START_SKIPPED=ACTIVE_SOURCE_CONFLICT');
          return; // Repeated taps remain idempotent.
        }
        final previous = _data;
        var stage = 'authorization';
        try {
          await authorize(mode);
          stage = 'technical_limit';
          final policy = await _authorizedCapturePolicy(uid);
          if (currentUid() != uid) return;
          final s = RecordingSessionData(
              sessionId:
                  'r_${now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}',
              ownerUid: uid,
              createdAt: now().toUtc(),
              language: language,
              mode: mode);
          s.job['durationTier'] = policy.tier.name;
          s.job['recordingLayout'] = 'single-audio-v1';
          s.job['localCaptureContract'] = 'transcription-only-r1';
          s.job['durationLimitMs'] = policy.limit.inMilliseconds;
          _data = s;
          stage = 'capture_initialization';
          await _beginSegment(s, reportStartFailure: true);
        } catch (error) {
          // A failed draft remains identifiable on disk; the previous source
          // remains active and all of its files/history stay intact.
          _data = previous;
          final failure = RecordingStartFailure.from(error, stage);
          debugPrint(
              'RECORDING_START_FAILURE stage=${failure.stage} code=${failure.code}');
          notifyListeners();
          throw failure;
        }
      });
  Future<void> _beginSegment(RecordingSessionData s,
      {bool reportStartFailure = false}) async {
    _requireOwner(s);
    if (durationPolicy.reached(Duration(milliseconds: s.elapsedDurationMs))) {
      await _finishAtDurationLimit(s);
      return;
    }
    try {
      await _transition(s, RecordingPhase.preparing);
      final dir = await _directory(s);
      await dir.create(recursive: true);
      var index = s.segments.length;
      final append = s.job['recordingLayout'] == 'single-audio-v1' &&
          s.segments.length == 1 &&
          (s.segments.single['path'] as String).endsWith('.aac');
      File f;
      if (append) {
        f = File(s.segments.single['path']);
        s.segments.single['completed'] = false;
      } else {
        do {
          f = s.job['recordingLayout'] == 'single-audio-v1'
              ? File(
                  '${dir.path}/${index == 0 ? 'recording' : 'recovery_$index'}.aac')
              : File(
                  '${dir.path}/segment_${index.toString().padLeft(4, '0')}.m4a');
          index++;
        } while (await f.exists());
        s.segments.add({
          'path': f.path,
          'durationMs': 0,
          'completed': false,
          'blockIndex': s.blockIndex
        });
      }
      await _save(s);
      _requireOwner(s); // Durable intent precedes capture.
      _engine = captureFactory();
      final source = _engine;
      if (source is RecordLongFormAudioProvider) {
        source.notificationLanguage = s.language;
        source.sessionRemaining = null;
      }
      if (source is RecordLongFormAudioProvider && _platformHandoff != null) {
        source.takePlatformSessionFrom(_platformHandoff!);
        _platformHandoff = null;
      }
      await _captureState?.cancel();
      if (source is RecordLongFormAudioProvider) {
        _captureState = source.captureActiveChanges.listen((running) {
          if (!running)
            unawaited(_serial(() async {
              if (identical(_engine, source) &&
                  s.phase == RecordingPhase.recording) {
                await _stopCapture(s);
                await _error(s, 'capture_interrupted');
              }
            }));
        });
      }
      debugPrint('RECORDER_START_CALLED=true');
      await _engine!.startSegment(
          path: f.path,
          config: ClinicalLongFormRecordingConfig(
            continuous: s.job['recordingLayout'] == 'single-audio-v1',
            append: append,
            fileExtension:
                s.job['recordingLayout'] == 'single-audio-v1' ? 'aac' : 'm4a',
            unlimitedLocalCapture: true,
          ));
      debugPrint('RECORDER_START_RESULT=SUCCESS');
      _activeSince = now();
      s.lastErrorCategory = null;
      await _transition(s, RecordingPhase.recording);
      if (!_owns(s)) {
        await _stopCapture(s);
        return;
      }
      _scheduleDurationLimit(s);
      if (automaticTicks) {
        _startLevelMonitoring();
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (_tickPending) return;
          _tickPending = true;
          unawaited(tick().whenComplete(() => _tickPending = false));
        });
      }
    } catch (error) {
      if (_engine != null) {
        final failedEngine = _engine!;
        try {
          await failedEngine.stopSegment();
        } catch (_) {}
        try {
          await failedEngine.dispose();
          _engine = null;
        } catch (_) {
          /* Retain the handle if disposal failed; no second capture. */
        }
      }
      _accumulate(s);
      if (_engine == null && s.segments.isNotEmpty) {
        final last = File(s.segments.last['path']);
        if (!await last.exists() || await last.length() == 0) {
          final paths = List<String>.from(s.job['emptySegmentPaths'] ?? []);
          paths.add(last.path);
          s.job['emptySegmentPaths'] = paths;
          s.segments.removeLast(); // Keep even empty files; never delete here.
        }
      }
      await _platformHandoff?.releaseRetainedPlatformSession();
      _platformHandoff = null;
      final failure =
          RecordingStartFailure.from(error, 'capture_initialization');
      await _error(s, failure.code);
      if (reportStartFailure) throw failure;
    }
  }

  Future<void> interruptCapture() => _serial(() async {
        final s = session;
        if (s == null || _engine == null || !capturing) return;
        await _stopCapture(s);
        await _error(s, 'capture_interrupted');
      });

  Future<void> rotateForQuota(ClinicalLongFormFileCapture source) =>
      _serial(() async {
        final s = session;
        if (s == null || !identical(_engine, source) || !capturing) return;
        await _stopCapture(s,
            rollover: !durationPolicy
                .reached(Duration(milliseconds: s.elapsedDurationMs)));
        if (s.phase == RecordingPhase.recorded &&
            !durationPolicy
                .reached(Duration(milliseconds: s.elapsedDurationMs))) {
          await _beginSegment(
              s); // Existing ledger decides whether more quota exists.
        } else {
          await _platformHandoff?.releaseRetainedPlatformSession();
          _platformHandoff = null;
          if (durationPolicy
              .reached(Duration(milliseconds: s.elapsedDurationMs))) {
            await _finishAtDurationLimit(s);
          }
        }
      });

  void _scheduleDurationLimit(RecordingSessionData s) {
    _durationTimer?.cancel();
    if (!automaticTicks || durationPolicy.unlimited) return;
    _durationTimer = Timer(durationPolicy.remaining(elapsed), () {
      unawaited(_serial(() async {
        if (!_owns(s) || s.phase != RecordingPhase.recording) return;
        await _finishAtDurationLimit(s);
      }));
    });
  }

  Future<void> _finishAtDurationLimit(RecordingSessionData s) async {
    if (s.job['durationLimitReached'] == true) return;
    markTranscriptionTime(s.job, 'T0');
    await _stopCapture(s);
    if (_engine != null || s.phase == RecordingPhase.recoverableError) return;
    s.job['durationLimitReached'] = true;
    await _save(s);
    notifyListeners();
    // Finalization never initiates upload/transcription without user intent.
  }

  Future<void> tick({bool forceCheckpoint = false}) => _serial(() async {
        final s = _data;
        if (s == null || _engine == null) return;
        if (!_owns(s)) {
          await _stopCapture(s);
          return;
        }
        if (s.phase == RecordingPhase.recording &&
            _engine is RecordLongFormAudioProvider) {
          try {
            if (!await (_engine as RecordLongFormAudioProvider)
                .isCaptureRunning()) {
              await _stopCapture(s);
              await _error(s, 'capture_interrupted');
              return;
            }
          } catch (_) {
            await _stopCapture(s);
            await _error(s, 'capture_status');
            return;
          }
        }
        if (s.phase == RecordingPhase.recording) {
          _accumulate(s);
          _activeSince = now();
          if (durationPolicy
              .reached(Duration(milliseconds: s.elapsedDurationMs))) {
            await _finishAtDurationLimit(s);
            return;
          }
          final segmentMs = s.segments.last['durationMs'] as int;
          // Prefer a measured silence during the last 15 seconds. The hard
          // quota boundary remains authoritative if speech never pauses.
          if (s.job['recordingLayout'] != 'single-audio-v1' &&
              (segmentMs >= const Duration(minutes: 5).inMilliseconds ||
                  (segmentMs >= 285000 && inputLevel.value.silenceMs >= 720))) {
            await _stopCapture(s, rollover: true);
            if (s.phase == RecordingPhase.recorded) await _beginSegment(s);
            return;
          }
        }
        try {
          if (forceCheckpoint ||
              _lastPeriodicSave == null ||
              now().difference(_lastPeriodicSave!).inSeconds >= 10) {
            await _save(s);
            _lastPeriodicSave = now();
          }
        } catch (_) {
          await _stopCapture(s);
          await _error(s, 'metadata_write');
        }
        notifyListeners();
      });
  Future<void> pause() => _serial(() async {
        final s = session;
        if (s == null || phase != RecordingPhase.recording || _engine == null)
          return;
        try {
          await _engine!.pause();
          _durationTimer?.cancel();
          _accumulate(s);
          await _transition(s, RecordingPhase.paused);
        } catch (_) {
          await _stopCapture(s);
          await _error(s, 'capture_pause');
        }
      });
  Future<void> resume() => _serial(() async {
        final s = session;
        if (s == null) return;
        if (phase != RecordingPhase.paused &&
            phase != RecordingPhase.recoverableError) return;
        // Recovered metadata cannot grant premium capture. Refresh through the
        // same authoritative resolver before resuming any stored session.
        await authorize(s.mode);
        final policy = await _authorizedCapturePolicy(s.ownerUid);
        _requireOwner(s);
        s.job['durationTier'] = policy.tier.name;
        s.job['recordingLayout'] = 'single-audio-v1';
        s.job['localCaptureContract'] = 'transcription-only-r1';
        s.job['durationLimitMs'] = policy.limit.inMilliseconds;
        await _save(s);
        if (durationPolicy.reached(elapsed)) {
          await _finishAtDurationLimit(s);
          return;
        }
        if (phase == RecordingPhase.recoverableError &&
            _engine == null &&
            s.transcriptionState == 'idle') {
          await authorize(s.mode);
          _requireOwner(s);
          await _beginSegment(s);
          return;
        }
        if (phase != RecordingPhase.paused || _engine == null) return;
        try {
          final engine = _engine;
          if (engine is RecordLongFormAudioProvider &&
              !durationPolicy.unlimited) {
            engine.updateRemainingCaptureBudget(
                durationPolicy.remaining(elapsed));
          }
          await _engine!.resume();
          _activeSince = now();
          await _transition(s, RecordingPhase.recording);
          _scheduleDurationLimit(s);
        } catch (_) {
          await _stopCapture(s);
          await _error(s, 'capture_resume');
        }
      });
  Future<void> nextBlock() => _serial(() async {
        final s = session;
        if (s == null ||
            s.mode != 'soapBlocks' ||
            s.blockIndex >= 5 ||
            !capturing) return;
        await _stopCapture(s, rollover: true);
        if (s.phase != RecordingPhase.recorded) return;
        s.blockIndex++;
        await _beginSegment(s);
      });

  Future<void> stop() => _serial(() async {
        final s = session;
        if (s == null || processing) return;
        if (_engine != null) markTranscriptionTime(s.job, 'T0');
        if (_engine == null && phase == RecordingPhase.recoverableError) {
          await _transition(s, RecordingPhase.recorded);
          return;
        }
        await _stopCapture(s);
      });
  Future<void> _stopCapture(RecordingSessionData s,
      {bool rollover = false}) async {
    if (_engine == null) return;
    _timer?.cancel();
    _durationTimer?.cancel();
    _levelTimer?.cancel();
    inputLevel.value = const RecordingInputLevel();
    _accumulate(s);
    try {
      await _transition(s, RecordingPhase.stopping);
    } catch (_) {}
    try {
      await _engine!.stopSegment();
      markTranscriptionTime(s.job, 'T1');
      if (s.segments.isNotEmpty) s.segments.last['completed'] = true;
      final engine = _engine!;
      if (rollover && engine is RecordLongFormAudioProvider) {
        await engine.dispose(preservePlatformSession: true);
        _platformHandoff = engine;
      } else {
        await engine.dispose();
      }
      _engine = null;
      await _transition(s, RecordingPhase.recorded);
    } catch (_) {
      await _platformHandoff?.releaseRetainedPlatformSession();
      _platformHandoff = null;
      await _error(s, 'capture_stop');
    }
  }

  Future<void> cancel({required bool confirmed}) => _serial(() async {
        final s = session;
        if (!confirmed || s == null || processing || _transcription != null)
          return;
        await _stopCapture(s);
        if (_engine != null) return;
        s.explicitlyCancelled = true;
        s.transcriptionState = 'cancelled';
        s.lastErrorCategory = null;
        await _transition(s, RecordingPhase.cancelled);
        // Retain audio; no implicit deletion policy is introduced.
      });
  Future<void> complete() => _serial(() async {
        final s = session;
        if (s == null ||
            (phase != RecordingPhase.transcribed &&
                phase != RecordingPhase.recorded)) return;
        await _transition(s, RecordingPhase.completed);
      });
  StudyLongFormAudioHandoff? get handoff {
    final s = session;
    if (s == null ||
        _engine != null ||
        s.segments.isEmpty ||
        s.explicitlyCancelled) return null;
    return StudyLongFormAudioHandoff(
        sessionId: s.sessionId,
        locale: s.language,
        totalActiveDurationMs: s.elapsedDurationMs,
        segments: [
          for (var i = 0; i < s.segments.length; i++)
            StudyLongFormAudioSegment(
                index: i,
                path: s.segments[i]['path'],
                activeDurationMs: s.segments[i]['durationMs'])
        ]);
  }

  /// Explicit owner-confirmed erase; never accept paths supplied by a card.
  Future<void> deleteRecording(String id,
          {required bool confirmed,
          Future<void> Function(RecordingSessionData)? cleanup,
          Future<void> Function(Directory)? eraseOverride,
          Map<String, dynamic>? sourceBinding,
          void Function(String)? onDeleteStage}) =>
      _serial(() async {
        if (!confirmed) return;
        onDeleteStage?.call('OWNER_CHECK');
        final uid = currentUid();
        if (uid == null || !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) {
          throw StateError('recording_owner_changed');
        }
        if (session?.sessionId == id && _engine != null) {
          throw StateError('active_recording_delete_forbidden');
        }
        final root = await storageRoot();
        final dir = Directory(
            '${root.path}/medcases_recordings/${base64Url.encode(utf8.encode(uid))}/$id');
        final legacy = RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(uid)
            ? Directory(
                '${root.path}/medcases_study_recorded_audio_state/$uid/$id')
            : null;
        Future<void> validateDirectory(Directory target) async {
          onDeleteStage?.call('CANONICAL_PATH_CHECK');
          if (await FileSystemEntity.isLink(target.path) ||
              (await target.exists() &&
                  await target.resolveSymbolicLinks() !=
                      '${await root.resolveSymbolicLinks()}${target.path.substring(root.path.length)}')) {
            throw StateError('recording_path_unproven');
          }
        }

        await validateDirectory(dir);
        for (final name in ['session.json', 'session.json.bak']) {
          if (await FileSystemEntity.isLink('${dir.path}/$name'))
            throw StateError('recording_path_unproven');
        }
        onDeleteStage?.call('SESSION_RESOLVE_START');
        var deleteDirectory = dir;
        RecordingSessionData data;
        try {
          data = RecordingSessionData.fromJson(jsonDecode(
              await File('${dir.path}/session.json').readAsString()));
        } catch (_) {
          if (await RecordingDeletionStore.state(uid, id) == 'deleted') return;
          try {
            data = RecordingSessionData.fromJson(jsonDecode(
                await File('${dir.path}/session.json.bak').readAsString()));
          } catch (_) {
            // Prior-schema recordings already have a UID-scoped manifest.
            // Do not require migration to session.json just to delete them.
            if (legacy != null) {
              await validateDirectory(legacy);
              for (final name in ['manifest.json', 'manifest.json.bak']) {
                if (await FileSystemEntity.isLink('${legacy.path}/$name'))
                  throw StateError('recording_path_unproven');
              }
            }
            onDeleteStage?.call('SESSION_RESOLVE_START');
            final previous = legacy == null
                ? null
                : await FileClinicalLongFormDurableStore(
                        rootDirectory: legacy.parent)
                    .loadManifest(id);
            if (previous != null && previous.sessionId != id)
              throw StateError('recording_owner_changed');
            final bound = sourceBinding != null &&
                sourceBinding['sessionId'] == id &&
                sourceBinding['sourceId'] is String &&
                (await RecordingDeletionStore.sourceBinding(
                        sourceBinding['sourceId']))?['sessionId'] ==
                    id;
            if (previous == null &&
                !bound &&
                await RecordingDeletionStore.state(uid, id) != 'deleting') {
              throw StateError('recording_identity_unproven');
            }
            // Never downgrade a corrupt modern owner manifest to a path guess.
            if (await File('${dir.path}/session.json').exists() ||
                await File('${dir.path}/session.json.bak').exists()) {
              throw StateError('recording_identity_unproven');
            }
            if (previous != null) deleteDirectory = legacy!;
            data = RecordingSessionData(
                sessionId: id,
                ownerUid: uid,
                createdAt: now(),
                language: previous?.locale ?? 'pt',
                mode: 'study');
            if (previous != null)
              data.segments.addAll(previous.segments.map((s) => {
                    'path': s.path,
                    'durationMs': s.activeDuration.inMilliseconds,
                    'completed': s.completed
                  }));
            if (previous == null && bound) {
              // A UID-scoped checkpoint can prove a dead card; it cannot grant
              // authority to erase an unrecognized directory or arbitrary path.
              if (await dir.exists() ||
                  (legacy != null && await legacy.exists()))
                throw StateError('recording_path_unproven');
            }
          }
        }
        onDeleteStage?.call('SESSION_RESOLVE_OK');
        onDeleteStage?.call('OWNER_CHECK');
        if (data.ownerUid != uid ||
            data.sessionId != id ||
            currentUid() != uid) {
          throw StateError('recording_owner_changed');
        }
        await validateDirectory(deleteDirectory);
        for (final segment in data.segments) {
          final file = File(segment['path'] as String);
          if (await file.exists() &&
              !(await file.resolveSymbolicLinks()).startsWith(
                  '${await deleteDirectory.resolveSymbolicLinks()}/')) {
            throw StateError('legacy_audio_path_requires_recovery');
          }
        }
        await RecordingDeletionStore.mark(uid, id);
        if (_data?.sessionId == id && _data?.ownerUid == uid) {
          _data!.job['attemptGeneration'] =
              (_data!.job['attemptGeneration'] as int? ?? 0) + 1;
          if (_transcriptionSessionId == id &&
              _cancelTranscription?.isCompleted == false) {
            _cancelTranscription!.completeError(const TranscriptionFailure(
                'discarded_due_to_user_deletion',
                retryable: false));
          }
        }
        // DSP may still own the derived output. Fail visibly rather than claim
        // deletion while a native writer can recreate a file after the erase.
        await RecordingDerivedAudio.waitForMasters(
            data.segments.map((segment) => segment['path'] as String));
        // Drain writes already in flight before removing any local checkpoint.
        await _writes.catchError((Object _) {});
        if (currentUid() != uid) throw StateError('recording_owner_changed');
        onDeleteStage?.call('LOCAL_AUDIO_DELETE_START');
        if (eraseOverride != null) {
          await eraseOverride(deleteDirectory);
        } else {
          if (await deleteDirectory.exists())
            await deleteDirectory.delete(recursive: true);
        }
        if (await deleteDirectory.exists())
          throw StateError('local_audio_delete_failed');
        onDeleteStage?.call('LOCAL_AUDIO_DELETE_END');
        onDeleteStage?.call('CHECKPOINT_DELETE');
        await RecordingDeletionStore.removePendingBindings(uid, id);
        await RecordingDeletionStore.mark(uid, id, complete: true);
        try {
          await NotificationService.cancel(RecordingCompletionNotice(
                  ownerUid: uid, sessionId: id, language: data.language)
              .id);
        } catch (_) {}
        if (completion.value?.sessionId == id) completion.value = null;
        if (_data?.sessionId == id && _data?.ownerUid == uid) _data = null;
        // Cleanup is started after the durable local erase, without holding UI.
        final clean = cleanup ?? RecordingTranscriptionDriver.cleanupDeleted;
        unawaited(Future<void>(() async {
          try {
            await clean(data).timeout(const Duration(seconds: 5));
          } catch (_) {}
        }));
        notifyListeners();
      });

  /// Stop the local attempt immediately; already-dispatched native/server work
  /// may finish, but retry always reattaches to the same durable job.
  Future<void> cancelTranscription() async {
    final s = session;
    if (s == null || !processing) return;
    s.job['attemptGeneration'] = (s.job['attemptGeneration'] as int? ?? 0) + 1;
    s.transcriptionState = 'pending';
    s.lastErrorCategory = 'CANCELLED';
    s.phase = RecordingPhase.recoverableError;
    notifyListeners();
    if (_cancelTranscription?.isCompleted == false) {
      _cancelTranscription!
          .completeError(const TranscriptionFailure('CANCELLED'));
    }
    await _save(s);
  }

  Future<String> transcribe(RecordingTranscriber execute) {
    if (_transcription != null) {
      if (session?.sessionId != _transcriptionSessionId)
        return Future.error(StateError('transcription_owner_changed'));
      return _transcription!;
    }
    _cancelTranscription = Completer<String>();
    final future = _transcribe(execute);
    _transcription = future;
    _transcriptionSessionId = session?.sessionId;
    return future.whenComplete(() {
      _transcription = null;
      _transcriptionSessionId = null;
    });
  }

  Future<String> _transcribe(RecordingTranscriber execute) async {
    await _commands;
    final s = session;
    if (s == null) throw StateError('no_owned_session');
    if (s.transcript != null &&
        (s.job['remainingUntranscribedMs'] as int? ?? 0) == 0)
      return s.transcript!;
    if (!canTranscribe) throw StateError('audio_not_ready');
    final generation = (s.job['attemptGeneration'] as int? ?? 0) + 1;
    s.job['attemptGeneration'] = generation;
    void guard() {
      _requireOwner(s);
      if (s.job['attemptGeneration'] != generation)
        throw const TranscriptionFailure('CANCELLED');
    }

    try {
      if (observeAttempts) {
        if (s.job['attemptPendingFailure'] != null) {
          await TranscriptionAttemptClient.failed(
              s, s.lastErrorCategory ?? 'UNKNOWN');
        }
        if ((s.job['remainingUntranscribedMs'] as int? ?? 0) > 0 &&
                s.job['pendingTranscriptionPart'] == null &&
                s.job['pendingOutputCommit'] != true ||
            s.job['transcriptionAttemptId'] == null ||
            (s.transcriptionJobId == null && s.job['attemptClosed'] == true)) {
          s.job['transcriptionAttemptId'] = TranscriptionAttemptClient.newId();
          s.job['attemptRegistered'] = false;
          s.job['attemptClosed'] = false;
        }
        await _save(s);
        await TranscriptionAttemptClient.requested(s);
        await _save(s);
      }
      for (final seg in s.segments) {
        final f = File(seg['path']);
        if (!await f.exists() || await f.length() == 0)
          throw StateError('audio_missing');
      }
      _requireOwner(s);
      markTranscriptionTime(s.job, 'T2');
      s.lastErrorCategory = null;
      s.recoveryAvailable = false;
      s.transcriptionState = 'queued';
      await _transition(s, RecordingPhase.transcriptionQueued);
      s.transcriptionState = 'processing';
      await _transition(s, RecordingPhase.transcribing);
      final text = await Future.any<String>([
        execute(s, () async {
          guard();
          await _save(s);
          notifyListeners();
        }),
        _cancelTranscription!.future
      ]);
      guard();
      if (text.trim().isEmpty) throw StateError('empty_transcript');
      await _atomic(File('${(await _directory(s)).path}/transcript.json'),
          {'sessionId': s.sessionId, 'ownerUid': s.ownerUid, 'text': text});
      markTranscriptionTime(s.job, 'T13');
      s.transcript = text;
      s.job.remove('pendingOutputCommit');
      s.transcriptionState =
          (s.job['remainingUntranscribedMs'] as int? ?? 0) > 0
              ? 'partial'
              : 'completed';
      s.lastErrorCategory = null;
      await _transition(s, RecordingPhase.transcribed);
      markTranscriptionTime(s.job, 'T14');
      await _save(s);
      if (_owns(s) && s.job['completionNotificationSent'] != true) {
        // Reserve before delivery: at-most-once even if the process dies while
        // the OS accepts the notification. Denial never invalidates transcript.
        try {
          s.job['completionNotificationSent'] = true;
          await _save(s);
          completion.value = s;
          if (_owns(s)) await notifyCompletion?.call(s);
        } catch (_) {
          /* Completion and saved audio are independent of permission. */
        }
      }
      return text;
    } catch (error) {
      // Late results/errors from a cancelled attempt cannot overwrite a retry.
      if (s.job['attemptGeneration'] != generation || !_owns(s)) rethrow;
      final failure = TranscriptionFailure.classify(error);
      if (observeAttempts &&
          failure.code != 'REMOTE_PROCESSING_PENDING' &&
          s.job['transcriptionAttemptId'] != null) {
        try {
          await TranscriptionAttemptClient.failed(s, failure.code);
        } catch (_) {}
      }
      s.transcriptionState = failure.retryable ? 'pending' : 'terminalError';
      for (final segment in s.segments) {
        if (segment['transcriptionState'] != 'completed')
          segment['transcriptionState'] = s.transcriptionState;
      }
      await _error(s, failure.code);
      rethrow;
    } finally {
      // Re-read after success, pre-execution release, or failure; never replace
      // the original outcome if the balance endpoint is temporarily unavailable.
      try {
        await refreshQuota();
      } catch (_) {}
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    unawaited(tick(forceCheckpoint: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _durationTimer?.cancel();
    _levelTimer?.cancel();
    _captureState?.cancel();
    _auth?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
