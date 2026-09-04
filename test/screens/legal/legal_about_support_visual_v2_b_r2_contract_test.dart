import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legal premium sheet preserves terms/privacy data and canonical tokens',
      () {
    final legal = File('lib/screens/legal_screen.dart').readAsStringSync();
    for (final token in <String>[
      'MEDCASES_LEGAL_ABOUT_SUPPORT_VISUAL_V2_B_R2',
      "import 'dart:ui';",
      'ImageFilter.blur(sigmaX: 16, sigmaY: 16)',
      'Color(0xFFECF0F4)',
      'Color(0xFFE2E7EC)',
      'Color(0xFF374151)',
      'Términos de Uso',
      'Termos de Uso',
      'Política de Privacidad',
      'Política de Privacidade',
      'DraggableScrollableSheet',
    ]) {
      expect(legal, contains(token), reason: token);
    }
    expect(legal, contains('return isEs ? _termsEs : _termsPt;'));
    expect(legal, contains('return isEs ? _privacyEs : _privacyPt;'));
  });

  test('about uses one MedCases identity and keeps institutional content', () {
    final main = File('lib/main.dart').readAsStringSync();
    final start = main.indexOf('class _AboutAppSheet extends StatelessWidget');
    expect(start, greaterThanOrEqualTo(0));
    final next = main.indexOf('\nclass ', start + 20);
    final owner =
        next > start ? main.substring(start, next) : main.substring(start);

    expect(
      main,
      contains('MEDCASES_LEGAL_ABOUT_SUPPORT_VISUAL_V2_B_R2'),
      reason: 'R2 marker is intentionally placed immediately before the owner',
    );

    for (final token in <String>[
      'Sobre MedCases Pro',
      'Sobre o MedCases Pro',
      'ImageFilter.blur(sigmaX: 16, sigmaY: 16)',
      'Color(0xFFECF0F4)',
      'Color(0xFFE2E7EC)',
      'Color(0xFF374151)',
      'medcasespro@gmail.com',
      'Comitê de Revisão Clínica MedCases Pro',
      'openAcademicSourceSecurely(',
      'promedcases.com',
    ]) {
      expect(owner, contains(token), reason: token);
    }
    expect(owner, isNot(contains('0xFF00E5FF')));
    expect(owner, isNot(contains('_kGold')));
    expect(owner, isNot(contains('withOpacity(')));
  });

  test('support keeps native ticket contract with refined visual tokens', () {
    final support =
        File('lib/screens/support_ticket_screen.dart').readAsStringSync();
    for (final token in <String>[
      'MEDCASES_SUPPORT_TICKET_USER_UI_V2_B_R1',
      'MEDCASES_LEGAL_ABOUT_SUPPORT_VISUAL_V2_B_R2',
      'SupportTicketService.createTicket(',
      'SupportTicketService.watchUserTickets(uid)',
      'Enviar al soporte',
      'Enviar ao suporte',
      'Mis solicitudes',
      'Minhas solicitações',
      'Privacidad:',
      'Privacidade:',
      'Color(0xFFECF0F4)',
      'Color(0xFFE2E7EC)',
      'Color(0xFF374151)',
    ]) {
      expect(support, contains(token), reason: token);
    }
    expect(support, isNot(contains('withOpacity(')));
    expect(support, isNot(contains('mailto:')));
  });

  test('Admin support preserves triage, adds critical metric and cleans API',
      () {
    final admin = File('lib/screens/admin_v2/support_admin_section.dart')
        .readAsStringSync();
    for (final token in <String>[
      'ADMIN_V2_SUPPORT_TICKET_CENTER_V2_B_R1',
      'MEDCASES_LEGAL_ABOUT_SUPPORT_VISUAL_V2_B_R2',
      'SupportTicketService.watchAllTickets()',
      'SupportTicketService.updateTicket(',
      'SUPERVISOR · SOMENTE LEITURA',
      "label: 'Críticos'",
      "ticket.priority == 'critical'",
      'Color(0xFFECF0F4)',
      'initialValue: _statusFilter',
      'initialValue: _editStatus ?? ticket.status',
      'initialValue: _editPriority ?? ticket.priority',
    ]) {
      expect(admin, contains(token), reason: token);
    }
  });

  test('visual R2 does not alter support persistence or patient privacy', () {
    final service =
        File('lib/services/support_ticket_service.dart').readAsStringSync();
    final rules = File('firestore.rules').readAsStringSync();
    expect(service, contains("collectionName = 'support_tickets'"));
    expect(service, contains("sourceModule = 'settings_support'"));
    expect(rules, contains('match /support_tickets/{ticketId}'));

    for (final forbidden in <String>[
      'chatHistory',
      'clinicalOutput',
      'patientName',
      'patientDocument',
      'audioTranscript',
      'medicalRecord',
      'promptHistory',
    ]) {
      expect(service, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}
