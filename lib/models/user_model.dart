// user_model.dart — modelo de usuário MedCases Pro
import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { master, admin, supervisor, user }
enum UserStatus { pending, approved, blocked }

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final UserStatus status;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? profession;
  final String? institution;
  final String lang;
  final bool darkMode;
  final int totalUsageSeconds;   // tempo total de uso acumulado (em segundos)
  final DateTime? lastSeenAt;    // última vez ativo no app
  final String? referredBy;      // id do influenciador que trouxe este usuário

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.role = UserRole.user,
    this.status = UserStatus.pending,
    required this.createdAt,
    this.approvedAt,
    this.approvedBy,
    this.profession,
    this.institution,
    this.lang = 'pt',
    this.darkMode = false,
    this.totalUsageSeconds = 0,
    this.lastSeenAt,
    this.referredBy,
  });

  bool get isMaster    => role == UserRole.master;
  bool get isAdmin     => role == UserRole.admin || role == UserRole.master;
  bool get isSupervisor => role == UserRole.supervisor;
  bool get isApproved => status == UserStatus.approved;
  bool get isPending => status == UserStatus.pending;
  bool get isBlocked => status == UserStatus.blocked;

  // ── Tempo formatado para exibição ─────────────────────────────────────────
  String get usageFormatted {
    if (totalUsageSeconds <= 0) return '—';
    final h = totalUsageSeconds ~/ 3600;
    final m = (totalUsageSeconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}min';
    if (m > 0) return '${m}min';
    return '<1min';
  }

  // ── Safe helpers — sem cast direto, imunes a TypeError em dart2js ──────────
  static String _s(dynamic v, [String fallback = '']) =>
      v?.toString() ?? fallback;

  static bool _b(dynamic v, [bool fallback = false]) {
    if (v == true || v?.toString() == 'true') return true;
    if (v == false || v?.toString() == 'false') return false;
    return fallback;
  }

  static int _i(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  // ── Serialização JSON pura (SharedPreferences) ────────────────────────────
  Map<String, dynamic> toJson() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'role': role.name,
    'status': status.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'approvedAt': approvedAt?.toUtc().toIso8601String(),
    'approvedBy': approvedBy,
    'profession': profession,
    'institution': institution,
    'lang': lang,
    'darkMode': darkMode,
    'totalUsageSeconds': totalUsageSeconds,
    'lastSeenAt': lastSeenAt?.toUtc().toIso8601String(),
    'referred_by': referredBy,
  };

  factory UserModel.fromJson(Map<String, dynamic> m) => UserModel(
    uid:               _s(m['uid']),
    email:             _s(m['email']),
    displayName:       _s(m['displayName']),
    role:              _parseRole(_s(m['role'])),
    status:            _parseStatus(_s(m['status'])),
    createdAt:         _parseDate(m['createdAt']) ?? DateTime.now(),
    approvedAt:        _parseDate(m['approvedAt']),
    approvedBy:        _sn(m['approvedBy']),
    profession:        _sn(m['profession']),
    institution:       _sn(m['institution']),
    lang:              _s(m['lang'], 'pt'),
    darkMode:          _b(m['darkMode']),
    totalUsageSeconds: _i(m['totalUsageSeconds']),
    lastSeenAt:        _parseDate(m['lastSeenAt']),
    referredBy:        _sn(m['referred_by']),
  );

  // ── Serialização Firestore SDK ────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'role': role.name,
    'status': status.name,
    'createdAt': Timestamp.fromDate(createdAt),
    'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
    'approvedBy': approvedBy,
    'profession': profession,
    'institution': institution,
    'lang': lang,
    'darkMode': darkMode,
    'totalUsageSeconds': totalUsageSeconds,
    'lastSeenAt': lastSeenAt != null ? Timestamp.fromDate(lastSeenAt!) : null,
    'referred_by': referredBy,
  };

  factory UserModel.fromMap(Map<String, dynamic> m) => UserModel(
    uid:               _s(m['uid']),
    email:             _s(m['email']),
    displayName:       _s(m['displayName']),
    role:              _parseRole(_s(m['role'])),
    status:            _parseStatus(_s(m['status'])),
    createdAt:         _parseDate(m['createdAt']) ?? DateTime.now(),
    approvedAt:        _parseDate(m['approvedAt']),
    approvedBy:        _sn(m['approvedBy']),
    profession:        _sn(m['profession']),
    institution:       _sn(m['institution']),
    lang:              _s(m['lang'], 'pt'),
    darkMode:          _b(m['darkMode']),
    totalUsageSeconds: _i(m['totalUsageSeconds']),
    lastSeenAt:        _parseDate(m['lastSeenAt']),
    referredBy:        _sn(m['referred_by']),
  );

  /// fromDoc — aceita qualquer Map retornado pelo SDK (Map<String,Object?> em dart2js)
  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw is Map<String, dynamic>) return UserModel.fromMap(raw);
    if (raw is Map) return UserModel.fromMap(Map<String, dynamic>.from(raw));
    return UserModel(uid: doc.id, email: '', displayName: '', createdAt: DateTime.now());
  }

  UserModel copyWith({
    String? displayName,
    UserRole? role,
    UserStatus? status,
    DateTime? approvedAt,
    String? approvedBy,
    String? profession,
    String? institution,
    String? lang,
    bool? darkMode,
    int? totalUsageSeconds,
    DateTime? lastSeenAt,
    String? referredBy,
  }) =>
      UserModel(
        uid: uid,
        email: email,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
        status: status ?? this.status,
        createdAt: createdAt,
        approvedAt: approvedAt ?? this.approvedAt,
        approvedBy: approvedBy ?? this.approvedBy,
        profession: profession ?? this.profession,
        institution: institution ?? this.institution,
        lang: lang ?? this.lang,
        darkMode: darkMode ?? this.darkMode,
        totalUsageSeconds: totalUsageSeconds ?? this.totalUsageSeconds,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
        referredBy: referredBy ?? this.referredBy,
      );

  // ── Helpers ───────────────────────────────────────────────────────────────
  /// Retorna null se o valor for nulo ou vazio — nunca lança TypeError.
  static String? _sn(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) {
      try { return DateTime.parse(v); } catch (_) {}
    }
    return null;
  }

  static UserRole _parseRole(String s) {
    switch (s) {
      case 'master':     return UserRole.master;
      case 'admin':      return UserRole.admin;
      case 'supervisor': return UserRole.supervisor;
      default:           return UserRole.user;
    }
  }

  static UserStatus _parseStatus(String s) {
    switch (s) {
      case 'approved': return UserStatus.approved;
      case 'blocked':  return UserStatus.blocked;
      default:         return UserStatus.pending;
    }
  }

  String get roleLabel {
    switch (role) {
      case UserRole.master:     return 'Master';
      case UserRole.admin:      return 'Admin';
      case UserRole.supervisor: return 'Supervisor';
      case UserRole.user:       return 'Usuário';
    }
  }

  String get statusLabel {
    switch (status) {
      case UserStatus.approved: return 'Aprovado';
      case UserStatus.pending:  return 'Pendente';
      case UserStatus.blocked:  return 'Bloqueado';
    }
  }

  String get statusLabelEs {
    switch (status) {
      case UserStatus.approved: return 'Aprobado';
      case UserStatus.pending:  return 'Pendiente';
      case UserStatus.blocked:  return 'Bloqueado';
    }
  }
}
