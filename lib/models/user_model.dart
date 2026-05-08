// user_model.dart — modelo de usuário MedCases Pro
import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, user }
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
  final String? profession;    // médico, residente, enfermeiro, etc.
  final String? institution;   // hospital / clínica
  final String lang;
  final bool darkMode;

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
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isApproved => status == UserStatus.approved;
  bool get isPending => status == UserStatus.pending;
  bool get isBlocked => status == UserStatus.blocked;

  // ── Serialização ──────────────────────────────────────────────────────────

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
  };

  factory UserModel.fromMap(Map<String, dynamic> m) => UserModel(
    uid: m['uid'] as String? ?? '',
    email: m['email'] as String? ?? '',
    displayName: m['displayName'] as String? ?? '',
    role: _parseRole(m['role'] as String?),
    status: _parseStatus(m['status'] as String?),
    createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    approvedAt: (m['approvedAt'] as Timestamp?)?.toDate(),
    approvedBy: m['approvedBy'] as String?,
    profession: m['profession'] as String?,
    institution: m['institution'] as String?,
    lang: m['lang'] as String? ?? 'pt',
    darkMode: m['darkMode'] as bool? ?? false,
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
      );

  // ── Helpers ───────────────────────────────────────────────────────────────

  static UserRole _parseRole(String? s) {
    switch (s) {
      case 'admin': return UserRole.admin;
      default: return UserRole.user;
    }
  }

  static UserStatus _parseStatus(String? s) {
    switch (s) {
      case 'approved': return UserStatus.approved;
      case 'blocked': return UserStatus.blocked;
      default: return UserStatus.pending;
    }
  }

  String get roleLabel {
    switch (role) {
      case UserRole.admin: return 'Admin';
      case UserRole.user: return 'Usuário';
    }
  }

  String get statusLabel {
    switch (status) {
      case UserStatus.approved: return 'Aprovado';
      case UserStatus.pending: return 'Pendente';
      case UserStatus.blocked: return 'Bloqueado';
    }
  }

  String get statusLabelEs {
    switch (status) {
      case UserStatus.approved: return 'Aprobado';
      case UserStatus.pending: return 'Pendiente';
      case UserStatus.blocked: return 'Bloqueado';
    }
  }
}
