// user_model.dart — modelo de usuário MedCases Pro
import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, supervisor, user }
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
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isSupervisor => role == UserRole.supervisor;
  static const String _masterEmail = 'rodrigssousa@gmail.com';
  bool get isMaster => email.toLowerCase() == _masterEmail.toLowerCase();
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
  };

  factory UserModel.fromJson(Map<String, dynamic> m) => UserModel(
    uid: m['uid'] as String? ?? '',
    email: m['email'] as String? ?? '',
    displayName: m['displayName'] as String? ?? '',
    role: _parseRole(m['role'] as String?),
    status: _parseStatus(m['status'] as String?),
    createdAt: m['createdAt'] != null
        ? DateTime.parse(m['createdAt'] as String)
        : DateTime.now(),
    approvedAt: m['approvedAt'] != null
        ? DateTime.parse(m['approvedAt'] as String)
        : null,
    approvedBy: m['approvedBy'] as String?,
    profession: m['profession'] as String?,
    institution: m['institution'] as String?,
    lang: m['lang'] as String? ?? 'pt',
    darkMode: m['darkMode'] as bool? ?? false,
    totalUsageSeconds: (m['totalUsageSeconds'] as num?)?.toInt() ?? 0,
    lastSeenAt: m['lastSeenAt'] != null
        ? DateTime.tryParse(m['lastSeenAt'] as String)
        : null,
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
  };

  factory UserModel.fromMap(Map<String, dynamic> m) => UserModel(
    uid: m['uid'] as String? ?? '',
    email: m['email'] as String? ?? '',
    displayName: m['displayName'] as String? ?? '',
    role: _parseRole(m['role'] as String?),
    status: _parseStatus(m['status'] as String?),
    createdAt: _parseDate(m['createdAt']) ?? DateTime.now(),
    approvedAt: _parseDate(m['approvedAt']),
    approvedBy: m['approvedBy'] as String?,
    profession: m['profession'] as String?,
    institution: m['institution'] as String?,
    lang: m['lang'] as String? ?? 'pt',
    darkMode: m['darkMode'] as bool? ?? false,
    totalUsageSeconds: (m['totalUsageSeconds'] as num?)?.toInt() ?? 0,
    lastSeenAt: _parseDate(m['lastSeenAt']),
  );

  factory UserModel.fromDoc(DocumentSnapshot doc) =>
      UserModel.fromMap(doc.data() as Map<String, dynamic>);

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
      );

  // ── Helpers ───────────────────────────────────────────────────────────────
  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String && v.isNotEmpty) {
      try { return DateTime.parse(v); } catch (_) {}
    }
    return null;
  }

  static UserRole _parseRole(String? s) {
    switch (s) {
      case 'admin':      return UserRole.admin;
      case 'supervisor': return UserRole.supervisor;
      default:           return UserRole.user;
    }
  }

  static UserStatus _parseStatus(String? s) {
    switch (s) {
      case 'approved': return UserStatus.approved;
      case 'blocked':  return UserStatus.blocked;
      default:         return UserStatus.pending;
    }
  }

  String get roleLabel {
    switch (role) {
      case UserRole.admin:      return isMaster ? 'Master' : 'Admin';
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
