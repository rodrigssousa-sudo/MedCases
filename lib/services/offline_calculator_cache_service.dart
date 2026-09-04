// offline_calculator_cache_service.dart — MedCases Pro
// BUILD 242 — Smart Offline Cache · Throttled Background Downloader
//
// ═══════════════════════════════════════════════════════════════════════════
// PRINCÍPIOS DE DESIGN
// ═══════════════════════════════════════════════════════════════════════════
//
//  1. HOME ABRE PRIMEIRO
//     startBackgroundSync() é fire-and-forget. O serviço não existe para a
//     UI até que _state.isReady = true. A Home nunca espera por isso.
//
//  2. APP FICA UTILIZÁVEL
//     Entre cada arquivo baixado há um yield via Future.delayed(Duration.zero).
//     Isso devolve o event loop ao Flutter para processar toque/rebuild.
//
//  3. BAIXA EM LOTES PEQUENOS (batch = kBatchSize)
//     Após cada lote, pausa kInterBatchDelayMs antes do próximo lote.
//     O usuário sente o app fluido; o download acontece nos "gaps".
//
//  4. PAUSA SE APP FICAR LENTO (AI busy / offlineCaching)
//     Antes de cada arquivo, o serviço lê _shouldPause():
//       • AppProvider.instance.aiStreaming == true → pausa
//       • AppProvider.instance.offlineCaching == true → pausa
//     Nesses casos o download espera kPausePollingMs antes de tentar de
//     novo. Quando a IA termina, o download retoma automaticamente.
//
//  5. CONTINUA DEPOIS
//     O progresso é persistido em tmp/ (arquivo já baixado não é refeito se
//     já existir com tamanho > 0). Portanto se o app for fechado no meio do
//     download, na próxima sessão apenas os arquivos faltantes são baixados.
//
//  6. NUNCA BLOQUEIA IA / HOME
//     _shouldPause() verifica aiStreaming (bool get aiStreaming no provider).
//     Enquanto o usuário conversa com a IA, kMaxFilesWhileAIBusy=0 →
//     download completamente suspenso até a conversa terminar.
//
// ═══════════════════════════════════════════════════════════════════════════
// ARQUITETURA DE DIRETÓRIOS
// ═══════════════════════════════════════════════════════════════════════════
//
//   <ApplicationSupportDirectory>/calculator_cache/
//     manifest.json        ← { version, downloadedAt, fileCount, status }
//     current/             ← versão ativa servida pela WebView
//       index.html
//       sw.js
//       css/…  js/…  database/…
//     tmp/                 ← download em andamento
//       .progress.json     ← { downloaded: [...paths], failed: [...paths] }
//       index.html         ← arquivos já baixados (skip se existir)
//       …
//
// ═══════════════════════════════════════════════════════════════════════════
// WEB
// ═══════════════════════════════════════════════════════════════════════════
//   • path_provider não suporta Web → kIsWeb guard em todos os métodos.
//   • No Web a WebView usa iframe → modo online sempre.
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constantes de throttling
// ─────────────────────────────────────────────────────────────────────────────

/// Arquivos baixados por lote antes de ceder o event loop.
const int _kBatchSize = 3;

/// Pausa entre lotes (ms) para manter a UI responsiva.
const int _kInterBatchDelayMs = 120;

/// Polling interval (ms) quando o download está pausado por AI/caching busy.
const int _kPausePollingMs = 800;

/// Tempo máximo por arquivo (segundos).
const int _kFileTimeoutSec = 20;

/// Timeout para o manifest remoto (segundos).
const int _kManifestTimeoutSec = 10;

/// Atraso inicial após startBackgroundSync() — deixa Home renderizar primeiro.
const int _kInitialDelayMs = 2500;

// ─────────────────────────────────────────────────────────────────────────────
// Constantes de segurança e validação
// ─────────────────────────────────────────────────────────────────────────────

const String _kManifestUrl = 'https://medcasescalcu.com/manifest-offline.json';
const String _kBaseUrl     = 'https://medcasescalcu.com/';

/// Arquivos essenciais — se qualquer um estiver ausente, o swap é abortado.
const List<String> _kEssentialFiles = [
  'index.html',
  'js/medcases-ux-v2.js',
  'js/hub-accordion.js',
  'js/elec-calc.js',
  'database/cardio.js',
  'database/interacoes.js',
];

/// Domínios permitidos para download (allowlist de segurança).
const List<String> _kAllowedHosts = [
  'medcasescalcu.com',
  'www.medcasescalcu.com',
];

// ─────────────────────────────────────────────────────────────────────────────
// Modelos públicos
// ─────────────────────────────────────────────────────────────────────────────

enum CalcuCacheStatus {
  unknown,         // estado inicial — ainda não verificado
  downloading,     // download em andamento (pausado incluso)
  downloadPaused,  // pausado temporariamente por AI/caching busy
  ready,           // cache válido e disponível offline
  updateAvailable, // nova versão disponível; cache atual ainda válido
  error,           // falha no último ciclo de download
}

class CalcuCacheState {
  final CalcuCacheStatus status;
  final String? localVersion;
  final String? remoteVersion;
  final DateTime? downloadedAt;
  final int fileCount;
  final int filesDownloaded;   // quantidade já baixada (para progresso real)
  final int filesTotal;        // total esperado (para progresso real)
  final double progress;       // 0.0 → 1.0
  final String? errorMessage;

  const CalcuCacheState({
    this.status = CalcuCacheStatus.unknown,
    this.localVersion,
    this.remoteVersion,
    this.downloadedAt,
    this.fileCount = 0,
    this.filesDownloaded = 0,
    this.filesTotal = 0,
    this.progress = 0.0,
    this.errorMessage,
  });

  CalcuCacheState copyWith({
    CalcuCacheStatus? status,
    String? localVersion,
    String? remoteVersion,
    DateTime? downloadedAt,
    int? fileCount,
    int? filesDownloaded,
    int? filesTotal,
    double? progress,
    String? errorMessage,
  }) =>
      CalcuCacheState(
        status:          status          ?? this.status,
        localVersion:    localVersion    ?? this.localVersion,
        remoteVersion:   remoteVersion   ?? this.remoteVersion,
        downloadedAt:    downloadedAt    ?? this.downloadedAt,
        fileCount:       fileCount       ?? this.fileCount,
        filesDownloaded: filesDownloaded ?? this.filesDownloaded,
        filesTotal:      filesTotal      ?? this.filesTotal,
        progress:        progress        ?? this.progress,
        errorMessage:    errorMessage    ?? this.errorMessage,
      );

  bool get isReady =>
      status == CalcuCacheStatus.ready ||
      status == CalcuCacheStatus.updateAvailable;

  bool get isActive =>
      status == CalcuCacheStatus.downloading ||
      status == CalcuCacheStatus.downloadPaused;
}

// ─────────────────────────────────────────────────────────────────────────────
// Callback de "AI está ocupado" — injetado do AppProvider para desacoplar
// ─────────────────────────────────────────────────────────────────────────────

typedef _AiBusyCheck = bool Function();

// ─────────────────────────────────────────────────────────────────────────────
// OfflineCalculatorCacheService
// ─────────────────────────────────────────────────────────────────────────────

class OfflineCalculatorCacheService {
  OfflineCalculatorCacheService._();

  static final OfflineCalculatorCacheService instance =
      OfflineCalculatorCacheService._();

  // ── Estado observável ──────────────────────────────────────────────────────
  CalcuCacheState _state = const CalcuCacheState();
  CalcuCacheState get state => _state;

  final _controller = StreamController<CalcuCacheState>.broadcast();
  Stream<CalcuCacheState> get stateStream => _controller.stream;

  // ── Controle de execução ───────────────────────────────────────────────────
  bool _syncInProgress = false;
  bool _cancelRequested = false; // sinaliza para o loop parar

  // CALCULATOR_PERF_V1 — offline-ready + 3 checks/day.
  static const bool offlineReadyByDefault = true;
  static const String _kLastSuccessfulSlotKey =
      'calculator_cache_last_successful_slot_v1';

  Timer? _syncSlotTimer;
  bool _schedulerStarted = false;
  bool _lastManifestCheckSucceeded = false;


  // ── Callback de "AI ocupada" — injetado externamente ──────────────────────
  // Evita importação circular com app_provider.dart.
  // Registrado em main.dart após login:
  //   OfflineCalculatorCacheService.instance.setAiBusyCheck(
  //     () => context.read<AppProvider>().aiStreaming ||
  //           context.read<AppProvider>().offlineCaching,
  //   );
  _AiBusyCheck? _aiBusyCheck;

  /// Injeta o callback de "AI ocupada". Chamar UMA vez após login.
  void setAiBusyCheck(_AiBusyCheck check) {
    _aiBusyCheck = check;
  }

  bool _isAiBusy() => _aiBusyCheck?.call() ?? false;

  // ── Diretórios ──────────────────────────────────────────────────────────────
  Future<Directory> get _cacheRoot async {
    final base = await getApplicationSupportDirectory();
    return Directory('${base.path}/calculator_cache');
  }

  Future<Directory> get _currentDir async {
    final root = await _cacheRoot;
    return Directory('${root.path}/current');
  }

  Future<Directory> get _tmpDir async {
    final root = await _cacheRoot;
    return Directory('${root.path}/tmp');
  }

  File _manifestFile(Directory root) => File('${root.path}/manifest.json');

  // Arquivo de progresso dentro de tmp/ — persiste arquivos já baixados
  File _progressFile(Directory tmpDir) =>
      File('${tmpDir.path}/.progress.json');

  // ── API pública ────────────────────────────────────────────────────────────

  /// Retorna true se existe um cache local válido com index.html.
  /// Em Web sempre retorna false (usa iframe online).
  Future<bool> hasValidCache() async {
    if (kIsWeb) return false;
    try {
      final dir = await _currentDir;
      final index = File('${dir.path}/index.html');
      return index.existsSync();
    } catch (_) {
      return false;
    }
  }

  /// Retorna o path absoluto do index.html local.
  /// Retorna null se não houver cache válido.
  Future<String?> getLocalIndexPath() async {
    if (!await hasValidCache()) return null;
    final dir = await _currentDir;
    return '${dir.path}/index.html';
  }

  /// Constrói URL local com os query params da URL online preservados.
  ///   https://medcasescalcu.com/?lang=pt&tab=farmacos&q=amiodarona
  ///   → file:///…/current/index.html?lang=pt&tab=farmacos&q=amiodarona
  Future<String?> buildLocalUrl(String onlineUrl) async {
    final localPath = await getLocalIndexPath();
    if (localPath == null) return null;
    try {
      final parsed = Uri.parse(onlineUrl);
      final params = parsed.queryParameters;
      if (params.isEmpty) return 'file://$localPath';
      final query = params.entries
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      return 'file://$localPath?$query';
    } catch (_) {
      return 'file://$localPath';
    }
  }

  /// Inicia sync em background — fire-and-forget, nunca bloqueia.
  /// Seguro chamar múltiplas vezes (re-entrada protegida por _syncInProgress).
  /// Espera [_kInitialDelayMs] antes de qualquer I/O para deixar Home renderizar.
  String _currentSyncSlotId([DateTime? value]) {
    final now = value ?? DateTime.now();
    final slot = now.hour ~/ 8;
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}-$slot';
  }

  DateTime _nextSyncBoundary([DateTime? value]) {
    final now = value ?? DateTime.now();

    if (now.hour < 8) {
      return DateTime(now.year, now.month, now.day, 8);
    }
    if (now.hour < 16) {
      return DateTime(now.year, now.month, now.day, 16);
    }

    final tomorrow = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
  }

  void _ensureSyncScheduler() {
    if (kIsWeb) return;
    if (_schedulerStarted) return;

    _schedulerStarted = true;
    _scheduleNextSyncBoundary();
  }

  void _scheduleNextSyncBoundary() {
    _syncSlotTimer?.cancel();

    final now = DateTime.now();
    final next = _nextSyncBoundary(now);
    final delay = next.difference(now) + const Duration(seconds: 1);

    _syncSlotTimer = Timer(delay, () {
      unawaited(_runScheduledSync(skipInitialDelay: true));
      _scheduleNextSyncBoundary();
    });

    debugPrint(
      '[OFFLINE_CACHE][SCHEDULE] next=${next.toIso8601String()} '
      'delaySec=${delay.inSeconds}',
    );
  }

  Future<void> _runScheduledSync({
    bool skipInitialDelay = false,
  }) async {
    if (kIsWeb || _syncInProgress) return;

    final slot = _currentSyncSlotId();
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString(_kLastSuccessfulSlotKey);

    if (previous == slot && await hasValidCache()) {
      debugPrint('[OFFLINE_CACHE][SCHEDULE] slot=$slot alreadyChecked=true');
      return;
    }

    _lastManifestCheckSucceeded = false;

    await _doSync(skipInitialDelay: skipInitialDelay);

    if (_lastManifestCheckSucceeded) {
      await prefs.setString(_kLastSuccessfulSlotKey, slot);
      debugPrint('[OFFLINE_CACHE][SCHEDULE] slot=$slot persisted=true');
    } else {
      debugPrint(
        '[OFFLINE_CACHE][SCHEDULE] slot=$slot persisted=false retryOnResume=true',
      );
    }
  }

  /// Called by the app lifecycle owner whenever the app returns foreground.
  /// If the current 8-hour slot was not successfully checked, catch up now.
  void onAppResumed() {
    if (kIsWeb) return;
    _ensureSyncScheduler();
    unawaited(_runScheduledSync(skipInitialDelay: true));
  }

  /// Starts offline-readiness automatically without forcing network-off mode.
  void startBackgroundSync() {
    if (kIsWeb) return;

    _ensureSyncScheduler();
    unawaited(_runScheduledSync());
  }

  /// Força atualização imediata (botão "Atualizar agora").
  /// Cancela ciclo em andamento e reinicia sem atraso inicial.
  Future<void> forceUpdate() async {
    if (kIsWeb) return;
    _cancelRequested = true;
    // Aguarda o loop perceber o cancel (máx 1 polling cycle)
    await Future<void>.delayed(
        const Duration(milliseconds: _kPausePollingMs + 100));
    _cancelRequested = false;
    await _doSync(force: true, skipInitialDelay: true);
  }

  /// Limpa todo o cache local.
  Future<void> clearCache() async {
    if (kIsWeb) return;
    _cancelRequested = true;
    try {
      final root = await _cacheRoot;
      if (root.existsSync()) await root.delete(recursive: true);
      _emit(_state.copyWith(
        status: CalcuCacheStatus.unknown,
        localVersion: null,
        downloadedAt: null,
        fileCount: 0,
        filesDownloaded: 0,
        filesTotal: 0,
        progress: 0.0,
        errorMessage: null,
      ));
      debugPrint('[OFFLINE_CACHE] cache limpo');
    } catch (e) {
      debugPrint('[OFFLINE_CACHE] erro ao limpar cache: $e');
    } finally {
      _cancelRequested = false;
    }
  }

  // ── Orquestração principal ─────────────────────────────────────────────────

  Future<void> _doSync({
    bool force = false,
    bool skipInitialDelay = false,
  }) async {
    _syncInProgress = true;
    try {
      if (!skipInitialDelay) {
        // Atraso inicial: deixa a Home renderizar e a IA inicializar
        debugPrint('[OFFLINE_CACHE] aguardando ${_kInitialDelayMs}ms antes de sincronizar');
        await Future<void>.delayed(
            Duration(milliseconds: _kInitialDelayMs));
      }
      if (_cancelRequested) return;
      await _syncImpl(force: force);
    } catch (e) {
      debugPrint('[OFFLINE_CACHE] error=$e');
      _emit(_state.copyWith(
        status: CalcuCacheStatus.error,
        errorMessage: e.toString(),
      ));
    } finally {
      _syncInProgress = false;
    }
  }

  Future<void> _syncImpl({bool force = false}) async {
    // 1. Carrega estado local persistido
    await _loadLocalManifest();
    if (_cancelRequested) return;

    // 2. Busca manifest remoto
    final remote = await _fetchRemoteManifest();
    if (_cancelRequested) return;

    if (remote == null) {
      debugPrint('[OFFLINE_CACHE] manifest remoto indisponível — fallback online');
      if (!await hasValidCache()) {
        _emit(_state.copyWith(
            status: CalcuCacheStatus.error, errorMessage: 'sem conexão'));
      }
      return;
    }

    final remoteVersion = remote['version'] as String? ?? '0';
    final localVersion  = _state.localVersion ?? '';
    debugPrint('[OFFLINE_CACHE] manifest remote version=$remoteVersion '
        'local version=$localVersion');

    _emit(_state.copyWith(remoteVersion: remoteVersion));

    // 3. Compara versões
    final needsUpdate = force ||
        localVersion.isEmpty ||
        localVersion != remoteVersion;

    if (!needsUpdate) {
      debugPrint('[OFFLINE_CACHE] ready=true (versão atual)');
      _emit(_state.copyWith(status: CalcuCacheStatus.ready));
      return;
    }

    // Se já tem cache e a versão remota é nova → sinaliza updateAvailable
    if (await hasValidCache() && !force) {
      _emit(_state.copyWith(
        status: CalcuCacheStatus.updateAvailable,
        remoteVersion: remoteVersion,
      ));
      debugPrint('[OFFLINE_CACHE] updateAvailable=true v=$remoteVersion');
    }

    // 4. Download em lotes throttled
    await _downloadVersionThrottled(remote, remoteVersion);
  }

  // ── Download throttled em lotes ────────────────────────────────────────────

  Future<void> _downloadVersionThrottled(
      Map<String, dynamic> manifest, String version) async {
    final rawFiles = (manifest['files'] as List?)
            ?.map((f) => f.toString())
            .toList() ??
        [];

    if (rawFiles.isEmpty) {
      debugPrint('[OFFLINE_CACHE] manifest sem arquivos — abortando');
      return;
    }

    // Valida que nenhum arquivo aponta para domínio externo não confiável
    for (final f in rawFiles) {
      if (f.startsWith('http')) {
        final host = Uri.tryParse(f)?.host ?? '';
        if (!_kAllowedHosts.contains(host)) {
          debugPrint('[OFFLINE_CACHE] SEGURANÇA: arquivo bloqueado: $f');
          return;
        }
      }
    }

    final baseUrl = manifest['baseUrl'] as String? ?? _kBaseUrl;

    // Prepara diretório tmp/
    final tmpDir = await _tmpDir;
    if (!tmpDir.existsSync()) tmpDir.createSync(recursive: true);

    // Carrega progresso anterior (resume de sessões anteriores)
    final alreadyDone = _loadProgress(tmpDir);
    debugPrint('[OFFLINE_CACHE] retomando: ${alreadyDone.length} arquivos já '
        'baixados de sessão anterior');

    // Filtra apenas arquivos que ainda precisam ser baixados
    final todo = rawFiles
        .where((f) => !alreadyDone.contains(f))
        .toList();

    final int totalFiles = rawFiles.length;
    int completedCount   = alreadyDone.length;
    int failedCount      = 0;

    _emit(_state.copyWith(
      status: CalcuCacheStatus.downloading,
      filesTotal: totalFiles,
      filesDownloaded: completedCount,
      progress: totalFiles > 0 ? completedCount / totalFiles : 0.0,
    ));

    debugPrint('[OFFLINE_CACHE] download iniciado: '
        '${todo.length} pendentes / $totalFiles total v=$version');

    // ── Loop de lotes ─────────────────────────────────────────────────────
    int i = 0;
    while (i < todo.length) {
      if (_cancelRequested) {
        debugPrint('[OFFLINE_CACHE] download cancelado por solicitação');
        return;
      }

      // Pausa se AI ou caching do app está ocupado
      if (_isAiBusy()) {
        _emit(_state.copyWith(status: CalcuCacheStatus.downloadPaused));
        debugPrint('[OFFLINE_CACHE] pausado — AI/caching ocupado');

        // Espera polling até AI terminar
        while (_isAiBusy()) {
          if (_cancelRequested) return;
          await Future<void>.delayed(
              const Duration(milliseconds: _kPausePollingMs));
        }

        _emit(_state.copyWith(status: CalcuCacheStatus.downloading));
        debugPrint('[OFFLINE_CACHE] retomado — AI/caching livre');
      }

      // Processa um lote de kBatchSize arquivos
      final batchEnd = (i + _kBatchSize).clamp(0, todo.length);
      final batch = todo.sublist(i, batchEnd);

      for (final filePath in batch) {
        if (_cancelRequested) return;

        // Yield: devolve o event loop antes de cada arquivo
        await Future<void>.delayed(Duration.zero);

        final success = await _downloadFile(
          filePath: filePath,
          baseUrl: baseUrl,
          targetDir: tmpDir,
        );

        if (success) {
          completedCount++;
          alreadyDone.add(filePath);
        } else {
          failedCount++;
          debugPrint('[OFFLINE_CACHE] falha no arquivo: $filePath');
        }

        final progress =
            totalFiles > 0 ? completedCount / totalFiles : 0.0;

        _emit(_state.copyWith(
          filesDownloaded: completedCount,
          filesTotal: totalFiles,
          progress: progress,
        ));

        debugPrint('[OFFLINE_CACHE] progress=${(progress * 100).toStringAsFixed(0)}% '
            'file=$filePath ok=$success '
            '($completedCount/$totalFiles)');
      }

      // Persiste progresso após cada lote — permite retomar na próxima sessão
      _saveProgress(tmpDir, alreadyDone);

      i = batchEnd;

      // Pausa inter-lote — cede CPU para Flutter/IA
      if (i < todo.length) {
        await Future<void>.delayed(
            const Duration(milliseconds: _kInterBatchDelayMs));
      }
    }

    // ── Fim do loop ───────────────────────────────────────────────────────
    debugPrint('[OFFLINE_CACHE] download concluído: '
        'ok=$completedCount fail=$failedCount total=$totalFiles');

    if (_cancelRequested) return;

    // Valida arquivos essenciais
    for (final essential in _kEssentialFiles) {
      final f = File('${tmpDir.path}/$essential');
      if (!f.existsSync() || f.lengthSync() == 0) {
        debugPrint('[OFFLINE_CACHE] ESSENCIAL FALTANDO: $essential — abortando swap');
        _emit(_state.copyWith(
          status: CalcuCacheStatus.error,
          errorMessage: 'arquivo essencial ausente: $essential',
        ));
        return; // mantém versão antiga funcionando
      }
    }

    // Swap atômico: tmp/ → current/
    await _atomicSwap(tmpDir, version, completedCount);
  }

  // ── Persistência de progresso ──────────────────────────────────────────────

  Set<String> _loadProgress(Directory tmpDir) {
    try {
      final f = _progressFile(tmpDir);
      if (!f.existsSync()) return {};
      final data = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final list = (data['downloaded'] as List?)?.cast<String>() ?? [];
      return list.toSet();
    } catch (_) {
      return {};
    }
  }

  void _saveProgress(Directory tmpDir, Set<String> downloaded) {
    try {
      final f = _progressFile(tmpDir);
      f.writeAsStringSync(jsonEncode({'downloaded': downloaded.toList()}));
    } catch (_) {
      // Falha ao salvar progresso é não-fatal — pior caso = redownload na sessão seguinte
    }
  }

  // ── Download de arquivo único ──────────────────────────────────────────────

  Future<bool> _downloadFile({
    required String filePath,
    required String baseUrl,
    required Directory targetDir,
  }) async {
    try {
      // Monta URL completa
      final String url;
      if (filePath.startsWith('http')) {
        url = filePath;
      } else {
        final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
        url = '$base$filePath';
      }

      // Valida host (allowlist de segurança)
      final host = Uri.parse(url).host;
      if (!_kAllowedHosts.contains(host)) {
        debugPrint('[OFFLINE_CACHE] SEGURANÇA: host bloqueado: $host');
        return false;
      }

      // Skip se arquivo já existe com conteúdo (resume entre sessões)
      final targetFile = File('${targetDir.path}/$filePath');
      if (targetFile.existsSync() && targetFile.lengthSync() > 0) {
        debugPrint('[OFFLINE_CACHE] skip (já existe): $filePath');
        return true;
      }

      final resp = await http
          .get(Uri.parse(url))
          .timeout(Duration(seconds: _kFileTimeoutSec));

      if (resp.statusCode != 200) {
        debugPrint('[OFFLINE_CACHE] HTTP ${resp.statusCode} para $filePath');
        return false;
      }

      await targetFile.parent.create(recursive: true);
      await targetFile.writeAsBytes(resp.bodyBytes);
      return true;
    } catch (e) {
      debugPrint('[OFFLINE_CACHE] error=$e arquivo=$filePath');
      return false;
    }
  }

  // ── Swap atômico ───────────────────────────────────────────────────────────

  Future<void> _atomicSwap(
      Directory tmpDir, String version, int fileCount) async {
    try {
      final root       = await _cacheRoot;
      final currentDir = await _currentDir;

      // Remove versão anterior SOMENTE após nova estar validada
      if (currentDir.existsSync()) {
        await currentDir.delete(recursive: true);
      }

      // Renomeia tmp/ → current/
      await tmpDir.rename(currentDir.path);

      // Persiste manifest local
      final now          = DateTime.now();
      final manifestData = {
        'version':     version,
        'downloadedAt': now.toIso8601String(),
        'fileCount':   fileCount,
        'status':      'ready',
      };
      await _manifestFile(root).writeAsString(jsonEncode(manifestData));

      _emit(_state.copyWith(
        status:          CalcuCacheStatus.ready,
        localVersion:    version,
        downloadedAt:    now,
        fileCount:       fileCount,
        filesDownloaded: fileCount,
        progress:        1.0,
        errorMessage:    null,
      ));

      debugPrint('[OFFLINE_CACHE] ready=true version=$version files=$fileCount');
    } catch (e) {
      debugPrint('[OFFLINE_CACHE] erro no swap atômico: $e');
      _emit(_state.copyWith(
        status: CalcuCacheStatus.error,
        errorMessage: 'falha no swap: $e',
      ));
    }
  }

  // ── Manifest local ─────────────────────────────────────────────────────────

  Future<void> _loadLocalManifest() async {
    try {
      final root = await _cacheRoot;
      final file = _manifestFile(root);
      if (!file.existsSync()) return;
      final json =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final downloadedAt = json['downloadedAt'] != null
          ? DateTime.tryParse(json['downloadedAt'] as String)
          : null;
      _emit(_state.copyWith(
        localVersion: json['version'] as String?,
        downloadedAt: downloadedAt,
        fileCount:    (json['fileCount'] as num?)?.toInt() ?? 0,
        status: json['status'] == 'ready'
            ? CalcuCacheStatus.ready
            : CalcuCacheStatus.unknown,
      ));
      debugPrint('[OFFLINE_CACHE] local manifest: '
          'v=${json['version']} '
          'downloadedAt=${json['downloadedAt']} '
          'files=${json['fileCount']}');
    } catch (e) {
      debugPrint('[OFFLINE_CACHE] erro ao ler manifest local: $e');
    }
  }

  // ── Manifest remoto ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _fetchRemoteManifest() async {
    try {
      final resp = await http
          .get(Uri.parse(_kManifestUrl))
          .timeout(Duration(seconds: _kManifestTimeoutSec));
      if (resp.statusCode != 200) {
        debugPrint('[OFFLINE_CACHE] manifest HTTP ${resp.statusCode}');
        return null;
      }
      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      _lastManifestCheckSucceeded = true;
      return decoded;
    } catch (e) {
      debugPrint('[OFFLINE_CACHE] erro ao buscar manifest remoto: $e');
      return null;
    }
  }

  // ── Emit helper ───────────────────────────────────────────────────────────

  void _emit(CalcuCacheState newState) {
    _state = newState;
    if (!_controller.isClosed) _controller.add(newState);
  }

  void dispose() {
    _controller.close();
  }
}
