import 'clinical_catalog_functional_baseline.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'clinical_catalog_repository.dart';

class FirestoreClinicalCatalogRemote implements ClinicalCatalogRemote {
  FirestoreClinicalCatalogRemote({FirebaseFirestore? firestore})
      : _firestore = firestore;
  final FirebaseFirestore? _firestore;
  FirebaseFirestore get db => _firestore ?? FirebaseFirestore.instance;
  Future<Map<String, dynamic>> _get(String path) async {
    final doc = await db
        .doc(path)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 8));
    if (!doc.exists) throw const ClinicalCatalogInvalid('document_missing');
    return doc.data()!;
  }

  @override
  Future<Map<String, dynamic>> pointer() => _get('app_config/clinical_content');
  @override
  Future<Map<String, dynamic>> manifest(String version) =>
      _get('clinical_content_versions/$version');
  @override
  Future<String> chunk(String version, String id) async =>
      (await _get('clinical_content_versions/$version/chunks/$id'))['json']
          as String;
}

/// Published clinical content only: contains no account, patient or chat data.
/// Intentionally outside user-session caches so logout cannot erase this fallback.
class FileClinicalCatalogCache implements ClinicalCatalogCache {
  FileClinicalCatalogCache({this.directory});
  final Directory? directory;
  Future<File> _file() async {
    final root = directory ?? await getApplicationSupportDirectory();
    final folder = Directory('${root.path}/clinical_catalog_r2');
    await folder.create(recursive: true);
    return File('${folder.path}/last_valid.json');
  }

  @override
  Future<Map<String, dynamic>?> read() async {
    final file = await _file();
    if (!await file.exists()) return null;
    return (jsonDecode(await file.readAsString()) as Map)
        .cast<String, dynamic>();
  }

  @override
  Future<void> write(Map<String, dynamic> envelope) async {
    ClinicalCatalogValidator.validate(envelope, ClinicalCatalogOrigin.cache);
    final file = await _file();
    final temporary = File('${file.path}.pending');
    await temporary.writeAsString(jsonEncode(envelope), flush: true);
    await temporary.rename(file.path);
  }
}

class SharedClinicalCatalog {
  SharedClinicalCatalog._();
  static final ClinicalCatalogRepository instance = ClinicalCatalogRepository(
      // Production coverage floor; partial migration drafts are emulator-only.
      requiredSurfaceOwners: clinicalRequiredSurfaceOwners,
      minimumRemoteOwnerCount: 577, // Schema-1 compatibility only; schema-2 uses exact surface sets.
      remote: FirestoreClinicalCatalogRemote(),
      cache: FileClinicalCatalogCache(),
      onRead: (metadata) {
        if (kDebugMode) {
          debugPrint('[CLINICAL_CATALOG_R1] ${jsonEncode(metadata)}');
        }
      });
}
