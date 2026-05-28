// referral_service.dart — Sistema de Indicações MedCases Pro
// CRUD de influenciadores + contagem de conversões + checkout prep (futuro)
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/influencer_model.dart';

class ReferralService {
  static const _col = 'influencers';
  static final _db  = FirebaseFirestore.instance;

  // ═══════════════════════════════════════════════════════════════════════════
  // SLUG GENERATOR
  // Converte nome → id/slug válido para URL: 'Dr. Marcos – Card.' → 'dr_marcos_card'
  // ═══════════════════════════════════════════════════════════════════════════
  static String generateSlug(String name) {
    // 1. lowercase
    var s = name.toLowerCase();
    // 2. substitui acentuados → versão ASCII equivalente
    const Map<String, String> accents = {
      'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'ä': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'ó': 'o', 'ò': 'o', 'õ': 'o', 'ô': 'o', 'ö': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c', 'ñ': 'n',
    };
    accents.forEach((from, to) => s = s.replaceAll(from, to));
    // 3. substitui qualquer char que não seja letra/dígito → underscore
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    // 4. remove underscores duplos e de extremidade
    s = s.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
    // 5. trunca em 40 chars para não ter slug gigante
    if (s.length > 40) s = s.substring(0, 40).replaceAll(RegExp(r'_$'), '');
    return s;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CRUD
  // ═══════════════════════════════════════════════════════════════════════════

  /// Cria um influenciador. O id/slug é gerado a partir do nome se não for
  /// fornecido. Lança [Exception] se o slug já existir no Firestore.
  static Future<InfluencerModel> createInfluencer({
    required String name,
    String? couponCode,
    int? discountPercent,
    String? customSlug,
  }) async {
    final slug = (customSlug != null && customSlug.isNotEmpty)
        ? customSlug
        : generateSlug(name);

    // Garante unicidade — slug duplicado lança erro legível
    final existing = await _db.collection(_col).doc(slug).get();
    if (existing.exists) {
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

    await _db.collection(_col).doc(slug).set(inf.toMap());
    return inf;
  }

  /// Retorna lista completa de influenciadores, ordenados por nome.
  static Future<List<InfluencerModel>> getInfluencers() async {
    final snap = await _db
        .collection(_col)
        .orderBy('name')
        .get();
    return snap.docs.map(InfluencerModel.fromDoc).toList();
  }

  /// Stream em tempo real da coleção de influenciadores.
  static Stream<List<InfluencerModel>> influencersStream() =>
      _db
          .collection(_col)
          .orderBy('name')
          .snapshots()
          .map((s) => s.docs.map(InfluencerModel.fromDoc).toList());

  /// Remove um influenciador pelo id/slug.
  static Future<void> deleteInfluencer(String id) =>
      _db.collection(_col).doc(id).delete();

  // ═══════════════════════════════════════════════════════════════════════════
  // MÉTRICAS DE CONVERSÃO — query agregada performática (sem varredura total)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Conta quantos usuários foram indicados pelo influenciador [influencerId].
  /// Usa AggregateQuery (count) — O(1) do ponto de vista de leitura de dados;
  /// o Firestore cobra apenas 1 leitura por chamada, independente do resultado.
  /// IMPORTANTE: o índice em `referred_by` é criado automaticamente pelo
  /// Firestore por ser campo de igualdade simples — sem índice composto necessário.
  static Future<int> getConversionCount(String influencerId) async {
    try {
      final agg = await _db
          .collection('users')
          .where('referred_by', isEqualTo: influencerId)
          .count()
          .get();
      return agg.count ?? 0;
    } catch (_) {
      // Fallback leve se count() não estiver disponível na versão do SDK:
      // conta docs via get() sem baixar campos (apenas metadados)
      try {
        final snap = await _db
            .collection('users')
            .where('referred_by', isEqualTo: influencerId)
            .get();
        return snap.size;
      } catch (_) {
        return 0;
      }
    }
  }

  /// Retorna contagem para múltiplos influenciadores de uma vez — batch paralelo.
  /// Útil para popular a tabela admin sem N chamadas sequenciais.
  static Future<Map<String, int>> getBatchConversionCounts(
      List<String> influencerIds) async {
    final futures = influencerIds.map(
      (id) => getConversionCount(id).then((n) => MapEntry(id, n)),
    );
    final entries = await Future.wait(futures);
    return Map.fromEntries(entries);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CHECKOUT PREP — auxiliar para futura monetização
  // ═══════════════════════════════════════════════════════════════════════════

  /// Dado um [userId], verifica se ele tem um influenciador indicador e retorna
  /// o coupon_code + discount_percent. Retorna null se não tiver indicação
  /// ou se o influenciador não tiver cupom configurado.
  ///
  /// Uso no checkout: se != null, aplica automaticamente o desconto sem
  /// que o usuário precise digitar nada.
  static Future<({String couponCode, int discountPercent})?> getActiveCouponForUser(
      String userId) async {
    try {
      // 1. Busca o usuário para obter o referred_by
      final userDoc = await _db.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;

      final referredBy = userDoc.data()?['referred_by'] as String?;
      if (referredBy == null || referredBy.isEmpty) return null;

      // 2. Busca o influenciador
      final infDoc = await _db.collection(_col).doc(referredBy).get();
      if (!infDoc.exists) return null;

      final inf = InfluencerModel.fromDoc(infDoc);
      if (inf.couponCode == null || inf.couponCode!.isEmpty) return null;
      if (inf.discountPercent == null || inf.discountPercent! <= 0) return null;

      return (
        couponCode:      inf.couponCode!,
        discountPercent: inf.discountPercent!,
      );
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VALIDAÇÃO DE SLUG — utilitário para o formulário admin
  // ═══════════════════════════════════════════════════════════════════════════

  /// Retorna true se o slug já está em uso no Firestore.
  static Future<bool> slugExists(String slug) async {
    final doc = await _db.collection(_col).doc(slug).get();
    return doc.exists;
  }
}
