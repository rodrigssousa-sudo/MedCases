// MEDCASES_SUPPORT_TICKET_SERVICE_V2_B_R1
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class SupportTicketRecord {
  const SupportTicketRecord({
    required this.ticketId,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.category,
    required this.categoryLabel,
    required this.rating,
    required this.message,
    required this.locale,
    required this.status,
    required this.priority,
    required this.platform,
    required this.createdAt,
    required this.updatedAt,
    required this.assignedToEmail,
    required this.adminReply,
    required this.adminReplyAt,
  });

  final String ticketId;
  final String userId;
  final String userEmail;
  final String userName;
  final String category;
  final String categoryLabel;
  final int rating;
  final String message;
  final String locale;
  final String status;
  final String priority;
  final String platform;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String assignedToEmail;
  final String adminReply;
  final DateTime? adminReplyAt;

  factory SupportTicketRecord.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};

    String text(String key) => (data[key] ?? '').toString();

    DateTime? date(Object? value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    return SupportTicketRecord(
      ticketId: text('ticketId').isEmpty ? doc.id : text('ticketId'),
      userId: text('userId'),
      userEmail: text('userEmail'),
      userName: text('userName'),
      category: text('category'),
      categoryLabel: text('categoryLabel'),
      rating: data['rating'] is num ? (data['rating'] as num).toInt() : 0,
      message: text('message'),
      locale: text('locale'),
      status: text('status').isEmpty ? 'new' : text('status'),
      priority: text('priority').isEmpty ? 'normal' : text('priority'),
      platform: text('platform'),
      createdAt: date(data['createdAt']),
      updatedAt: date(data['updatedAt']),
      assignedToEmail: text('assignedToEmail'),
      adminReply: text('adminReply'),
      adminReplyAt: date(data['adminReplyAt']),
    );
  }
}

class SupportTicketService {
  SupportTicketService._();

  static const collectionName = 'support_tickets';
  static const sourceModule = 'settings_support';
  static const privacyNoticeVersion = 'support-privacy-v1';

  static CollectionReference<Map<String, dynamic>> get _tickets =>
      FirebaseFirestore.instance.collection(collectionName);

  static String _platform() {
    if (kIsWeb) return 'web';

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  static String _newTicketId() {
    final now = DateTime.now().toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    final date = '${now.year}${two(now.month)}${two(now.day)}';
    final entropy = now.microsecondsSinceEpoch.toRadixString(36).toUpperCase();
    final tail =
        entropy.length <= 7 ? entropy : entropy.substring(entropy.length - 7);
    return 'MC-$date-$tail';
  }

  static Future<String> createTicket({
    required String userId,
    required String userEmail,
    required String userName,
    required String category,
    required String categoryLabel,
    required int rating,
    required String message,
    required String locale,
  }) async {
    final uid = userId.trim();
    final body = message.trim();

    if (uid.isEmpty) {
      throw ArgumentError('support_ticket_user_required');
    }
    if (body.isEmpty || body.length > 500) {
      throw ArgumentError('support_ticket_message_invalid');
    }
    if (rating < 0 || rating > 5) {
      throw ArgumentError('support_ticket_rating_invalid');
    }

    final ticketId = _newTicketId();

    await _tickets.doc(ticketId).set(<String, dynamic>{
      'ticketId': ticketId,
      'userId': uid,
      'userEmail': userEmail.trim(),
      'userName': userName.trim(),
      'category': category.trim(),
      'categoryLabel': categoryLabel.trim(),
      'rating': rating,
      'message': body,
      'locale': locale == 'es' ? 'es' : 'pt',
      'status': 'new',
      'priority': 'normal',
      'platform': _platform(),
      'sourceModule': sourceModule,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'assignedTo': '',
      'assignedToEmail': '',
      'adminReply': '',
      'adminReplyAt': null,
      'privacyNoticeVersion': privacyNoticeVersion,
    });

    return ticketId;
  }

  static Stream<List<SupportTicketRecord>> watchUserTickets(String userId) {
    final uid = userId.trim();
    if (uid.isEmpty) {
      return const Stream<List<SupportTicketRecord>>.empty();
    }

    return _tickets.where('userId', isEqualTo: uid).snapshots().map((snapshot) {
      final rows = snapshot.docs
          .map(SupportTicketRecord.fromDoc)
          .toList(growable: false);
      rows.sort((a, b) {
        final left = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final right = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return right.compareTo(left);
      });
      return rows;
    });
  }

  static Stream<List<SupportTicketRecord>> watchAllTickets() {
    return _tickets.limit(300).snapshots().map((snapshot) {
      final rows = snapshot.docs
          .map(SupportTicketRecord.fromDoc)
          .toList(growable: false);
      rows.sort((a, b) {
        final left = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final right = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return right.compareTo(left);
      });
      return rows;
    });
  }

  static Future<void> updateTicket({
    required String ticketId,
    required String status,
    required String priority,
    required String assignedTo,
    required String assignedToEmail,
    required String adminReply,
    required String adminActorUid,
    required String adminActorEmail,
  }) async {
    final id = ticketId.trim();
    if (id.isEmpty) throw ArgumentError('support_ticket_id_required');

    final reply = adminReply.trim();

    await _tickets.doc(id).update(<String, dynamic>{
      'status': status,
      'priority': priority,
      'assignedTo': assignedTo.trim(),
      'assignedToEmail': assignedToEmail.trim(),
      'adminReply': reply,
      'adminReplyAt': reply.isEmpty ? null : FieldValue.serverTimestamp(),
      'lastAdminActorUid': adminActorUid.trim(),
      'lastAdminActorEmail': adminActorEmail.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
