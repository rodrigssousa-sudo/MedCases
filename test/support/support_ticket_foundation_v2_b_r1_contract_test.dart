import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classBlock(String source, String className) {
  final marker = 'class $className ';
  final start = source.indexOf(marker);
  expect(start, greaterThanOrEqualTo(0), reason: className);

  final open = source.indexOf('{', start);
  expect(open, greaterThan(start), reason: '$className opening');

  var depth = 0;
  var quote = '';
  var escaped = false;
  var lineComment = false;
  var blockComment = false;

  for (var i = open; i < source.length; i++) {
    final ch = source[i];
    final nx = i + 1 < source.length ? source[i + 1] : '';

    if (lineComment) {
      if (ch == '\n') lineComment = false;
      continue;
    }

    if (blockComment) {
      if (ch == '*' && nx == '/') {
        blockComment = false;
        i++;
      }
      continue;
    }

    if (quote.isNotEmpty) {
      if (escaped) {
        escaped = false;
      } else if (ch == r'\') {
        escaped = true;
      } else if (ch == quote) {
        quote = '';
      }
      continue;
    }

    if (ch == '/' && nx == '/') {
      lineComment = true;
      i++;
      continue;
    }

    if (ch == '/' && nx == '*') {
      blockComment = true;
      i++;
      continue;
    }

    if (ch == "'" || ch == '"') {
      quote = ch;
      continue;
    }

    if (ch == '{') depth++;
    if (ch == '}') {
      depth--;
      if (depth == 0) return source.substring(start, i + 1);
    }
  }

  throw StateError('Unbalanced $className');
}

void main() {
  test('app support owner is native ticket UI instead of email-first', () {
    final main = File('lib/main.dart').readAsStringSync();

    expect(
      main,
      contains('MEDCASES_SUPPORT_TICKET_FOUNDATION_V2_B_R1'),
    );
    expect(
      main,
      contains("import 'screens/support_ticket_screen.dart';"),
    );

    final owner = classBlock(main, '_FeedbackSheet');
    expect(owner, contains('SupportTicketScreen('));
    expect(owner, isNot(contains('mailto:')));
    expect(owner, isNot(contains('_destEmail')));
    expect(owner, isNot(contains('Abrir correo para enviar')));
  });

  test('user support surface is PT ES and privacy-safe by default', () {
    final ui =
        File('lib/screens/support_ticket_screen.dart').readAsStringSync();

    for (final token in <String>[
      'MEDCASES_SUPPORT_TICKET_USER_UI_V2_B_R1',
      'Feedback y Soporte',
      'Feedback e Suporte',
      'Enviar al soporte',
      'Enviar ao suporte',
      'Mis solicitudes',
      'Minhas solicitações',
      'Privacidad:',
      'Privacidade:',
      'SupportTicketService.createTicket(',
      'SupportTicketService.watchUserTickets(uid)',
    ]) {
      expect(ui, contains(token), reason: token);
    }
  });

  test('Firestore ticket service has no automatic clinical payload', () {
    final service =
        File('lib/services/support_ticket_service.dart').readAsStringSync();

    for (final token in <String>[
      "collectionName = 'support_tickets'",
      "sourceModule = 'settings_support'",
      "privacyNoticeVersion = 'support-privacy-v1'",
      "'status': 'new'",
      "'priority': 'normal'",
      'watchUserTickets(String userId)',
      'watchAllTickets()',
      'updateTicket({',
    ]) {
      expect(service, contains(token), reason: token);
    }

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

  test('Admin V2 exposes support and Supervisor remains read-only', () {
    final admin =
        File('lib/screens/admin_v2/admin_v2_screen.dart').readAsStringSync();
    final adminUi = File('lib/screens/admin_v2/support_admin_section.dart')
        .readAsStringSync();

    for (final token in <String>[
      'ADMIN_V2_SUPPORT_TICKET_FOUNDATION_V2_B_R1',
      '_AdminSection.support',
      "Icons.support_agent_outlined, 'Suporte'",
      'SupportAdminSection(',
      'item.\$1 == _AdminSection.support',
    ]) {
      expect(admin, contains(token), reason: token);
    }

    for (final token in <String>[
      'ADMIN_V2_SUPPORT_TICKET_CENTER_V2_B_R1',
      'SupportTicketService.watchAllTickets()',
      'SupportTicketService.updateTicket(',
      'bool get _canMutate => widget.currentAdmin.isAdmin;',
      'SUPERVISOR · SOMENTE LEITURA',
    ]) {
      expect(adminUi, contains(token), reason: token);
    }
  });

  test('Firestore rules enforce ownership and admin triage roles', () {
    final rules = File('firestore.rules').readAsStringSync();

    for (final token in <String>[
      'MEDCASES_SUPPORT_TICKET_RULES_V2_B_R1',
      'match /support_tickets/{ticketId}',
      'request.resource.data.userId == request.auth.uid',
      "request.resource.data.status == 'new'",
      "request.resource.data.priority == 'normal'",
      'request.resource.data.message.size() <= 500',
      'isAdmin() || isSupervisor()',
      'allow update: if isAdmin();',
      'allow delete: if isMaster();',
    ]) {
      expect(rules, contains(token), reason: token);
    }
  });
}
