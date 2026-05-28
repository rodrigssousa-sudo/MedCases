// influencer_model.dart — entidade Influencer para o Sistema de Indicações
import 'package:cloud_firestore/cloud_firestore.dart';

class InfluencerModel {
  final String id;             // slug único — usado na URL: ?ref=dr_marcos
  final String name;           // nome real de exibição: 'Dr. Marcos - Cardiologia'
  final String? couponCode;    // código do cupom: 'PLANTAO20' (futuro checkout)
  final int? discountPercent;  // porcentagem de desconto: 20 (futuro checkout)
  final DateTime createdAt;

  const InfluencerModel({
    required this.id,
    required this.name,
    this.couponCode,
    this.discountPercent,
    required this.createdAt,
  });

  // ── Serialização Firestore SDK ────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
    'id':              id,
    'name':            name,
    'couponCode':      couponCode,
    'discountPercent': discountPercent,
    'createdAt':       Timestamp.fromDate(createdAt),
  };

  factory InfluencerModel.fromMap(Map<String, dynamic> m) => InfluencerModel(
    id:              m['id']   as String? ?? '',
    name:            m['name'] as String? ?? '',
    couponCode:      m['couponCode'] as String?,
    discountPercent: (m['discountPercent'] as num?)?.toInt(),
    createdAt:       _parseDate(m['createdAt']) ?? DateTime.now(),
  );

  factory InfluencerModel.fromDoc(DocumentSnapshot doc) =>
      InfluencerModel.fromMap(doc.data() as Map<String, dynamic>);

  InfluencerModel copyWith({
    String? name,
    String? couponCode,
    int? discountPercent,
  }) =>
      InfluencerModel(
        id:              id,
        name:            name ?? this.name,
        couponCode:      couponCode ?? this.couponCode,
        discountPercent: discountPercent ?? this.discountPercent,
        createdAt:       createdAt,
      );

  // ── Helper ────────────────────────────────────────────────────────────────
  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String && v.isNotEmpty) {
      try { return DateTime.parse(v); } catch (_) {}
    }
    return null;
  }

  /// Texto formatado do cupom para exibição na tabela admin.
  String get couponLabel =>
      (couponCode != null && couponCode!.isNotEmpty)
          ? '$couponCode (${discountPercent ?? 0}% off)'
          : 'Nenhum';
}
