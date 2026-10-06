/// Generic lock-screen copy only. Clinical text must never enter this contract.
enum NotificationEvent {
  transcriptionCompleted, consultationSummaryReady, analysisCompleted,
  contentProcessed, importantAppAlert, newFeatureAvailable,
  globalEngagementReminder, timerCompleted,
}

class NotificationContract {
  static int? featureTab(String id) => const {'tools':4,'guides':5,'study':10}[id];
  static const wireNames = [
    'TRANSCRIPTION_COMPLETED', 'CONSULTATION_SUMMARY_READY', 'ANALYSIS_COMPLETED',
    'CONTENT_PROCESSED', 'IMPORTANT_APP_ALERT', 'NEW_FEATURE_AVAILABLE',
    'GLOBAL_ENGAGEMENT_REMINDER', 'TIMER_COMPLETED',
  ];
  static const pt = ['Sua transcrição foi concluída',
    'Seu resumo da consulta está pronto', 'Sua análise foi concluída',
    'Seu conteúdo foi processado', 'Há um aviso importante no MedCases',
    'Tem novidade no MedCases', 'Como o MedCases pode te ajudar hoje?', 'Timer concluído'];
  static const es = ['Tu transcripción está lista',
    'El resumen de tu consulta está listo', 'Tu análisis está listo',
    'Tu contenido está listo', 'Hay un aviso importante en MedCases',
    'Hay novedades en MedCases', '¿Cómo puede ayudarte MedCases hoy?', 'Temporizador finalizado'];
  static String locale(String value) => value.toLowerCase().startsWith('es') ? 'es' : 'pt';
  static String title(NotificationEvent event, String lang) =>
      (locale(lang) == 'es' ? es : pt)[event.index];
  static String route(NotificationEvent event, String id) {
    final paths = ['transcription', 'summary', 'analysis', 'content',
      'alerts', 'features', 'home', 'timer'];
    return 'medcases://${paths[event.index]}/${Uri.encodeComponent(id)}';
  }
}

class NotificationDestination {
  const NotificationDestination(this.event, this.resourceId, this.notificationId);
  final NotificationEvent event;
  final String resourceId, notificationId;
  static NotificationDestination? parse(Map<String, dynamic> data) {
    final index = NotificationContract.wireNames.indexOf(data['eventType'] as String? ?? '');
    final id = data['resourceId'], notificationId = data['notificationId'];
    if (index < 0 || id is! String || notificationId is! String ||
        id.isEmpty || id.length > 180 || notificationId.isEmpty ||
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id)) return null;
    final event = NotificationEvent.values[index];
    if (data['deepLink'] != NotificationContract.route(event, id)) return null;
    return NotificationDestination(event, id, notificationId);
  }
}

class NotificationPreferences {
  const NotificationPreferences({this.productUpdates = true, this.marketingEngagement = true,
    this.reminders = true, this.quietStart = 21, this.quietEnd = 8});
  final bool productUpdates, marketingEngagement, reminders;
  final int quietStart, quietEnd;
  Map<String, dynamic> toJson() => {'productUpdates': productUpdates,
    'marketingEngagement': marketingEngagement, 'reminders': reminders,
    'quietStart': quietStart, 'quietEnd': quietEnd};
}
