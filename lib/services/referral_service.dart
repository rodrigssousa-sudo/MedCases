// referral_service.dart — Sistema de Indicações MedCases Pro
// CRUD de influenciadores + contagem de conversões
//
// ARQUITETURA WEB vs NATIVO:
// • Web:    usa Firestore REST API com idToken do AuthService (kIsWeb == true)
//           O app Web faz login via REST (identitytoolkit), não via Firebase SDK,
//           portanto FirebaseFirestore.instance não tem auth → permission-denied.
// • Nativo: usa FirebaseFirestore.instance (SDK) normalmente.
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore, Timestamp;
import 'package:http/http.dart' as http;
import '../models/influencer_model.dart';
import 'auth_service.dart';

class ReferralService {
  static const _col       = 'influencers';
  static const _projectId = 'medcases-pro';
  static const _fsBase    =
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents';

  // SDK nativo (não-Web)
  static final _db = FirebaseFirestore.instance;

  // ═══════════════════════════════════════════════════════════════════════════
  // SLUG GENERATOR
  // ═══════════════════════════════════════════════════════════════════════════
  static String generateSlug(String name) {
    var s = name.toLowerCase();
    const Map<String, String> accents = {
      'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'ä': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'ó': 'o', 'ò': 'o', 'õ': 'o', 'ô': 'o', 'ö': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c', 'ñ': 'n',
    };
    accents.forEach((from, to) => s = s.replaceAll(from, to));
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    s = s.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
    if (s.length > 40) s = s.substring(0, 40).replaceAll(RegExp(r'_$'), '');
    return s;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS REST — converte entre Map Dart e formato Firestore REST
  // ═══════════════════════════════════════════════════════════════════════════

  /// Converte documento REST do Firestore em Map<String, dynamic> Dart.
  static Map<String, dynamic> _restDocToMap(Map<String, dynamic> doc) {
    final fields = doc['fields'] as Map<String, dynamic>? ?? {};
    final result = <String, dynamic>{};
    fields.forEach((key, value) {
      final v = value as Map<String, dynamic>;
      if (v.containsKey('stringValue'))    result[key] = v['stringValue'];
      else if (v.containsKey('integerValue')) result[key] = int.tryParse(v['integerValue'].toString()) ?? 0;
      else if (v.containsKey('doubleValue'))  result[key] = (v['doubleValue'] as num).toDouble();
      else if (v.containsKey('booleanValue')) result[key] = v['booleanValue'] as bool;
      else if (v.containsKey('nullValue'))    result[key] = null;
      else if (v.containsKey('timestampValue')) result[key] = v['timestampValue'];
    });
    return result;
  }

  /// Converte Map Dart em payload de campos para Firestore REST.
  static Map<String, dynamic> _mapToRestFields(Map<String, dynamic> data) {
    final fields = <String, dynamic>{};
    data.forEach((key, value) {
      if (value == null) {
        fields[key] = {'nullValue': null};
      } else if (value is bool) {
        fields[key] = {'booleanValue': value};
      } else if (value is int) {
        fields[key] = {'integerValue': value.toString()};
      } else if (value is double) {
        fields[key] = {'doubleValue': value};
      } else if (value is DateTime) {
        fields[key] = {'timestampValue': value.toUtc().toIso8601String()};
      } else if (value is Timestamp) {
        // Firestore SDK Timestamp → converte para ISO 8601 para REST
        fields[key] = {'timestampValue': value.toDate().toUtc().toIso8601String()};
      } else {
        fields[key] = {'stringValue': value.toString()};
      }
    });
    return fields;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CRUD
  // ═══════════════════════════════════════════════════════════════════════════

  /// Cria um influenciador. Lança [Exception] se o slug já existir.
  static Future<InfluencerModel> createInfluencer({
    required String name,
    String? couponCode,
    int? discountPercent,
    String? customSlug,
  }) async {
    final slug = (customSlug != null && customSlug.isNotEmpty)
        ? customSlug
        : generateSlug(name);

    // Verifica duplicidade
    if (await slugExists(slug)) {
      throw Exception('Já existe um influenciador com o slug "$slug". '
          'Escolha um nome diferente ou forneça um slug customizado.');
    }

    final inf = InfluencerModel(
      id:              slug,
      name:            name.trim(),
      couponCode:      (couponCode != null && couponCode.trim().isNotEmpty)
                           ? couponCode.trim().toUpperCase()
                           : null,
      discountPercent: discountPercent,
      createdAt:       DateTime.now(),
    );

    if (kIsWeb) {
      final token = await AuthService.getAdminToken();
      if (token.isEmpty) throw Exception('Não autenticado. Faça login novamente.');

      // REST: cria documento com ID explícito usando PATCH
      final url = '$_fsBase/$_col/$slug';
      final resp = await http.patch(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'fields': _mapToRestFields(inf.toMap())}),
      );
      if (resp.statusCode != 200) {
        throw Exception('Erro ao criar influenciador: HTTP ${resp.statusCode}');
      }
    } else {
      await _db.collection(_col).doc(slug).set(inf.toMap());
    }
    return inf;
  }

  /// Retorna lista completa de influenciadores, ordenados por nome (in-memory sort).
  /// Não usa orderBy() para evitar requisito de índice composto.
  static Future<List<InfluencerModel>> getInfluencers() async {
    if (kIsWeb) {
      final token = await AuthService.getAdminToken();
      if (token.isEmpty) throw Exception('Não autenticado.');

      // REST: lista todos os documentos da coleção
      final url = '$_fsBase/$_col';
      final resp = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (resp.statusCode == 401 || resp.statusCode == 403) {
        throw Exception('[cloud_firestore/permission-denied] REST: sem permissão (${resp.statusCode})');
      }
      if (resp.statusCode != 200) {
        throw Exception('Erro ao carregar influenciadores: HTTP ${resp.statusCode}');
      }

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final docs = body['documents'] as List<dynamic>? ?? [];

      final list = docs.map((d) {
        final doc = d as Map<String, dynamic>;
        // Extrai o slug do caminho: .../influencers/{slug}
        final namePath = doc['name'] as String? ?? '';
        final docSlug = namePath.split('/').last;
        final data = _restDocToMap(doc);
        data['id'] = docSlug; // injeta o id (slug) que vem do path REST
        return InfluencerModel.fromMap(data);
      }).toList();

      // Sort in-memory por nome
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    }

    // Nativo — SDK
    final snap = await _db.collection(_col).orderBy('name').get();
    return snap.docs.map(InfluencerModel.fromDoc).toList();
  }

  /// Stream em tempo real — Web usa polling a cada 5s (REST não tem WebSocket).
  static Stream<List<InfluencerModel>> influencersStream() {
    if (kIsWeb) {
      // No Web, transforma Future em Stream que re-executa a cada 5 segundos
      return Stream.periodic(const Duration(seconds: 5))
          .asyncMap((_) => getInfluencers())
          .distinct();
    }
    return _db
        .collection(_col)
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map(InfluencerModel.fromDoc).toList());
  }

  /// Remove um influenciador pelo id/slug.
  static Future<void> deleteInfluencer(String id) async {
    if (kIsWeb) {
      final token = await AuthService.getAdminToken();
      if (token.isEmpty) throw Exception('Não autenticado.');
      final url = '$_fsBase/$_col/$id';
      final resp = await http.delete(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode != 200) {
        throw Exception('Erro ao remover influenciador: HTTP ${resp.statusCode}');
      }
    } else {
      await _db.collection(_col).doc(id).delete();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MÉTRICAS DE CONVERSÃO
  // ═══════════════════════════════════════════════════════════════════════════

  /// Conta usuários indicados por um influenciador.
  static Future<int> getConversionCount(String influencerId) async {
    try {
      if (kIsWeb) {
        final token = await AuthService.getAdminToken();
        if (token.isEmpty) return 0;
        // REST: query com filtro referred_by == influencerId
        final url = Uri.parse('$_fsBase:runQuery');
        final resp = await http.post(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'structuredQuery': {
              'from': [{'collectionId': 'users'}],
              'where': {
                'fieldFilter': {
                  'field': {'fieldPath': 'referred_by'},
                  'op': 'EQUAL',
                  'value': {'stringValue': influencerId},
                }
              },
              'select': {'fields': [{'fieldPath': 'uid'}]},
            }
          }),
        );
        if (resp.statusCode != 200) return 0;
        final results = jsonDecode(resp.body) as List<dynamic>;
        // runQuery retorna [{document: ...}, ...] — filtra docs reais (sem readTime-only)
        return results.where((r) {
          final m = r as Map<String, dynamic>;
          return m.containsKey('document');
        }).length;
      }

      // Nativo — SDK com aggregation
      try {
        final agg = await _db
            .collection('users')
            .where('referred_by', isEqualTo: influencerId)
            .count()
            .get();
        return agg.count ?? 0;
      } catch (_) {
        final snap = await _db
            .collection('users')
            .where('referred_by', isEqualTo: influencerId)
            .get();
        return snap.size;
      }
    } catch (_) {
      return 0;
    }
  }

  /// Batch de contagens para múltiplos influenciadores.
  static Future<Map<String, int>> getBatchConversionCounts(
      List<String> influencerIds) async {
    final futures = influencerIds.map(
      (id) => getConversionCount(id).then((n) => MapEntry(id, n)),
    );
    final entries = await Future.wait(futures);
    return Map.fromEntries(entries);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CHECKOUT PREP
  // ═══════════════════════════════════════════════════════════════════════════

  /// Verifica cupom ativo para um usuário (para aplicar desconto automático).
  static Future<({String couponCode, int discountPercent})?> getActiveCouponForUser(
      String userId) async {
    try {
      if (kIsWeb) {
        final token = await AuthService.getAdminToken();
        if (token.isEmpty) return null;
        // Lê o usuário para obter referred_by
        final userResp = await http.get(
          Uri.parse('$_fsBase/users/$userId'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (userResp.statusCode != 200) return null;
        final userData = _restDocToMap(jsonDecode(userResp.body) as Map<String, dynamic>);
        final referredBy = userData['referred_by'] as String?;
        if (referredBy == null || referredBy.isEmpty) return null;

        final infResp = await http.get(
          Uri.parse('$_fsBase/$_col/$referredBy'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (infResp.statusCode != 200) return null;
        final infData = _restDocToMap(jsonDecode(infResp.body) as Map<String, dynamic>);
        infData['id'] = referredBy;
        final inf = InfluencerModel.fromMap(infData);
        if (inf.couponCode == null || inf.couponCode!.isEmpty) return null;
        if (inf.discountPercent == null || inf.discountPercent! <= 0) return null;
        return (couponCode: inf.couponCode!, discountPercent: inf.discountPercent!);
      }

      final userDoc = await _db.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;
      final referredBy = userDoc.data()?['referred_by'] as String?;
      if (referredBy == null || referredBy.isEmpty) return null;
      final infDoc = await _db.collection(_col).doc(referredBy).get();
      if (!infDoc.exists) return null;
      final inf = InfluencerModel.fromDoc(infDoc);
      if (inf.couponCode == null || inf.couponCode!.isEmpty) return null;
      if (inf.discountPercent == null || inf.discountPercent! <= 0) return null;
      return (couponCode: inf.couponCode!, discountPercent: inf.discountPercent!);
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VALIDAÇÃO DE SLUG
  // ═══════════════════════════════════════════════════════════════════════════

  /// Retorna true se o slug já está em uso.
  static Future<bool> slugExists(String slug) async {
    try {
      if (kIsWeb) {
        final token = await AuthService.getAdminToken();
        if (token.isEmpty) return false;
        final resp = await http.get(
          Uri.parse('$_fsBase/$_col/$slug'),
          headers: {'Authorization': 'Bearer $token'},
        );
        return resp.statusCode == 200;
      }
      final doc = await _db.collection(_col).doc(slug).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }
}
