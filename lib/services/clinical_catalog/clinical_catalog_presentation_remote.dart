import 'package:cloud_firestore/cloud_firestore.dart';

/// Existing R12 read contract, reused for presentation reconciliation only.
/// No write, authorization, model or ledger API is exposed here.
abstract interface class ClinicalCatalogRemote {
  Future<Map<String, dynamic>> pointer();
  Future<Map<String, dynamic>> manifest(String version);
  Future<String> chunk(String version, String id);
}

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
    if (!doc.exists) throw const FormatException('document_missing');
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
