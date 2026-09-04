import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clinical app no longer exposes admin drawer entry', () {
    final main = File('lib/main.dart').readAsStringSync();

    expect(main, contains('ADMIN_V2_EXTERNAL_WEB_ONLY'));
    expect(
      main,
      isNot(contains(
        "title: p.lang == 'es' ? 'Panel Admin' : 'Painel Admin'",
      )),
    );
  });

  test('admin v2 keeps dedicated web entrypoint and role gate', () {
    final entry = File('lib/main_admin.dart').readAsStringSync();
    final screen =
        File('lib/screens/admin_v2/admin_v2_screen.dart').readAsStringSync();

    expect(entry, contains('MedCasesAdminApp'));
    expect(entry, contains('DefaultFirebaseOptions.currentPlatform'));
    expect(screen, contains('if (!admin.isAdmin)'));
    expect(screen, contains('AdminV2Screen(currentAdmin: admin)'));
    expect(screen, contains('Erros & Saúde do Sistema'));
    expect(screen, contains("collection('admin_incidents')"));
    expect(screen, contains("loadDocument('admin_metrics/realtime')"));
    expect(screen, contains("loadDocument('admin_error_metrics/realtime')"));
    expect(screen, contains('AdminScreen(currentAdmin: widget.currentAdmin)'));
  });

  test('dashboard is compact and reads real user metrics from Firestore', () {
    final screen =
        File('lib/screens/admin_v2/admin_v2_screen.dart').readAsStringSync();

    expect(screen, contains('ADMIN_V2_DASHBOARD_REAL_USERS_REST_V3'));
    expect(screen, isNot(contains("collection('users').snapshots()")));
    expect(screen, contains('AuthService.getAdminToken()'));
    expect(screen, contains('FirebaseAuth.instance.currentUser'));
    expect(screen, contains('sdkUser.getIdToken()'));
    expect(screen, contains('sdkUser.getIdToken(true)'));
    expect(screen, contains("loadDocument('admin_metrics/realtime')"));
    expect(screen, contains("loadDocument('admin_error_metrics/realtime')"));
    expect(
      screen,
      isNot(
        contains(
          ".collection('admin_metrics')\\n              .doc('realtime')\\n              .snapshots()",
        ),
      ),
    );
    expect(
      screen,
      isNot(
        contains(
          ".collection('admin_error_metrics')\\n          .doc('realtime')\\n          .snapshots()",
        ),
      ),
    );
    expect(screen, contains('firestore.googleapis.com'));
    expect(screen, contains("'pageSize': '1000'"));
    expect(screen, contains("query['pageToken'] = pageToken"));
    expect(
      screen,
      contains(r"headers: {'Authorization': 'Bearer $token'}"),
    );
    expect(screen, contains('_AdminUserMetrics.fromRows'));
    expect(screen, contains("data['lastSeenAt']"));
    expect(screen, contains("data['createdAt']"));
    expect(screen, contains("data['plan']"));
    expect(screen, contains("data['subscriptionStatus']"));
    expect(screen, contains("'Ativos hoje'"));
    expect(screen, contains("label: 'DAU'"));
    expect(screen, contains("label: 'WAU'"));
    expect(screen, contains("label: 'MAU'"));
    expect(
      RegExp(r'width\s*>=\s*760\s*\?\s*5', multiLine: true).hasMatch(screen),
      isTrue,
    );
    expect(screen, contains('width: 220'));
    expect(screen, contains('height: 58'));
    expect(screen, contains('height: 198'));
    expect(screen, contains('void _reloadAll()'));
    expect(screen, contains('_SystemHealthCard(data: errorData)'));
  });

  test('subscriptions revenue is master-only and prewired for future billing',
      () {
    final screen =
        File('lib/screens/admin_v2/admin_v2_screen.dart').readAsStringSync();

    expect(screen, contains('ADMIN_V2_BILLING_FOUNDATION_V1'));
    expect(
      screen,
      contains('return _SubscriptionsRevenueSection(allowed: _isMaster)'),
    );
    expect(screen, contains("loadDocument('admin_billing_metrics/realtime')"));
    expect(screen, contains("data['subscriptionStatus']"));
    expect(screen, contains("'subscriptionProvider'"));
    expect(screen, contains("'billingProvider'"));
    expect(screen, contains("'Apple App Store'"));
    expect(screen, contains("'Google Play'"));
    expect(screen, contains("'Stripe Web'"));
    expect(screen, contains("billing['mrr']"));
    expect(screen, contains("billing['grossRevenueMonth']"));
    expect(screen, contains("billing['netRevenueMonth']"));
    expect(screen, contains("billing['churnPct']"));
    expect(screen, contains("billing['refundsMonth']"));
    expect(screen, contains('Pré-lançamento — sem assinantes pagos'));
    expect(
      screen,
      contains(
        'Segredos e validação de compra permanecem no backend; nunca no navegador.',
      ),
    );
    expect(screen, isNot(contains('sk_live_')));
    expect(screen, isNot(contains('STRIPE_SECRET_KEY')));
  });

  test('users core management is migrated into admin v2', () {
    final screen =
        File('lib/screens/admin_v2/admin_v2_screen.dart').readAsStringSync();

    expect(screen, contains('ADMIN_V2_USERS_MIGRATION_V1'));
    expect(screen, contains('return _UsersManagementSection('));
    expect(screen, contains('class _UsersManagementSection'));
    expect(screen, contains('Buscar nome, e-mail, profissão ou UID'));
    expect(screen, contains("'Pendentes'"));
    expect(screen, contains("'Aprovados'"));
    expect(screen, contains("'Bloqueados'"));
    expect(screen, contains("'Equipe'"));

    expect(screen, contains('patchUserFields('));
    expect(screen, contains('deleteUserDocument('));
    expect(screen, contains("'status': 'approved'"));
    expect(screen, contains("'status': 'blocked'"));
    expect(screen, contains("'role': 'supervisor'"));
    expect(screen, contains("'role': 'admin'"));
    expect(screen, contains("'role': 'user'"));

    expect(screen, contains('uid == widget.currentAdmin.uid'));
    expect(screen, contains("role == 'master'"));
    expect(
      screen,
      contains('Esta alteração de permissão é exclusiva do Master.'),
    );

    expect(screen, contains('http.patch('));
    expect(screen, contains('http.delete('));
    expect(screen, contains("'updateMask.fieldPaths'"));
    expect(screen, contains("'approvedBy': widget.currentAdmin.uid"));
  });

  test('AI costs core is migrated into admin v2', () {
    final screen =
        File('lib/screens/admin_v2/admin_v2_screen.dart').readAsStringSync();

    expect(screen, contains('ADMIN_V2_AI_COSTS_MIGRATION_V1'));
    expect(screen, contains('return _AiCostsSection('));
    expect(screen, contains('class _AiCostsSection'));
    expect(screen, contains('widget.currentAdmin.isMaster'));

    expect(
      screen,
      contains("loadDocument('app_config/global')"),
    );
    expect(
      screen,
      contains("loadDocument('app_config/paid_budget')"),
    );
    expect(
      screen,
      contains("loadDocument('admin_ai_metrics/realtime')"),
    );

    expect(screen, contains('patchDocumentFields('));
    expect(screen, contains("'geminiPaidEnabled': enabled"));
    expect(screen, contains('Segredos permanecem no backend'));
    expect(screen, contains('Nenhuma chave de provedor é carregada'));
    expect(screen, contains('Fallback pago'));
    expect(screen, contains('Requisições 24h'));
    expect(screen, contains('Tokens 24h'));
    expect(screen, contains('Custo IA mês'));

    expect(screen, contains('ADMIN_V2_DASHBOARD_REAL_USERS_REST_V3'));
    expect(screen, contains('ADMIN_V2_BILLING_FOUNDATION_V1'));
    expect(screen, contains('ADMIN_V2_USERS_MIGRATION_V1'));
  });

  test('errors health center is REST-only and operational', () {
    final screen =
        File('lib/screens/admin_v2/admin_v2_screen.dart').readAsStringSync();

    expect(screen, contains('ADMIN_V2_ERRORS_HEALTH_CENTER_V1'));
    expect(screen, contains('return _ErrorsHealthCenterSection('));
    expect(screen, contains('class _ErrorsHealthCenterSection'));

    expect(
      screen,
      contains("listCollection(\n      'admin_incidents'"),
    );
    expect(screen,
        contains('static Future<List<Map<String, dynamic>>> listCollection'));
    expect(screen, contains("'pageSize':"));
    expect(screen, contains("'pageToken'"));

    expect(screen, contains("'critical'"));
    expect(screen, contains("'investigating'"));
    expect(screen, contains("'resolved'"));
    expect(screen, contains('stackTrace'));
    expect(screen, contains('safeUserId'));
    expect(screen, contains('affectedUsers'));
    expect(screen, contains('appVersion'));
    expect(screen, contains('buildNumber'));

    expect(
      screen,
      contains(r"'admin_incidents/${incident.id}'"),
    );
    expect(screen, contains("'acknowledgedBy': widget.currentAdmin.uid"));
    expect(screen, contains("'resolvedBy': widget.currentAdmin.uid"));
    expect(
      screen,
      contains(
        'widget.currentAdmin.isMaster || widget.currentAdmin.isAdmin',
      ),
    );

    expect(screen, contains('ADMIN_V2_DASHBOARD_REAL_USERS_REST_V3'));
    expect(screen, contains('ADMIN_V2_BILLING_FOUNDATION_V1'));
    expect(screen, contains('ADMIN_V2_USERS_MIGRATION_V1'));
    expect(screen, contains('ADMIN_V2_AI_COSTS_MIGRATION_V1'));
  });

  test('clinical guides core is migrated into admin v2', () {
    final screen =
        File('lib/screens/admin_v2/admin_v2_screen.dart').readAsStringSync();

    expect(screen, contains('ADMIN_V2_CONTENT_GUIDES_MIGRATION_V1'));
    expect(screen, contains('return _ContentGuidesSection('));
    expect(screen, contains('class _ContentGuidesSection'));

    expect(
      screen,
      contains("listCollection(\n      'clinical_guides'"),
    );
    expect(
      screen,
      contains(r"'clinical_guides/${guide.id}'"),
    );
    expect(screen, contains("'isPublished': false"));
    expect(screen, contains("'updatedBy': widget.currentAdmin.uid"));
    expect(screen, contains('deleteDocument('));

    expect(screen, contains('AdminClinicalGuideEditorScreen('));
    expect(screen, contains('GuideModel.fromJson('));
    expect(screen, contains('Novo guia'));
    expect(screen, contains('Abrir editor'));
    expect(screen, contains('Publicar no CMS'));
    expect(screen, isNot(contains('onOpenLegacyUpload')));
    expect(
      screen,
      contains('Supervisor possui acesso somente leitura.'),
    );

    expect(screen, contains('ADMIN_V2_DASHBOARD_REAL_USERS_REST_V3'));
    expect(screen, contains('ADMIN_V2_BILLING_FOUNDATION_V1'));
    expect(screen, contains('ADMIN_V2_USERS_MIGRATION_V1'));
    expect(screen, contains('ADMIN_V2_AI_COSTS_MIGRATION_V1'));
    expect(screen, contains('ADMIN_V2_ERRORS_HEALTH_CENTER_V1'));
  });

  test('content v2 uses audited canonical bilingual CMS', () {
    final screen =
        File('lib/screens/admin_v2/admin_v2_screen.dart').readAsStringSync();
    final editor = File(
      'lib/screens/admin_clinical_guide_editor_screen.dart',
    ).readAsStringSync();

    expect(screen, contains('ADMIN_V2_CONTENT_CANONICAL_CMS_V2'));
    expect(
      screen,
      contains("import '../../models/guide_model.dart';"),
    );
    expect(
      screen,
      contains(
        "import '../admin_clinical_guide_editor_screen.dart';",
      ),
    );

    expect(screen, contains('GuideModel.fromJson('));
    expect(screen, contains('AdminClinicalGuideEditorScreen('));
    expect(screen, contains('guide: fullGuide'));
    expect(screen, contains('adminName: adminName'));
    expect(screen, contains('Novo guia'));
    expect(screen, contains('Abrir editor'));
    expect(screen, contains('Publicar no CMS'));

    expect(
      screen,
      contains(r"'clinical_guides/${guide.id}'"),
    );
    expect(screen, contains("'isPublished': false"));
    expect(
      screen,
      isNot(contains("'isPublished': !guide.isPublished")),
    );
    expect(screen, isNot(contains('onOpenLegacyUpload')));
    expect(screen, isNot(contains("labelText: 'URL do PDF'")));

    expect(editor, contains('final GuideModel? guide;'));
    expect(editor, contains('final String adminName;'));
    expect(editor, contains('Salvar rascunho'));
    expect(editor, contains('Pré-visualizar'));
    expect(editor, contains('Publicar PT + ES'));
  });

  test('communication core is native to admin v2', () {
    final screen =
        File('lib/screens/admin_v2/admin_v2_screen.dart').readAsStringSync();

    expect(screen, contains('ADMIN_V2_COMMUNICATION_MIGRATION_V1'));
    expect(screen, contains('return _CommunicationSection('));
    expect(screen, contains('class _CommunicationSection'));

    expect(screen, contains("'admin_notifications'"));
    expect(screen, contains("'global_push_campaigns'"));
    expect(screen, contains("'email_campaigns'"));
    expect(screen, contains("'app_config/emailjs'"));

    expect(screen, contains('createCollectionDocument('));
    expect(screen, contains("'status': 'pending'"));
    expect(screen, contains("'targetRole': 'all'"));

    expect(screen, contains('Marcar lida'));
    expect(screen, contains("'readBy': <String>["));

    expect(
      screen,
      contains('https://api.emailjs.com/api/v1.0/email/send'),
    );
    expect(screen, contains("'service_id': serviceId"));
    expect(screen, contains("'template_id': templateId"));
    expect(screen, contains("'user_id': publicKey"));
    expect(screen, contains("'to_email': toEmail"));
    expect(screen, contains("'from_name': 'MedCases Pro'"));

    expect(screen, contains('Confirmar disparo em massa'));
    expect(screen, contains('Confirmar campanha de e-mail'));
    expect(screen, contains('Supervisor possui acesso somente leitura.'));
    expect(screen, contains('widget.currentAdmin.isMaster'));
    expect(screen, contains('widget.currentAdmin.isAdmin'));

    expect(
      screen,
      isNot(
        contains(
          "case _AdminSection.communication:\n"
          "        return _LegacyBridge(",
        ),
      ),
    );

    expect(screen, contains('ADMIN_V2_DASHBOARD_REAL_USERS_REST_V3'));
    expect(screen, contains('ADMIN_V2_BILLING_FOUNDATION_V1'));
    expect(screen, contains('ADMIN_V2_USERS_MIGRATION_V1'));
    expect(screen, contains('ADMIN_V2_AI_COSTS_MIGRATION_V1'));
    expect(screen, contains('ADMIN_V2_ERRORS_HEALTH_CENTER_V1'));
    expect(screen, contains('ADMIN_V2_CONTENT_CANONICAL_CMS_V2'));
  });

  test('settings core is native to admin v2', () {
    final screen =
        File('lib/screens/admin_v2/admin_v2_screen.dart').readAsStringSync();

    expect(screen, contains('ADMIN_V2_SETTINGS_MIGRATION_V1'));
    expect(screen, contains('return _SettingsSection('));
    expect(screen, contains('class _SettingsSection'));

    expect(screen, contains("'app_config/maintenance'"));
    expect(screen, contains("'app_updates/current'"));

    expect(screen, contains("'enabled': _maintenanceEnabled"));
    expect(screen, contains("'message': message"));
    expect(screen, contains("'updatedBy': widget.currentAdmin.uid"));

    expect(screen, contains("'version': version"));
    expect(screen, contains("'title': title"));
    expect(screen, contains("'date': date"));
    expect(screen, contains("'items': items"));
    expect(screen, contains("'active': _updateActive"));

    expect(screen, contains('Ativar modo de manutenção?'));
    expect(screen, contains('Salvar novidades do app?'));
    expect(screen, contains('Alterações críticas exigem Master.'));

    expect(screen, contains('widget.currentAdmin.isMaster'));

    expect(
      screen,
      isNot(
        contains(
          "case _AdminSection.settings:\n"
          "        return _LegacyBridge(",
        ),
      ),
    );

    expect(
      screen,
      contains('Configurações não lê nem exibe chaves de provedor.'),
    );

    expect(screen, contains('ADMIN_V2_DASHBOARD_REAL_USERS_REST_V3'));
    expect(screen, contains('ADMIN_V2_BILLING_FOUNDATION_V1'));
    expect(screen, contains('ADMIN_V2_USERS_MIGRATION_V1'));
    expect(screen, contains('ADMIN_V2_AI_COSTS_MIGRATION_V1'));
    expect(screen, contains('ADMIN_V2_ERRORS_HEALTH_CENTER_V1'));
    expect(screen, contains('ADMIN_V2_CONTENT_CANONICAL_CMS_V2'));
    expect(screen, contains('ADMIN_V2_COMMUNICATION_MIGRATION_V1'));
  });

  test('final audit log and alerts are native and server-side', () {
    final screen =
        File('lib/screens/admin_v2/admin_v2_screen.dart').readAsStringSync();

    expect(screen, contains('ADMIN_V2_FINAL_AUDIT_ALERTS_V1'));
    expect(screen, contains('_AdminSection.audit'));
    expect(screen, contains("'Auditoria'"));
    expect(screen, contains('class _AuditAlertsSection'));
    expect(screen, contains("'admin_audit_logs'"));

    expect(screen, contains('setAuditActor('));
    expect(screen, contains("'_adminAuditBy'"));
    expect(screen, contains("'_adminAuditEmail'"));
    expect(screen, contains("'_adminAuditAt'"));

    expect(screen, contains("'admin_incidents'"));
    expect(screen, contains("'admin_notifications'"));
    expect(screen, contains("'global_push_campaigns'"));
    expect(screen, contains("'email_campaigns'"));
    expect(screen, contains("'app_config/maintenance'"));

    expect(screen, contains('SERVER-SIDE · IMUTÁVEL'));
    expect(screen, contains('O browser possui leitura, nunca escrita.'));
    expect(screen, contains('sem nova collection de alerts.'));

    expect(screen, contains('ADMIN_V2_COMMUNICATION_MIGRATION_V1'));
    expect(screen, contains('ADMIN_V2_SETTINGS_MIGRATION_V1'));
  });

  test('AI costs V2 exposes GPT and Gemini operational telemetry', () {
    final screen =
        File('lib/screens/admin_v2/admin_v2_screen.dart').readAsStringSync();

    expect(screen, contains('ADMIN_V2_AI_COSTS_V2'));
    expect(screen, contains('OpenAI / GPT'));
    expect(screen, contains('Gemini'));
    expect(screen, contains('Código de liberação GPT'));
    expect(screen, contains('adminSetGptOperationalState'));
    expect(screen, contains("loadDocument('app_config/ai_control')"));
    expect(screen, contains("loadDocument('admin_ai_metrics/realtime')"));

    expect(screen, contains('Chamadas 24h'));
    expect(screen, contains('Tokens 24h'));
    expect(screen, contains('Tokens entrada'));
    expect(screen, contains('Tokens saída'));
    expect(screen, contains('Custo hoje'));
    expect(screen, contains('Custo mês'));
    expect(screen, contains('Erros 24h'));
    expect(screen, contains('Latência média'));

    expect(
      screen,
      contains('O código nunca é salvo ou retornado ao navegador.'),
    );
    expect(
      screen,
      contains('Nenhuma chave de provedor é carregada'),
    );

    expect(screen, contains('ADMIN_V2_FINAL_AUDIT_ALERTS_V1'));
    expect(screen, contains('ADMIN_V2_COMMUNICATION_MIGRATION_V1'));
    expect(screen, contains('ADMIN_V2_SETTINGS_MIGRATION_V1'));
  });

  test('legacy admin remains untouched and reachable from admin v2', () {
    final legacy = File('lib/screens/admin_screen.dart').readAsStringSync();
    final screen =
        File('lib/screens/admin_v2/admin_v2_screen.dart').readAsStringSync();

    expect(legacy, contains('class AdminScreen'));
    expect(screen, contains('../admin_screen.dart'));
    expect(screen, contains('Operações atuais'));
  });
}
