import 'dart:io';

void main() {
  final rules = File('firestore.rules').readAsStringSync();

  for (final token in <String>[
    'ADMIN_V2_403_METRICS_RULES_CLOSURE_V1',
    'match /admin_metrics/{document=**}',
    'match /admin_error_metrics/{document=**}',
    'match /admin_billing_metrics/{document=**}',
    'match /admin_ai_metrics/{document=**}',
  ]) {
    if (!rules.contains(token)) {
      throw StateError('Missing rules token: $token');
    }
  }

  final adminMetrics = RegExp(
    r'match /admin_metrics/\{document=\*\*\} \{[\s\S]*?'
    r'allow read: if isAdmin\(\);[\s\S]*?'
    r'allow create, update, delete: if false;[\s\S]*?\}',
  );

  final errorMetrics = RegExp(
    r'match /admin_error_metrics/\{document=\*\*\} \{[\s\S]*?'
    r'allow read: if isAdmin\(\);[\s\S]*?'
    r'allow create, update, delete: if false;[\s\S]*?\}',
  );

  final billingMetrics = RegExp(
    r'match /admin_billing_metrics/\{document=\*\*\} \{[\s\S]*?'
    r'allow read: if isMaster\(\);[\s\S]*?'
    r'allow create, update, delete: if false;[\s\S]*?\}',
  );

  if (!adminMetrics.hasMatch(rules)) {
    throw StateError('admin_metrics contract failed');
  }
  if (!errorMetrics.hasMatch(rules)) {
    throw StateError('admin_error_metrics contract failed');
  }
  if (!billingMetrics.hasMatch(rules)) {
    throw StateError('admin_billing_metrics contract failed');
  }

  print('ADMIN_V2_403_METRICS_RULES_CLOSURE_V1_CONTRACT=PASS');
  print('ADMIN_METRICS_READ=ADMIN_OR_MASTER');
  print('ADMIN_ERROR_METRICS_READ=ADMIN_OR_MASTER');
  print('ADMIN_BILLING_METRICS_READ=MASTER_ONLY');
  print('CLIENT_WRITE_ALL_THREE=DENIED');
}
