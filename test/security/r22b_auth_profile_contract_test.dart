import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/user_model.dart';

void main() {
  Map<String, dynamic> profile({
    String role = 'user',
    String status = 'approved',
  }) => <String, dynamic>{
        'uid': 'fictitious-test-uid',
        'email': 'someone@example.invalid',
        'displayName': 'Fictitious Test',
        'createdAt': '2026-09-16T00:00:00.000Z',
        'role': role,
        'status': status,
        'acceptedTerms': false,
      };

  test('existing master/admin are parsed solely from persisted role', () {
    final master = UserModel.fromJson(profile(role: 'master'));
    expect(master.role, UserRole.master);
    expect(master.isMaster, true);
    expect(master.isAdmin, true);

    final admin = UserModel.fromJson(profile(role: 'admin'));
    expect(admin.role, UserRole.admin);
    expect(admin.isMaster, false);
    expect(admin.isAdmin, true);
  });

  test('pending and blocked profiles are never auto-approved by the model', () {
    final pending = UserModel.fromMap(profile(status: 'pending'));
    final blocked = UserModel.fromMap(profile(status: 'blocked'));
    expect(pending.status, UserStatus.pending);
    expect(blocked.status, UserStatus.blocked);
    expect(pending.isApproved, false);
    expect(blocked.isApproved, false);
  });

  test('an email string alone does not assign administrator privilege', () {
    final ordinary = UserModel.fromJson(profile());
    expect(ordinary.role, UserRole.user);
    expect(ordinary.isAdmin, false);
    final unknown = UserModel.fromJson(profile(role: 'invalid-role'));
    expect(unknown.role, UserRole.user);
  });

  test('R22B auth source has no email-driven privilege or pending approval', () {
    final src = File('lib/services/auth_service.dart').readAsStringSync();
    expect(src.contains('adminEmail'), false);
    expect(src.contains('_autoApproveInBackground'), false);
    expect(src.contains("'system-auto'"), false);
    expect(src.contains('role: UserRole.user,'), true);
    expect(src.contains('status: UserStatus.pending,'), true);
    expect(src.contains("..remove('isPartner')"), true);
    expect(src.contains("..remove('partnerTitle')"), true);
    expect(src.contains("..remove('referralLink')"), true);
    expect(src.contains('throw StateError(\'Falha ao persistir perfil'), true);
    expect(src.contains('rethrow;'), true);
  });
}
