import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/prompt_composer.dart';

Widget _buildComposer({
  required TextEditingController controller,
  required FocusNode focusNode,
  bool dark = false,
  bool thinking = false,
  bool connected = true,
  bool listening = false,
  double soundLevel = 0,
  String lang = 'pt',
  VoidCallback? onSend,
  VoidCallback? onCancel,
  VoidCallback? onVoice,
  VoidCallback? onConnect,
}) {
  return MaterialApp(
    home: Scaffold(
      body: PromptComposer(
        ctrl: controller,
        focusNode: focusNode,
        dark: dark,
        hasFocus: focusNode.hasFocus,
        thinking: thinking,
        onSend: onSend ?? () {},
        onCancel: onCancel,
        onVoice: onVoice ?? () {},
        sttListening: listening,
        sttSoundLevel: soundLevel,
        hint: 'Pesquisar...',
        lang: lang,
        isConnected: connected,
        onConnectTap: onConnect,
      ),
    ),
  );
}

void main() {
  testWidgets('bloqueia o campo quando a IA está desconectada', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    var connectCalls = 0;

    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _buildComposer(
        controller: controller,
        focusNode: focusNode,
        connected: false,
        onConnect: () => connectCalls++,
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));

    expect(field.enabled, isFalse);
    expect(field.readOnly, isTrue);
    expect(find.text('Conecte a IA para escrever'), findsOneWidget);

    await tester.tap(find.byType(PromptComposer));
    await tester.pump();

    expect(connectCalls, 1);
  });

  testWidgets('envia pelo botão quando não existe streaming', (tester) async {
    final controller = TextEditingController(text: 'Paciente com dor torácica');
    final focusNode = FocusNode();
    var sendCalls = 0;

    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _buildComposer(
        controller: controller,
        focusNode: focusNode,
        onSend: () => sendCalls++,
      ),
    );

    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();

    expect(sendCalls, 1);
  });

  testWidgets('exibe cancelar durante streaming e chama onCancel',
      (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    var cancelCalls = 0;
    var sendCalls = 0;

    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _buildComposer(
        controller: controller,
        focusNode: focusNode,
        thinking: true,
        onSend: () => sendCalls++,
        onCancel: () => cancelCalls++,
      ),
    );

    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);

    await tester.tap(find.byIcon(Icons.stop_rounded));
    await tester.pump();

    expect(cancelCalls, 1);
    expect(sendCalls, 0);
  });

  testWidgets('renderiza estado ativo do ditado em espanhol', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();

    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _buildComposer(
        controller: controller,
        focusNode: focusNode,
        listening: true,
        soundLevel: 0.8,
        lang: 'es',
      ),
    );

    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Escuchando…'), findsOneWidget);
    expect(find.byIcon(Icons.mic_off_outlined), findsOneWidget);
  });

  testWidgets('Enter envia e Shift+Enter não dispara envio', (tester) async {
    final controller = TextEditingController(text: 'Hipercalemia');
    final focusNode = FocusNode();
    var sendCalls = 0;

    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _buildComposer(
        controller: controller,
        focusNode: focusNode,
        onSend: () => sendCalls++,
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(sendCalls, 1);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(sendCalls, 1);
  });
}
