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

  /// fromMap — NUNCA usa `as T` para evitar TypeError em dart2js release mode.
  /// dart2js retorna Map<String, Object?> no lugar de Map<String, dynamic>.
  /// Todos os campos usam helpers seguros: toString(), _parseInt(), _parseStr().
  factory InfluencerModel.fromMap(Map<String, dynamic> m) => InfluencerModel(
    id:              _s(m['id']),
    name:            _s(m['name']),
    couponCode:      _sn(m['couponCode']),
    discountPercent: _parseInt(m['discountPercent']),
    createdAt:       _parseDate(m['createdAt']) ?? DateTime.now(),
  );

  /// fromDoc — aceita qualquer Map retornado pelo SDK (Map<String,Object?> em dart2js).
  /// NUNCA usa `doc.data() as Map<String, dynamic>` — lança TypeError em release.
  factory InfluencerModel.fromDoc(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw is Map<String, dynamic>) return InfluencerModel.fromMap(raw);
    if (raw is Map) return InfluencerModel.fromMap(Map<String, dynamic>.from(raw));
    return InfluencerModel(id: doc.id, name: '', createdAt: DateTime.now());
  }

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

  // ── Safe helpers — sem cast direto, imunes a TypeError em dart2js ──────────

  /// Retorna String não-nula — nunca lança TypeError.
  static String _s(dynamic v, [String fallback = '']) =>
      v?.toString() ?? fallback;

  /// Retorna String? — null se nulo ou vazio.
  static String? _sn(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  /// Parse seguro de int/double/num/String → int?.
  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  // ── Helper ────────────────────────────────────────────────────────────────
  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
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
