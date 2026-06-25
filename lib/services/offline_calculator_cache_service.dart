// offline_calculator_cache_service.dart — MedCases Pro
// BUILD 240 — Smart Offline Cache para a Calculadora Clínica WebView
//
// ═══════════════════════════════════════════════════════════════════════════
// ARQUITETURA
// ═══════════════════════════════════════════════════════════════════════════
//
// Fluxo principal:
//   1. App abre com internet → startBackgroundSync() chamado na Home.
//   2. Baixa manifest remoto (https://medcasescalcu.com/manifest-offline.json).
//   3. Compara versão remota x local.
//   4. Se remoto > local (ou sem cache): baixa todos os arquivos para tmp/.
//   5. Valida arquivos essenciais.
//   6. Swap atômico: tmp/ → current/.
//   7. Salva manifest.json local com version, downloadedAt, fileCount, status.
//   8. CalculadoraScreen consulta hasValidCache() para decidir local vs online.
//
// Diretório:
//   <ApplicationSupportDirectory>/calculator_cache/
//     manifest.json          ← metadados do cache local
//     current/               ← versão ativa servida pela WebView
//       index.html
//       sw.js
//       css/…
//       js/…
//       database/…
//     tmp/                   ← download em andamento (descartado se incompleto)
//
// Segurança:
//   • Apenas downloads de medcasescalcu.com e www.medcasescalcu.com.
//   • Nenhum arquivo de CDN externa é salvo localmente.
//   • Swap atômico garante que versão antiga fica disponível se nova falhar.
//
// Web:
//   • path_provider não suporta Web → hasValidCache() retorna false no Web.
//   • No Web a WebView usa iframe → modo online sempre.
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constantes
// ─────────────────────────────────────────────────────────────────────────────

const _kManifestUrl = 'https://medcasescalcu.com/manifest-offline.json';
const _kBaseUrl     = 'https://medcasescalcu.com/';

/// Arquivos essenciais — se qualquer um falhar, a nova versão não é ativada.
const _kEssentialFiles = [
  'index.html',
  'js/medcases-ux-v2.js',
  'js/hub-accordion.js',
  'js/elec-calc.js',
  'database/cardio.js',
  'database/interacoes.js',
];

/// Domínios permitidos para download.
const _kAllowedHosts = ['medcasescalcu.com', 'www.medcasescalcu.com'];

// ─────────────────────────────────────────────────────────────────────────────
// Modelos
// ─────────────────────────────────────────────────────────────────────────────

enum CalcuCacheStatus {
  unknown,    // ainda não verificado
  downloading, // download em andamento
  ready,      // cache válido disponível
  updateAvailable, // nova versão disponível (cache atual ainda válido)
  error,      // falha no último download
}

class CalcuCacheState {
  final CalcuCacheStatus status;
  final String? localVersion;
  final String? remoteVersion;
  final DateTime? downloadedAt;
  final int fileCount;
  final double progress; // 0.0 → 1.0 durante download
  final String? errorMessage;

  const CalcuCacheState({
    this.status = CalcuCacheStatus.unknown,
    this.localVersion,
    this.remoteVersion,
    this.downloadedAt,
    this.fileCount = 0,
    this.progress = 0.0,
    this.errorMessage,
  });

  CalcuCacheState copyWith({
    CalcuCacheStatus? status,
    String? localVersion,
    String? remoteVersion,
    DateTime? downloadedAt,
    int? fileCount,
    double? progress,
    String? errorMessage,
  }) => CalcuCacheState(
    status:          status         ?? this.status,
    localVersion:    localVersion   ?? this.localVersion,
    remoteVersion:   remoteVersion  ?? this.remoteVersion,
    downloadedAt:    downloadedAt   ?? this.downloadedAt,
    fileCount:       fileCount      ?? this.fileCount,
    progress:        progress       ?? this.progress,
    errorMessage:    errorMessage   ?? this.errorMessage,
  );

  bool get isReady => status == CalcuCacheStatus.ready ||
                      status == CalcuCacheStatus.updateAvailable;
}

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

  bool _syncInProgress = false;

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

  /// Retorna o path do index.html local para abertura na WebView.
  /// Retorna null se não houver cache válido.
  Future<String?> getLocalIndexPath() async {
    if (!await hasValidCache()) return null;
    final dir = await _currentDir;
    return '${dir.path}/index.html';
  }

  /// Constrói a URL local com os query params da URL original (online).
  /// Ex: https://medcasescalcu.com/?lang=pt&tab=farmacos&q=amiodarona
  ///  → file:///…/current/index.html?lang=pt&tab=farmacos&q=amiodarona
  Future<String?> buildLocalUrl(String onlineUrl) async {
    final localPath = await getLocalIndexPath();
    if (localPath == null) return null;

    try {
      final parsed = Uri.parse(onlineUrl);
      final params = parsed.queryParameters;
      if (params.isEmpty) return 'file://$localPath';
      final query = params.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      return 'file://$localPath?$query';
    } catch (_) {
      return 'file://$localPath';
    }
  }

  /// Inicia sync em background. Não bloqueia.
  /// Seguro para chamar repetidamente — re-entrada protegida por _syncInProgress.
  void startBackgroundSync() {
    if (kIsWeb) return; // Web não usa cache de arquivo local
    if (_syncInProgress) {
      debugPrint('[OFFLINE_CACHE] sync já em andamento — ignorando nova chamada');
      return;
    }
    // ignore: unawaited_futures
    _doSync();
  }

  /// Força atualização imediata (botão "Atualizar agora" na UI).
  Future<void> forceUpdate() async {
    if (kIsWeb) return;
    if (_syncInProgress) return;
    await _doSync(force: true);
  }

  /// Limpa todo o cache local.
  Future<void> clearCache() async {
    if (kIsWeb) return;
    try {
      final root = await _cacheRoot;
      if (root.existsSync()) await root.delete(recursive: true);
      _emit(_state.copyWith(
        status: CalcuCacheStatus.unknown,
        localVersion: null,
        downloadedAt: null,
        fileCount: 0,
      ));
      debugPrint('[OFFLINE_CACHE] cache limpo');
    } catch (e) {
      debugPrint('[OFFLINE_CACHE] error ao limpar cache: $e');
    }
  }

  // ── Lógica interna ─────────────────────────────────────────────────────────

  Future<void> _doSync({bool force = false}) async {
    _syncInProgress = true;
    try {
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
    // 1. Carregar estado local existente
    await _loadLocalManifest();

    // 2. Baixar manifest remoto
    final remote = await _fetchRemoteManifest();
    if (remote == null) {
      debugPrint('[OFFLINE_CACHE] fallbackOnline=true (manifest remoto indisponível)');
      // Se não tem cache local e não tem internet → status error
      if (!await hasValidCache()) {
        _emit(_state.copyWith(status: CalcuCacheStatus.error,
            errorMessage: 'sem conexão'));
      }
      return;
    }

    final remoteVersion = remote['version'] as String? ?? '0';
    final localVersion  = _state.localVersion ?? '';
    debugPrint('[OFFLINE_CACHE] manifest remote version=$remoteVersion');
    debugPrint('[OFFLINE_CACHE] local version=$localVersion');

    _emit(_state.copyWith(remoteVersion: remoteVersion));

    // 3. Comparar versões
    final needsUpdate = force || localVersion.isEmpty || localVersion != remoteVersion;
    if (!needsUpdate) {
      debugPrint('[OFFLINE_CACHE] ready=true (versão atual, sem atualização necessária)');
      _emit(_state.copyWith(status: CalcuCacheStatus.ready));
      return;
    }

    // Se há cache local válido e versão remota é nova → sinaliza updateAvailable
    if (await hasValidCache() && !force) {
      _emit(_state.copyWith(
        status: CalcuCacheStatus.updateAvailable,
        remoteVersion: remoteVersion,
      ));
      debugPrint('[OFFLINE_CACHE] updateAvailable=true');
    }

    // 4. Baixar nova versão para tmp/
    await _downloadVersion(remote, remoteVersion);
  }

  Future<void> _loadLocalManifest() async {
    try {
      final root = await _cacheRoot;
      final file = _manifestFile(root);
      if (!file.existsSync()) return;
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
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
      debugPrint('[OFFLINE_CACHE] local version=${json['version']} '
          'downloadedAt=${json['downloadedAt']} '
          'fileCount=${json['fileCount']}');
    } catch (e) {
      debugPrint('[OFFLINE_CACHE] erro ao ler manifest local: $e');
    }
  }

  Future<Map<String, dynamic>?> _fetchRemoteManifest() async {
    try {
      final resp = await http.get(Uri.parse(_kManifestUrl))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) {
        debugPrint('[OFFLINE_CACHE] manifest HTTP ${resp.statusCode}');
        return null;
      }
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[OFFLINE_CACHE] erro ao buscar manifest remoto: $e');
      return null;
    }
  }

  Future<void> _downloadVersion(
      Map<String, dynamic> manifest, String version) async {
    final files = (manifest['files'] as List?)
        ?.map((f) => f.toString())
        .toList() ?? [];

    if (files.isEmpty) {
      debugPrint('[OFFLINE_CACHE] manifest sem arquivos — abortando');
      return;
    }

    // Validar que nenhum arquivo aponta para domínio externo
    for (final f in files) {
      if (f.startsWith('http')) {
        final host = Uri.tryParse(f)?.host ?? '';
        if (!_kAllowedHosts.contains(host)) {
          debugPrint('[OFFLINE_CACHE] SEGURANÇA: arquivo bloqueado (domínio não confiável): $f');
          return;
        }
      }
    }

    _emit(_state.copyWith(
      status: CalcuCacheStatus.downloading,
      progress: 0.0,
    ));
    debugPrint('[OFFLINE_CACHE] iniciando download de ${files.length} arquivo(s) v=$version');

    final tmpDir = await _tmpDir;
    // Limpa tmp anterior se houver
    if (tmpDir.existsSync()) await tmpDir.delete(recursive: true);
    tmpDir.createSync(recursive: true);

    int downloaded = 0;
    int failed = 0;

    for (final filePath in files) {
      final success = await _downloadFile(
        filePath: filePath,
        baseUrl: manifest['baseUrl'] as String? ?? _kBaseUrl,
        targetDir: tmpDir,
      );
      if (success) {
        downloaded++;
      } else {
        failed++;
        debugPrint('[OFFLINE_CACHE] falha no arquivo: $filePath');
      }
      final progress = downloaded / files.length;
      _emit(_state.copyWith(progress: progress));
      debugPrint('[OFFLINE_CACHE] progress=${(progress * 100).toStringAsFixed(0)}% '
          'file=$filePath ok=$success');
    }

    debugPrint('[OFFLINE_CACHE] download concluído: ok=$downloaded fail=$failed total=${files.length}');

    // Validar arquivos essenciais
    for (final essential in _kEssentialFiles) {
      final f = File('${tmpDir.path}/$essential');
      if (!f.existsSync() || f.lengthSync() == 0) {
        debugPrint('[OFFLINE_CACHE] ESSENCIAL FALTANDO: $essential — abortando swap');
        _emit(_state.copyWith(
          status: CalcuCacheStatus.error,
          errorMessage: 'arquivo essencial ausente: $essential',
        ));
        // Mantém versão antiga funcionando — não apaga current
        return;
      }
    }

    // Swap atômico: tmp → current
    await _atomicSwap(tmpDir, version, files.length);
  }

  Future<bool> _downloadFile({
    required String filePath,
    required String baseUrl,
    required Directory targetDir,
  }) async {
    try {
      // Monta URL: se filePath já é URL absoluta, usa direta; senão concatena com baseUrl
      final String url;
      if (filePath.startsWith('http')) {
        url = filePath;
      } else {
        final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
        url = '$base$filePath';
      }

      // Valida host
      final host = Uri.parse(url).host;
      if (!_kAllowedHosts.contains(host)) {
        debugPrint('[OFFLINE_CACHE] SEGURANÇA: host bloqueado: $host');
        return false;
      }

      debugPrint('[OFFLINE_CACHE] downloading file=$filePath');

      final resp = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) {
        debugPrint('[OFFLINE_CACHE] HTTP ${resp.statusCode} para $filePath');
        return false;
      }

      // Cria diretórios necessários
      final targetFile = File('${targetDir.path}/$filePath');
      await targetFile.parent.create(recursive: true);
      await targetFile.writeAsBytes(resp.bodyBytes);
      return true;
    } catch (e) {
      debugPrint('[OFFLINE_CACHE] error=$e arquivo=$filePath');
      return false;
    }
  }

  Future<void> _atomicSwap(
      Directory tmpDir, String version, int fileCount) async {
    try {
      final root = await _cacheRoot;
      final currentDir = await _currentDir;

      // Remove versão anterior
      if (currentDir.existsSync()) {
        await currentDir.delete(recursive: true);
      }

      // Move tmp → current
      await tmpDir.rename(currentDir.path);

      // Salva manifest local
      final now = DateTime.now();
      final manifestData = {
        'version':     version,
        'downloadedAt': now.toIso8601String(),
        'fileCount':   fileCount,
        'status':      'ready',
      };
      await _manifestFile(root).writeAsString(jsonEncode(manifestData));

      _emit(_state.copyWith(
        status:       CalcuCacheStatus.ready,
        localVersion: version,
        downloadedAt: now,
        fileCount:    fileCount,
        progress:     1.0,
        errorMessage: null,
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

  void _emit(CalcuCacheState newState) {
    _state = newState;
    if (!_controller.isClosed) _controller.add(newState);
  }

  void dispose() {
    _controller.close();
  }
}
