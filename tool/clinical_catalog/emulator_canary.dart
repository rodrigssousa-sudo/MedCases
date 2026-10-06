import 'dart:convert';
import 'dart:io';
import '../../lib/services/clinical_catalog/clinical_catalog_repository.dart';

class EmulatorRemote implements ClinicalCatalogRemote {
  bool offline = false;
  Future<Map<String, dynamic>> get(String path) async {
    if (offline) throw const SocketException('synthetic_offline');
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(
          'http://127.0.0.1:8791/v1/projects/demo-clinical-canary/databases/(default)/documents/$path'));
      // Emulator-only admin token; authentication rules tested independently.
      req.headers.set('Authorization', 'Bearer owner');
      final res = await req.close();
      if (res.statusCode != 200) throw StateError('HTTP_${res.statusCode}');
      final json = jsonDecode(await utf8.decoder.bind(res).join()) as Map;
      Object? unpack(Map value) {
        if (value.containsKey('mapValue'))
          return (value['mapValue']['fields'] as Map? ?? {})
              .map((k, v) => MapEntry(k.toString(), unpack(v)));
        if (value.containsKey('arrayValue'))
          return (value['arrayValue']['values'] as List? ?? [])
              .map((v) => unpack(v))
              .toList();
        if (value.containsKey('integerValue'))
          return int.parse(value['integerValue'].toString());
        return value['stringValue'] ??
            value['booleanValue'] ??
            value['doubleValue'];
      }

      return (unpack({
        'mapValue': {'fields': json['fields']}
      }) as Map)
          .cast<String, dynamic>();
    } finally {
      client.close();
    }
  }

  @override
  Future<Map<String, dynamic>> pointer() => get('app_config/clinical_content');
  @override
  Future<Map<String, dynamic>> manifest(String v) =>
      get('clinical_content_versions/$v');
  @override
  Future<String> chunk(String v, String id) async =>
      (await get('clinical_content_versions/$v/chunks/$id'))['json'] as String;
}

class Cache implements ClinicalCatalogCache {
  Cache(this.file);
  final File file;
  @override
  Future<Map<String, dynamic>?> read() async => await file.exists()
      ? jsonDecode(await file.readAsString()) as Map<String, dynamic>
      : null;
  @override
  Future<void> write(Map<String, dynamic> e) =>
      file.writeAsString(jsonEncode(e), flush: true).then((_) {});
}

Future<void> main() async {
  if (Platform.environment['FIRESTORE_EMULATOR_HOST'] != '127.0.0.1:8791')
    throw StateError('EMULATOR_REQUIRED');
  Future<void> command(String c) async {
    final p = await Process.run(
        'node', ['tool/clinical_catalog/emulator_admin.mjs', c]);
    if (p.exitCode != 0) throw StateError(p.stderr.toString());
  }

  final dir = await Directory.systemTemp.createTemp('clinical-canary');
  try {
    final remote = EmulatorRemote();
    final cache = Cache(File('${dir.path}/cache.json'));
    final repo = ClinicalCatalogRepository(remote: remote, cache: cache);
    Future<void> expectVersion(String version) async {
      final snapshot = await repo.acquire(refresh: true);
      if (snapshot.version != version)
        throw StateError('VERSION_${snapshot.version}_${repo.fallbackReason}');
      for (final mode in ['study', 'plantao']) {
        for (final lang in ['pt', 'es']) {
          if (snapshot.projections(mode, lang).single['version'] != version)
            throw StateError('PARITY');
        }
      }
      print('FOUR_PROJECTIONS_$version=PASS');
    }

    await command('A');
    await expectVersion('A');
    await command('draftB');
    await expectVersion('A');
    await command('B');
    await expectVersion('B');
    remote.offline = true;
    final restarted = await ClinicalCatalogRepository(
            remote: remote, cache: Cache(cache.file))
        .acquire();
    if (restarted.version != 'B' ||
        restarted.origin != ClinicalCatalogOrigin.cache)
      throw StateError('CACHE_RESTART');
    print('OFFLINE_RESTART_CACHE=PASS');
    remote.offline = false;
    await command('rollback');
    await expectVersion('A');
    print('REMOTE_UPDATE_WITHOUT_NEW_BUILD=PASS\nROLLBACK_POINTER_ONLY=PASS');
  } finally {
    await dir.delete(recursive: true);
  }
}
