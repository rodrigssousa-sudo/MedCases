import 'package:flutter_test/flutter_test.dart';
import 'current_theme_runtime_harness.dart';

void main() {
  testWidgets(
      'real root theme propagation preserves route state', verifyRootTheme);
  testWidgets('real mobile branding and drawer preserve states',
      (t) => verifyShellTheme(t, desktop: false));
  testWidgets('real desktop sidebar selects current clinical route',
      (t) => verifyShellTheme(t, desktop: true));
  testWidgets(
      'real profile palette and validation callback', verifyProfileTheme);
}
