import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

// Phase 2 supersedes legacy direct-REST mutation routing. Behavioral coverage
// lives in admin_operations_section_test and the Firestore concurrency suite.
void main() {
  final source = File('lib/screens/admin_v2/admin_v2_screen.dart').readAsStringSync();
  final runtime = source.substring(source.indexOf('  Widget _buildSection()'), source.indexOf('class _AdminSidebar'));
  test('users and entitlement use metadata callable without billing writes', () {
    expect(runtime, contains("table: 'users'"));
    expect(runtime, contains('Assinaturas & Planos'));
    expect(runtime, isNot(contains('return _UsersManagementSection(')));
    expect(runtime, isNot(contains('return _SubscriptionsRevenueSection(')));
  });
  test('AI observability cannot change clinical routing', () {
    expect(runtime, contains("table: 'ai'"));
    expect(runtime, isNot(contains('return _AiCostsSection(')));
  });
  test('Supervisor receives read-only sections', () {
    expect(runtime, contains('readOnly: widget.currentAdmin.isSupervisor'));
    expect(source, contains('if (!admin.isAdmin && !admin.isSupervisor)'));
  });
  test('guides paginate and use reviewed bilingual editor', () {
    final guides = source.substring(source.indexOf('class _ContentGuidesSectionState'),source.indexOf('class _GuideData'));
    expect(guides, contains("'table': 'guides'"));
    expect(guides, contains("'limit': 30"));
    expect(guides, contains('AdminClinicalGuideEditorScreen('));
    expect(guides, isNot(contains('listCollection(')));
    expect(guides, isNot(contains('patchDocumentFields(')));
    expect(guides, isNot(contains('deleteDocument(')));
  });
  test('legacy campaign dispatcher is not a reachable phase2 route', () {
    expect(runtime, contains("table: 'campaigns'"));
    expect(runtime, isNot(contains('return _CommunicationSection(')));
  });
  test('new inventories, jobs, audit and health have distinct routes', () {
    expect(runtime, contains("kind: 'pathologies'"));
    expect(runtime, contains("kind: 'drugs'"));
    expect(runtime, contains('ContentInventorySection'));
    expect(runtime, contains('ContentInventoryOverview'));
    for (final table in ['jobs','audit','health','transcriptions','releases','deploys','notifications']) {
      expect(runtime, contains("table: '$table'"));
    }
  });
  test('manual time owner and server API are preserved', () {
    expect(runtime, contains('return ControlCenterSection('));
    expect(runtime, contains("table: 'credits'"));
    expect(runtime, contains("table: 'ledger'"));
  });
  test('configuration mutations use audited callable', () {
    final settings = source.substring(source.indexOf('class _SettingsSectionState'),source.indexOf('class _SettingsBundle'));
    expect(settings, contains("call('mutate', _configPending!)"));
    expect(settings, contains('REASON_REQUIRED'));
    expect(settings, isNot(contains('patchDocumentFields(')));
  });
}
