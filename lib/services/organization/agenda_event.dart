import 'package:cloud_firestore/cloud_firestore.dart';

class AgendaEvent {
  const AgendaEvent(
      {required this.id,
      required this.userId,
      required this.title,
      required this.category,
      required this.startAt,
      this.endAt,
      this.notes = '',
      this.reminderMinutes,
      this.recurrence = 'none',
      this.status = 'active',
      this.deviceCalendarLinked = false,
      this.deviceCalendarEventId});
  static const categories = [
    'guardia',
    'estudio',
    'clase',
    'consulta',
    'personal',
    'otro'
  ];
  static const recurrences = ['none', 'daily', 'weekly', 'monthly'];
  static const reminders = [0, 5, 10, 15, 30, 60, 1440];
  final String id, userId, title, category, notes, recurrence, status;
  final DateTime startAt;
  final DateTime? endAt;
  final int? reminderMinutes;
  final bool deviceCalendarLinked;
  final String? deviceCalendarEventId;
  void validate() {
    if (id.isEmpty ||
        userId.isEmpty ||
        title.trim().isEmpty ||
        title.length > 160 ||
        notes.length > 5000 ||
        !categories.contains(category) ||
        !recurrences.contains(recurrence) ||
        !['active', 'archived'].contains(status) ||
        (endAt != null && endAt!.isBefore(startAt)) ||
        (reminderMinutes != null && !reminders.contains(reminderMinutes))) {
      throw const FormatException('INVALID_AGENDA_EVENT');
    }
  }

  Map<String, dynamic> toFirestore() {
    validate();
    return {
      'id': id,
      'userId': userId,
      'title': title.trim(),
      'category': category,
      'startAt': Timestamp.fromDate(startAt.toUtc()),
      'endAt': endAt == null ? null : Timestamp.fromDate(endAt!.toUtc()),
      'notes': notes,
      'reminderMinutes': reminderMinutes,
      'recurrence': recurrence,
      'status': status,
      'deviceCalendarLinked': deviceCalendarLinked,
      'deviceCalendarEventId': deviceCalendarEventId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory AgendaEvent.fromFirestore(Map<String, dynamic> j) {
    final event = AgendaEvent(
        id: j['id'] as String,
        userId: j['userId'] as String,
        title: j['title'] as String,
        category: j['category'] as String,
        startAt: (j['startAt'] as Timestamp).toDate().toUtc(),
        endAt: (j['endAt'] as Timestamp?)?.toDate().toUtc(),
        notes: j['notes'] as String? ?? '',
        reminderMinutes: j['reminderMinutes'] as int?,
        recurrence: j['recurrence'] as String? ?? 'none',
        status: j['status'] as String? ?? 'active',
        deviceCalendarLinked: j['deviceCalendarLinked'] as bool? ?? false,
        deviceCalendarEventId: j['deviceCalendarEventId'] as String?);
    event.validate();
    return event;
  }
  List<DateTime> occurrences(DateTime from, DateTime until) {
    final anchor = startAt.toLocal();
    if (recurrence == 'none') {
      return startAt.isBefore(from) || !startAt.isBefore(until)
          ? []
          : [startAt.toLocal()];
    }
    final result = <DateTime>[];
    // Calendar components preserve wall-clock time across DST transitions.
    var day = DateTime(from.year, from.month, from.day);
    while (day.isBefore(until)) {
      final occurrence = DateTime(day.year, day.month, day.day, anchor.hour,
          anchor.minute, anchor.second);
      final matches = recurrence == 'daily' ||
          (recurrence == 'weekly' && day.weekday == anchor.weekday) ||
          (recurrence == 'monthly' && day.day == anchor.day);
      if (matches &&
          !occurrence.isBefore(startAt) &&
          !occurrence.isBefore(from) &&
          occurrence.isBefore(until)) {
        result.add(occurrence);
      }
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return result;
  }
}
