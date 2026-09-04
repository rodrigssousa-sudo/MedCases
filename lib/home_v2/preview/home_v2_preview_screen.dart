import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../screens/ai_screen.dart';

class HomeV2PreviewScreen extends StatefulWidget {
  const HomeV2PreviewScreen({
    required this.onNavigateToAi,
    super.key,
  });

  final ValueChanged<int> onNavigateToAi;

  @override
  State<HomeV2PreviewScreen> createState() => _HomeV2PreviewScreenState();
}

class _HomeV2PreviewScreenState extends State<HomeV2PreviewScreen> {
  bool _aiExpanded = false;

  String get _greeting {
    final hour = DateTime.now().hour;

    if (hour < 5) return 'Boa madrugada';
    if (hour < 12) return 'Bom dia';
    if (hour < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  void _openRealAi(String query) {
    final normalizedQuery = query.trim();

    if (normalizedQuery.isNotEmpty) {
      AiScreen.pendingHistory.value = [];
      AiScreen.pendingQuery.value = normalizedQuery;
    }

    widget.onNavigateToAi(2);
  }

  void _feedback(String module) {
    final messenger = ScaffoldMessenger.maybeOf(context);

    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _Palette.surfaceStrong,
        duration: const Duration(milliseconds: 750),
        content: Text(
          'Preview visual: $module',
          style: const TextStyle(
            color: _Palette.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: ColoredBox(
        color: _Palette.background,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final desktop = width >= 1100;
            final tablet = width >= 700 && width < 1100;

            final content = desktop
                ? _DesktopComposition(
                    greeting: _greeting,
                    aiExpanded: _aiExpanded,
                    guardiaExpanded: true,
                    onToggleAi: () {
                      setState(() => _aiExpanded = !_aiExpanded);
                    },
                    onToggleGuardia: () {},
                    onFeedback: _feedback,
                    onOpenRealAi: _openRealAi,
                  )
                : _MobileComposition(
                    greeting: _greeting,
                    aiExpanded: _aiExpanded,
                    guardiaExpanded: true,
                    onToggleAi: () {
                      setState(() => _aiExpanded = !_aiExpanded);
                    },
                    onToggleGuardia: () {},
                    onFeedback: _feedback,
                    onOpenRealAi: _openRealAi,
                  );

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                desktop ? 20 : 5,
                8,
                desktop ? 20 : 5,
                124,
              ),
              child: tablet
                  ? Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 860),
                        child: content,
                      ),
                    )
                  : content,
            );
          },
        ),
      ),
    );
  }
}

abstract final class _Palette {
  static const lightPreview = bool.fromEnvironment(
    'HOME_V2_LIGHT_PREVIEW',
    defaultValue: false,
  );

  static const background =
      lightPreview ? Color(0xFFF3F5F7) : Color(0xFF070D16);

  static const surface = lightPreview ? Color(0xFFFFFFFF) : Color(0xFF101C2C);

  static const surfaceSoft =
      lightPreview ? Color(0xFFF6F8FA) : Color(0xFF0B1522);

  static const surfaceStrong =
      lightPreview ? Color(0xFFF8FAFC) : Color(0xFF14243A);

  static const surfaceActive =
      lightPreview ? Color(0xFFF6F8FA) : Color(0xFF182A40);

  static const shortcutSurface =
      lightPreview ? Color(0xFFF8FAFC) : Color(0xFF14243A);

  // HOME V2: molduras apenas perceptíveis, sem efeito de grade rígida.
  static const border = lightPreview ? Color(0xFFE7EBEF) : Color(0xFF1B2B3E);

  static const divider = lightPreview ? Color(0xFFEEF1F4) : Color(0xFF162538);

  static const dividerStrong =
      lightPreview ? Color(0xFFE6EAEE) : Color(0xFF203247);

  static const borderActive =
      lightPreview ? Color(0xFFB8C3CD) : Color(0xFF385778);

  static const textPrimary =
      lightPreview ? Color(0xFF05070A) : Color(0xFFFFFFFF);

  static const textSecondary =
      lightPreview ? Color(0xFF59636E) : Color(0xFFFFFFFF);

  static const textMuted = lightPreview ? Color(0xFF8A939D) : Color(0xFFFFFFFF);

  static const accent = lightPreview ? Color(0xFF008F66) : Color(0xFF00C781);

  static const accentSoft =
      lightPreview ? Color(0xFFE5F4EE) : Color(0x1F00C781);

  // Identidade cromática dos módulos — fosca, sem neon ou glow.
  static const farmacosIcon =
      lightPreview ? Color(0xFF087F7B) : Color(0xFF61D2CB);

  static const farmacosSurface =
      lightPreview ? Color(0xFFEFF8F7) : Color(0xFF14243A);

  static const patientIcon =
      lightPreview ? Color(0xFF3478C7) : Color(0xFF82B7F2);

  static const patientSurface =
      lightPreview ? Color(0xFFEFF5FC) : Color(0xFF14243A);

  static const pediatricsIcon =
      lightPreview ? Color(0xFFC58A1A) : Color(0xFFE7B957);

  static const pediatricsSurface =
      lightPreview ? Color(0xFFFFF8E9) : Color(0xFF14243A);

  static const toolsIcon = lightPreview ? Color(0xFF465568) : Color(0xFFB2C0D0);

  static const toolsSurface =
      lightPreview ? Color(0xFFF1F4F7) : Color(0xFF14243A);

  static const historyIcon =
      lightPreview ? Color(0xFF0F766E) : Color(0xFF70D3C9);

  static const historySurface =
      lightPreview ? Color(0xFFEDF8F6) : Color(0xFF14243A);

  static const assessmentIcon =
      lightPreview ? Color(0xFF16845B) : Color(0xFF7DDDB5);

  static const assessmentSurface =
      lightPreview ? Color(0xFFEDF8F2) : Color(0xFF14243A);

  static const notesIcon = lightPreview ? Color(0xFF7659B8) : Color(0xFFC0ADF0);

  static const notesSurface =
      lightPreview ? Color(0xFFF4F0FB) : Color(0xFF14243A);

  static const timerIcon = lightPreview ? Color(0xFFC64A4A) : Color(0xFFF49A9A);

  static const timerSurface =
      lightPreview ? Color(0xFFFDF0F0) : Color(0xFF14243A);

  static const shiftIcon = lightPreview ? Color(0xFF087A55) : Color(0xFF73D5AA);

  static const shiftSurface =
      lightPreview ? Color(0xFFEDF8F3) : Color(0xFF101C2C);

  static const cardioIcon =
      lightPreview ? Color(0xFFC64A52) : Color(0xFFF4999F);

  static const cardioSurface =
      lightPreview ? Color(0xFFFDF0F1) : Color(0xFF3B2028);

  static const nephroIcon =
      lightPreview ? Color(0xFF267EAE) : Color(0xFF84C8EE);

  static const nephroSurface =
      lightPreview ? Color(0xFFEDF6FB) : Color(0xFF183149);

  static const hepatoIcon =
      lightPreview ? Color(0xFFC97828) : Color(0xFFF4BB76);

  static const hepatoSurface =
      lightPreview ? Color(0xFFFFF4E9) : Color(0xFF382817);

  static const pressedOverlayColor =
      lightPreview ? Color(0x1459636E) : Color(0x40243C5A);

  static final WidgetStateProperty<Color?> pressedOverlay =
      WidgetStateProperty.resolveWith<Color?>(
    (states) {
      if (states.contains(WidgetState.pressed)) {
        return pressedOverlayColor;
      }

      return Colors.transparent;
    },
  );
}

class _MobileComposition extends StatelessWidget {
  const _MobileComposition({
    required this.greeting,
    required this.aiExpanded,
    required this.guardiaExpanded,
    required this.onToggleAi,
    required this.onToggleGuardia,
    required this.onFeedback,
    required this.onOpenRealAi,
  });

  final String greeting;
  final bool aiExpanded;
  final bool guardiaExpanded;
  final VoidCallback onToggleAi;
  final VoidCallback onToggleGuardia;
  final ValueChanged<String> onFeedback;
  final ValueChanged<String> onOpenRealAi;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AiWorkspace(
          greeting: greeting,
          expanded: aiExpanded,
          onToggle: onToggleAi,
          onFeedback: onFeedback,
          onOpenRealAi: onOpenRealAi,
        ),
        const SizedBox(height: 7),
        _PrimaryClinicalCluster(onFeedback: onFeedback),
        const SizedBox(height: 7),
        _UtilityModules(onFeedback: onFeedback),
        const SizedBox(height: 4),
        _GuardiaWorkspace(
          expanded: guardiaExpanded,
          onToggle: onToggleGuardia,
          onFeedback: onFeedback,
        ),
      ],
    );
  }
}

class _DesktopComposition extends StatelessWidget {
  const _DesktopComposition({
    required this.greeting,
    required this.aiExpanded,
    required this.guardiaExpanded,
    required this.onToggleAi,
    required this.onToggleGuardia,
    required this.onFeedback,
    required this.onOpenRealAi,
  });

  final String greeting;
  final bool aiExpanded;
  final bool guardiaExpanded;
  final VoidCallback onToggleAi;
  final VoidCallback onToggleGuardia;
  final ValueChanged<String> onFeedback;
  final ValueChanged<String> onOpenRealAi;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 64,
              child: Column(
                children: [
                  _AiWorkspace(
                    greeting: greeting,
                    expanded: aiExpanded,
                    onToggle: onToggleAi,
                    onFeedback: onFeedback,
                    onOpenRealAi: onOpenRealAi,
                  ),
                  const SizedBox(height: 4),
                  _GuardiaWorkspace(
                    expanded: guardiaExpanded,
                    onToggle: onToggleGuardia,
                    onFeedback: onFeedback,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 36,
              child: Column(
                children: [
                  _PrimaryModuleButton(onFeedback: onFeedback),
                  const SizedBox(height: 4),
                  _ClinicalModules(onFeedback: onFeedback),
                  const SizedBox(height: 4),
                  _UtilityModules(onFeedback: onFeedback),
                  const SizedBox(height: 4),
                  const _DesktopStatusPanel(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiWorkspace extends StatelessWidget {
  const _AiWorkspace({
    required this.greeting,
    required this.expanded,
    required this.onToggle,
    required this.onFeedback,
    required this.onOpenRealAi,
  });

  final String greeting;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<String> onFeedback;
  final ValueChanged<String> onOpenRealAi;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      highlighted: expanded,
      radius: 6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 19, 12, 14),
            child: Row(
              children: [
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    overlayColor: _Palette.pressedOverlay,
                    splashFactory: NoSplash.splashFactory,
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onOpenRealAi(''),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 3,
                      ),
                      child: _HeaderBadge(
                        icon: Icon(
                          Icons.psychology_alt_outlined,
                          size: 15,
                          color: _Palette.accent,
                        ),
                        label: 'MEDCASES IA',
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    overlayColor: _Palette.pressedOverlay,
                    splashFactory: NoSplash.splashFactory,
                    customBorder: const CircleBorder(),
                    onTap: onToggle,
                    child: SizedBox.square(
                      dimension: 38,
                      child: Icon(
                        expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 25,
                        color: _Palette.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            height: expanded ? 72 : 126,
            padding: const EdgeInsets.fromLTRB(17, 0, 17, 18),
            alignment: expanded ? Alignment.topLeft : Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: expanded
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                RichText(
                  textAlign: expanded ? TextAlign.left : TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 22,
                      height: 1.05,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                    ),
                    children: [
                      TextSpan(
                        text: '$greeting, ',
                        style: const TextStyle(
                          color: _Palette.accent,
                        ),
                      ),
                      const TextSpan(
                        text: 'Bruno',
                        style: TextStyle(
                          color: _Palette.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Descreva o caso ou a dúvida clínica.',
                  textAlign: expanded ? TextAlign.left : TextAlign.center,
                  style: const TextStyle(
                    color: _Palette.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(13, 0, 13, 12),
                    child: _MockConversation(
                      onContinue: () => onOpenRealAi(''),
                    ),
                  )
                : const SizedBox(height: 22),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 0, 13, 16),
            child: Align(
              alignment: Alignment.center,
              child: FractionallySizedBox(
                widthFactor: 0.88,
                child: _MessageComposer(
                  expanded: expanded,
                  onOpen: onToggle,
                  onSend: onOpenRealAi,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockConversation extends StatefulWidget {
  const _MockConversation({
    required this.onContinue,
  });

  final VoidCallback onContinue;

  @override
  State<_MockConversation> createState() => _MockConversationState();
}

class _MockConversationState extends State<_MockConversation> {
  static const _fullResponse =
      'Em fibrilação atrial não valvar, com clearance de creatinina de '
      '32 mL/min, a dose habitual da apixabana permanece 5 mg por via oral '
      'a cada 12 horas.\n\n'
      'A redução para 2,5 mg a cada 12 horas deve ser considerada quando '
      'o paciente apresenta pelo menos dois dos seguintes critérios:\n\n'
      '• idade igual ou superior a 80 anos;\n'
      '• peso corporal igual ou inferior a 60 kg;\n'
      '• creatinina sérica igual ou superior a 1,5 mg/dL.\n\n'
      'Também é necessário avaliar risco hemorrágico, interações '
      'medicamentosas, indicação clínica e protocolo institucional.';

  Timer? _streamTimer;
  Timer? _cursorTimer;

  int _visibleCharacters = 0;
  bool _cursorVisible = true;

  String get _visibleResponse {
    return _fullResponse.substring(0, _visibleCharacters);
  }

  bool get _isStreaming {
    return _visibleCharacters < _fullResponse.length;
  }

  @override
  void initState() {
    super.initState();
    _startStreaming();
  }

  void _startStreaming() {
    _streamTimer = Timer.periodic(
      const Duration(milliseconds: 12),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_visibleCharacters >= _fullResponse.length) {
          timer.cancel();
          setState(() => _cursorVisible = false);
          return;
        }

        setState(() {
          _visibleCharacters = (_visibleCharacters + 2).clamp(
            0,
            _fullResponse.length,
          );
        });
      },
    );

    _cursorTimer = Timer.periodic(
      const Duration(milliseconds: 430),
      (timer) {
        if (!mounted || !_isStreaming) {
          timer.cancel();
          return;
        }

        setState(() => _cursorVisible = !_cursorVisible);
      },
    );
  }

  @override
  void dispose() {
    _streamTimer?.cancel();
    _cursorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: 250,
        maxHeight: 390,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PromptContext(),
            const SizedBox(height: 15),
            Row(
              children: [
                Icon(
                  Icons.psychology_alt_outlined,
                  size: 15,
                  color: _Palette.accent,
                ),
                const SizedBox(width: 7),
                Text(
                  _isStreaming ? 'GERANDO RESPOSTA' : 'RESPOSTA CONCLUÍDA',
                  style: TextStyle(
                    color:
                        _isStreaming ? _Palette.accent : _Palette.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                if (_isStreaming) const _StreamingIndicator(),
              ],
            ),
            const SizedBox(height: 13),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: _visibleResponse,
                    style: const TextStyle(
                      color: _Palette.textPrimary,
                      fontSize: 14,
                      height: 1.48,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_isStreaming)
                    TextSpan(
                      text: _cursorVisible ? '▍' : ' ',
                      style: const TextStyle(
                        color: _Palette.accent,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            if (!_isStreaming) ...[
              const SizedBox(height: 16),
              const Divider(
                height: 1,
                thickness: 1,
                color: _Palette.divider,
              ),
              const SizedBox(height: 11),
              const Row(
                children: [
                  Icon(
                    Icons.library_books_outlined,
                    size: 13,
                    color: _Palette.textMuted,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'REFERÊNCIA DEMONSTRATIVA · VALIDAÇÃO VISUAL',
                      style: TextStyle(
                        color: _Palette.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.45,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _CopyResponseButton(
                    text: _fullResponse,
                  ),
                  const SizedBox(width: 8),
                  _ContinueInAiButton(
                    onTap: widget.onContinue,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CopyResponseButton extends StatelessWidget {
  const _CopyResponseButton({
    required this.text,
  });

  final String text;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(
      ClipboardData(text: text),
    );

    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);

    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 900),
        backgroundColor: _Palette.surfaceStrong,
        content: Text(
          'Resposta copiada',
          style: TextStyle(
            color: _Palette.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        overlayColor: _Palette.pressedOverlay,
        splashFactory: NoSplash.splashFactory,
        borderRadius: BorderRadius.circular(8),
        onTap: () => _copy(context),
        child: const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 7,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.copy_all_outlined,
                size: 15,
                color: _Palette.textSecondary,
              ),
              SizedBox(width: 6),
              Text(
                'Copiar',
                style: TextStyle(
                  color: _Palette.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContinueInAiButton extends StatelessWidget {
  const _ContinueInAiButton({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          overlayColor: _Palette.pressedOverlay,
          splashFactory: NoSplash.splashFactory,
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 7,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.psychology_alt_outlined,
                  size: 15,
                  color: _Palette.accent,
                ),
                SizedBox(width: 7),
                Text(
                  'Continuar na IA',
                  style: TextStyle(
                    color: _Palette.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(width: 5),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 15,
                  color: _Palette.accent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PromptContext extends StatelessWidget {
  const _PromptContext();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(
            color: _Palette.accent,
            width: 2,
          ),
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.only(left: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PERGUNTA',
              style: TextStyle(
                color: _Palette.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Qual a dose de apixabana em FA com clearance 32?',
              style: TextStyle(
                color: _Palette.textSecondary,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreamingIndicator extends StatefulWidget {
  const _StreamingIndicator();

  @override
  State<_StreamingIndicator> createState() => _StreamingIndicatorState();
}

class _StreamingIndicatorState extends State<_StreamingIndicator> {
  Timer? _timer;
  int _activeDot = 0;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(
      const Duration(milliseconds: 280),
      (_) {
        if (mounted) {
          setState(() => _activeDot = (_activeDot + 1) % 3);
        }
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        3,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: index == _activeDot ? 6 : 4,
          height: index == _activeDot ? 6 : 4,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color: index == _activeDot ? _Palette.accent : _Palette.textMuted,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _MessageComposer extends StatefulWidget {
  const _MessageComposer({
    required this.expanded,
    required this.onOpen,
    required this.onSend,
  });

  final bool expanded;
  final VoidCallback onOpen;
  final ValueChanged<String> onSend;

  @override
  State<_MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<_MessageComposer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  void _submit() {
    final query = _controller.text.trim();

    if (query.isEmpty) {
      _focusNode.requestFocus();
      return;
    }

    _controller.clear();
    _focusNode.unfocus();
    widget.onSend(query);
  }

  void _previewMicrophone(BuildContext context) {
    final messenger = ScaffoldMessenger.maybeOf(context);

    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 750),
        backgroundColor: _Palette.surfaceStrong,
        content: Text(
          'Microfone será conectado em uma etapa própria.',
          style: TextStyle(
            color: _Palette.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _Palette.surfaceSoft,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 50,
        padding: const EdgeInsets.fromLTRB(11, 3, 3, 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _Palette.border,
            width: 0.6,
          ),
        ),
        child: Row(
          children: [
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                overlayColor: _Palette.pressedOverlay,
                splashFactory: NoSplash.splashFactory,
                borderRadius: BorderRadius.circular(9),
                onTap: () => _previewMicrophone(context),
                child: const SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(
                    Icons.mic_none_rounded,
                    size: 18,
                    color: _Palette.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 3),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: false,
                maxLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                style: const TextStyle(
                  color: _Palette.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 10,
                  ),
                  hintText: 'Digite uma dúvida clínica...',
                  hintStyle: TextStyle(
                    color: _Palette.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                overlayColor: _Palette.pressedOverlay,
                splashFactory: NoSplash.splashFactory,
                customBorder: const CircleBorder(),
                onTap: _submit,
                child: const SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    size: 19,
                    color: _Palette.accent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryClinicalCluster extends StatelessWidget {
  const _PrimaryClinicalCluster({
    required this.onFeedback,
  });

  final ValueChanged<String> onFeedback;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _Palette.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _Palette.border, width: 0.6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Column(
          children: [
            _PrimaryModuleButton(
              onFeedback: onFeedback,
              embedded: true,
            ),
            const Divider(
              height: 1,
              thickness: 1,
              color: _Palette.dividerStrong,
            ),
            _ClinicalModules(
              onFeedback: onFeedback,
              embedded: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryModuleButton extends StatelessWidget {
  const _PrimaryModuleButton({
    required this.onFeedback,
    this.embedded = false,
  });

  final ValueChanged<String> onFeedback;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return _ActionSurface(
      height: 75,
      embedded: embedded,
      backgroundColor: _Palette.farmacosSurface,
      onTap: () => onFeedback('Calculadoras & Fármacos'),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            height: 46,
            child: Center(
              child: SvgPicture.asset(
                'assets/icons/home_v2/ic_farmacos.svg',
                width: 36,
                height: 36,
                colorFilter: const ColorFilter.mode(
                  _Palette.farmacosIcon,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FÁRMACOS & CALCULADORAS',
                  style: TextStyle(
                    color: _Palette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Acesso rápido e disponível offline',
                  style: TextStyle(
                    color: _Palette.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 21,
            color: _Palette.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _ClinicalModules extends StatelessWidget {
  const _ClinicalModules({
    required this.onFeedback,
    this.embedded = false,
  });

  final ValueChanged<String> onFeedback;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ClinicalShortcut(
                label: 'PACIENTE',
                svgAsset: 'assets/icons/home_v2/ic_paciente.svg',
                iconSize: 31,
                iconColor: _Palette.patientIcon,
                surfaceColor: _Palette.patientSurface,
                onTap: () => onFeedback('Paciente'),
              ),
            ),
            const _ClinicalVerticalDivider(),
            Expanded(
              child: _ClinicalShortcut(
                label: 'PEDIATRIA',
                icon: Icons.child_care_outlined,
                iconSize: 30,
                iconColor: _Palette.pediatricsIcon,
                surfaceColor: _Palette.pediatricsSurface,
                onTap: () => onFeedback('Pediatria'),
              ),
            ),
          ],
        ),
        const _ClinicalHorizontalDivider(),
        Row(
          children: [
            Expanded(
              child: _ClinicalShortcut(
                label: 'FERRAMENTAS',
                svgAsset: 'assets/icons/home_v2/ic_ferramentas.svg',
                iconSize: 31,
                iconColor: _Palette.toolsIcon,
                surfaceColor: _Palette.toolsSurface,
                onTap: () => onFeedback('Ferramentas'),
              ),
            ),
            const _ClinicalVerticalDivider(),
            Expanded(
              child: _ClinicalShortcut(
                label: 'H. CLÍNICA',
                svgAsset: 'assets/icons/home_v2/ic_historia.svg',
                iconSize: 31,
                iconColor: _Palette.historyIcon,
                surfaceColor: _Palette.historySurface,
                onTap: () => onFeedback('História Clínica'),
              ),
            ),
          ],
        ),
      ],
    );

    return embedded
        ? content
        : _Panel(
            child: content,
          );
  }
}

class _PressScale extends StatefulWidget {
  const _PressScale({
    required this.onTap,
    required this.child,
    required this.color,
  });

  final VoidCallback onTap;
  final Widget child;
  final Color color;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) {
      return;
    }

    setState(() {
      _pressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.975 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: Material(
        color: widget.color,
        child: InkWell(
          overlayColor: _Palette.pressedOverlay,
          splashFactory: NoSplash.splashFactory,
          onHighlightChanged: _setPressed,
          onTap: widget.onTap,
          child: widget.child,
        ),
      ),
    );
  }
}

class _ClinicalShortcut extends StatelessWidget {
  const _ClinicalShortcut({
    required this.label,
    required this.onTap,
    this.icon,
    this.svgAsset,
    this.iconSize = 23,
    this.iconColor = _Palette.textSecondary,
    this.surfaceColor = _Palette.shortcutSurface,
  }) : assert(
          (icon == null) != (svgAsset == null),
          'Informe exatamente um ícone Material ou um SVG.',
        );

  final String label;
  final IconData? icon;
  final String? svgAsset;
  final double iconSize;
  final Color iconColor;
  final Color surfaceColor;
  final VoidCallback onTap;

  Widget get _iconWidget {
    final asset = svgAsset;

    if (asset != null) {
      return SvgPicture.asset(
        asset,
        width: iconSize,
        height: iconSize,
        colorFilter: ColorFilter.mode(
          iconColor,
          BlendMode.srcIn,
        ),
      );
    }

    return Icon(
      icon!,
      size: iconSize,
      color: iconColor,
    );
  }

  Widget get _content {
    return SizedBox(
      height: 68,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _iconWidget,
          const SizedBox(height: 7),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _Palette.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_Palette.lightPreview) {
      return _PressScale(
        color: surfaceColor,
        onTap: onTap,
        child: _content,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _Palette.border, width: 0.6),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08111820),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: _PressScale(
            color: surfaceColor,
            onTap: onTap,
            child: _content,
          ),
        ),
      ),
    );
  }
}

class _ClinicalVerticalDivider extends StatelessWidget {
  const _ClinicalVerticalDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 1,
      height: 68,
      child: Center(
        child: SizedBox(
          width: 0.55,
          height: 42,
          child: ColoredBox(
            color: _Palette.dividerStrong,
          ),
        ),
      ),
    );
  }
}

class _ClinicalHorizontalDivider extends StatelessWidget {
  const _ClinicalHorizontalDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        height: 0.55,
        width: double.infinity,
        child: ColoredBox(
          color: _Palette.dividerStrong,
        ),
      ),
    );
  }
}

class _UtilityModules extends StatelessWidget {
  const _UtilityModules({
    required this.onFeedback,
  });

  final ValueChanged<String> onFeedback;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        children: [
          Expanded(
            child: _UtilityShortcut(
              label: 'AVALIAÇÃO',
              svgAsset: 'assets/icons/home_v2/ic_avaliacao.svg',
              iconColor: _Palette.assessmentIcon,
              surfaceColor: _Palette.assessmentSurface,
              onTap: () => onFeedback('Avaliação'),
            ),
          ),
          const _UtilityDivider(),
          Expanded(
            child: _UtilityShortcut(
              label: 'NOTAS',
              svgAsset: 'assets/icons/home_v2/ic_notas.svg',
              iconColor: _Palette.notesIcon,
              surfaceColor: _Palette.notesSurface,
              onTap: () => onFeedback('Notas'),
            ),
          ),
          const _UtilityDivider(),
          Expanded(
            child: _UtilityShortcut(
              label: 'TIMER',
              svgAsset: 'assets/icons/home_v2/ic_timer.svg',
              iconColor: _Palette.timerIcon,
              surfaceColor: _Palette.timerSurface,
              onTap: () => onFeedback('Timer'),
            ),
          ),
        ],
      ),
    );
  }
}

class _UtilityShortcut extends StatelessWidget {
  const _UtilityShortcut({
    required this.label,
    required this.svgAsset,
    required this.iconColor,
    required this.surfaceColor,
    required this.onTap,
  });

  final String label;
  final String svgAsset;
  final Color iconColor;
  final Color surfaceColor;
  final VoidCallback onTap;

  Widget get _content {
    return SizedBox(
      height: 72,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            svgAsset,
            width: 30,
            height: 30,
            colorFilter: ColorFilter.mode(
              iconColor,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: const TextStyle(
              color: _Palette.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_Palette.lightPreview) {
      return _PressScale(
        color: surfaceColor,
        onTap: onTap,
        child: _content,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _Palette.border, width: 0.6),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08111820),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: _PressScale(
            color: surfaceColor,
            onTap: onTap,
            child: _content,
          ),
        ),
      ),
    );
  }
}

class _UtilityDivider extends StatelessWidget {
  const _UtilityDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 1,
      height: 72,
      child: Center(
        child: SizedBox(
          width: 0.55,
          height: 40,
          child: ColoredBox(
            color: _Palette.dividerStrong,
          ),
        ),
      ),
    );
  }
}

class _PreviewGuardiaPatient {
  const _PreviewGuardiaPatient({
    required this.name,
    required this.severity,
    required this.severityTone,
  });

  final String name;
  final String severity;
  final _SeverityTone severityTone;
}

const _previewGuardiaPatients = <_PreviewGuardiaPatient>[
  _PreviewGuardiaPatient(
    name: 'R. Santos',
    severity: 'CRÍTICA',
    severityTone: _SeverityTone.critical,
  ),
  _PreviewGuardiaPatient(
    name: 'L. Almeida',
    severity: 'ALTA',
    severityTone: _SeverityTone.high,
  ),
  _PreviewGuardiaPatient(
    name: 'M. Costa',
    severity: 'MODERADA',
    severityTone: _SeverityTone.moderate,
  ),
  _PreviewGuardiaPatient(
    name: 'P. Silva',
    severity: 'BAIXA',
    severityTone: _SeverityTone.low,
  ),
];

class _GuardiaWorkspace extends StatelessWidget {
  const _GuardiaWorkspace({
    required this.expanded,
    required this.onToggle,
    required this.onFeedback,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<String> onFeedback;

  @override
  Widget build(BuildContext context) {
    final languageCode =
        Localizations.localeOf(context).languageCode.toLowerCase();

    final shiftTitle = languageCode == 'pt' ? 'MEU PLANTÃO' : 'MI GUARDIA';

    return _Panel(
      child: Column(
        children: [
          Material(
            color: _Palette.shiftSurface,
            child: InkWell(
              overlayColor: _Palette.pressedOverlay,
              splashFactory: NoSplash.splashFactory,
              borderRadius: BorderRadius.circular(6),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(15, 13, 11, 13),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/icons/home_v2/ic_plantao.svg',
                          width: 32,
                          height: 32,
                          colorFilter: const ColorFilter.mode(
                            _Palette.shiftIcon,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          shiftTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _Palette.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: const BoxDecoration(
                        color: _Palette.accentSoft,
                        borderRadius: BorderRadius.all(
                          Radius.circular(6),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Text(
                          '${_previewGuardiaPatients.length}',
                          style: const TextStyle(
                            color: _Palette.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: expanded
                ? _GuardiaExpandedContent(onFeedback: onFeedback)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _GuardiaExpandedContent extends StatelessWidget {
  const _GuardiaExpandedContent({
    required this.onFeedback,
  });

  final ValueChanged<String> onFeedback;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(
            height: 1,
            thickness: 1,
            color: _Palette.divider,
          ),
          const SizedBox(height: 11),
          _AddPatientButton(
            onTap: () => onFeedback('Adicionar paciente'),
          ),
          const SizedBox(height: 9),
          ..._previewGuardiaPatients.map(
            (patient) => _PatientRow(
              name: patient.name,
              severity: patient.severity,
              severityTone: patient.severityTone,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'ATALHOS DE ESPECIALIDADE',
            style: TextStyle(
              color: _Palette.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.65,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _SpecialtyShortcut(
                  label: 'CARDIO',
                  svgAsset: 'assets/icons/home_v2/ic_cardio.svg',
                  iconColor: _Palette.cardioIcon,
                  surfaceColor: _Palette.cardioSurface,
                  onTap: () => onFeedback('Cardiologia'),
                ),
              ),
              const _SpecialtyDivider(),
              Expanded(
                child: _SpecialtyShortcut(
                  label: 'NEFRO',
                  svgAsset: 'assets/icons/home_v2/ic_nefro.svg',
                  iconColor: _Palette.nephroIcon,
                  surfaceColor: _Palette.nephroSurface,
                  onTap: () => onFeedback('Nefrologia'),
                ),
              ),
              const _SpecialtyDivider(),
              Expanded(
                child: _SpecialtyShortcut(
                  label: 'HEPATO',
                  svgAsset: 'assets/icons/home_v2/ic_hepato.svg',
                  iconColor: _Palette.hepatoIcon,
                  surfaceColor: _Palette.hepatoSurface,
                  onTap: () => onFeedback('Hepatologia'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddPatientButton extends StatelessWidget {
  const _AddPatientButton({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: _Palette.accentSoft,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          overlayColor: _Palette.pressedOverlay,
          splashFactory: NoSplash.splashFactory,
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_rounded,
                  color: _Palette.accent,
                  size: 20,
                ),
                SizedBox(width: 6),
                Text(
                  'PACIENTE',
                  style: TextStyle(
                    color: _Palette.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _SeverityTone {
  low,
  moderate,
  high,
  critical,
}

class _PatientRow extends StatelessWidget {
  const _PatientRow({
    required this.name,
    required this.severity,
    required this.severityTone,
  });

  final String name;
  final String severity;
  final _SeverityTone severityTone;

  Color get _severityColor {
    if (_Palette.lightPreview) {
      return switch (severityTone) {
        _SeverityTone.low => const Color(0xFF147A55),
        _SeverityTone.moderate => const Color(0xFF9A7000),
        _SeverityTone.high => const Color(0xFFC65D14),
        _SeverityTone.critical => const Color(0xFFC62828),
      };
    }

    return switch (severityTone) {
      _SeverityTone.low => const Color(0xFF73D7B0),
      _SeverityTone.moderate => const Color(0xFFE4C86D),
      _SeverityTone.high => const Color(0xFFF0A363),
      _SeverityTone.critical => const Color(0xFFF27777),
    };
  }

  Color get _severityBackground {
    if (_Palette.lightPreview) {
      return switch (severityTone) {
        _SeverityTone.low => const Color(0xFFE3F5ED),
        _SeverityTone.moderate => const Color(0xFFFFF6D6),
        _SeverityTone.high => const Color(0xFFFFF0E3),
        _SeverityTone.critical => const Color(0xFFFDE7E7),
      };
    }

    return switch (severityTone) {
      _SeverityTone.low => const Color(0xFF15352D),
      _SeverityTone.moderate => const Color(0xFF39321B),
      _SeverityTone.high => const Color(0xFF3D291A),
      _SeverityTone.critical => const Color(0xFF3B2023),
    };
  }

  Widget get _severityChip {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _severityBackground,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 9,
          vertical: 5,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.circle,
              color: _severityColor,
              size: 8,
            ),
            const SizedBox(width: 5),
            Text(
              severity,
              style: TextStyle(
                color: _severityColor,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget get _rowContent {
    return Row(
      children: [
        const CircleAvatar(
          radius: 17,
          backgroundColor: _Palette.surfaceStrong,
          child: Icon(
            Icons.person_outline_rounded,
            size: 18,
            color: _Palette.textSecondary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(
              color: _Palette.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _severityChip,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_Palette.lightPreview) {
      return Container(
        height: 54,
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: _Palette.divider,
            ),
          ),
        ),
        child: _rowContent,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _Palette.surfaceSoft,
            border: Border.all(color: _Palette.border, width: 0.6),
          ),
          child: SizedBox(
            height: 58,
            child: Row(
              children: [
                ColoredBox(
                  color: _severityColor,
                  child: const SizedBox(
                    width: 4,
                    height: double.infinity,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _rowContent,
                ),
                const SizedBox(width: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpecialtyShortcut extends StatelessWidget {
  const _SpecialtyShortcut({
    required this.label,
    required this.svgAsset,
    required this.iconColor,
    required this.surfaceColor,
    required this.onTap,
  });

  final String label;
  final String svgAsset;
  final Color iconColor;
  final Color surfaceColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          overlayColor: _Palette.pressedOverlay,
          splashFactory: NoSplash.splashFactory,
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(
            height: 68,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  svgAsset,
                  width: 31,
                  height: 31,
                  colorFilter: ColorFilter.mode(
                    iconColor,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  label,
                  style: const TextStyle(
                    color: _Palette.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpecialtyDivider extends StatelessWidget {
  const _SpecialtyDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 1,
      height: 38,
      child: ColoredBox(
        color: _Palette.divider,
      ),
    );
  }
}

class _DesktopStatusPanel extends StatelessWidget {
  const _DesktopStatusPanel();

  @override
  Widget build(BuildContext context) {
    return const _Panel(
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RESUMO DO PLANTÃO',
              style: TextStyle(
                color: _Palette.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Visão rápida do estado atual',
              style: TextStyle(
                color: _Palette.textSecondary,
                fontSize: 12,
              ),
            ),
            SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'PACIENTES',
                    value: '04',
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _Metric(
                    label: 'ALERTAS',
                    value: '02',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _Palette.surfaceSoft,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _Palette.border, width: 0.6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: _Palette.textPrimary,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: _Palette.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.highlighted = false,
    this.radius = 6,
  });

  final Widget child;
  final bool highlighted;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 230),
      width: double.infinity,
      decoration: BoxDecoration(
        color: highlighted ? _Palette.surfaceActive : _Palette.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: highlighted ? _Palette.borderActive : _Palette.border,
        ),
        boxShadow: null,
      ),
      child: child,
    );
  }
}

class _ActionSurface extends StatelessWidget {
  const _ActionSurface({
    required this.height,
    required this.child,
    required this.onTap,
    this.embedded = false,
    this.backgroundColor,
  });

  final double height;
  final Widget child;
  final VoidCallback onTap;
  final bool embedded;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final radius = embedded ? BorderRadius.zero : BorderRadius.circular(6);
    final resolvedColor =
        backgroundColor ?? (embedded ? Colors.transparent : _Palette.surface);

    return Material(
      color: resolvedColor,
      borderRadius: radius,
      child: InkWell(
        overlayColor: _Palette.pressedOverlay,
        splashFactory: NoSplash.splashFactory,
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: resolvedColor,
            borderRadius: radius,
            border: embedded
                ? null
                : Border.all(color: _Palette.border, width: 0.6),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({
    required this.icon,
    required this.label,
  });

  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _Palette.surfaceStrong,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _Palette.border, width: 0.6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 7,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: _Palette.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
