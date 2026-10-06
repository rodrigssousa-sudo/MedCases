import 'dart:async';
import 'package:flutter/material.dart';
import '../../../home_v2/theme/home_v2_palette.dart';

/// Shared presentation-only preparation state. These short timed phrases do
/// not claim hidden provider/tool activity or delay an available answer.
class AiResponseLoading extends StatefulWidget {
  const AiResponseLoading(
      {super.key,
      required this.dark,
      required this.lang,
      this.showPhrases = true});
  final bool dark, showPhrases;
  final String lang;
  static const pt = [
    'Consultando o MedCases…',
    'Organizando as informações…',
    'Verificando os pontos principais…',
    'Preparando a resposta…'
  ];
  static const es = [
    'Consultando MedCases…',
    'Organizando la información…',
    'Verificando los puntos principales…',
    'Preparando la respuesta…'
  ];
  @override
  State<AiResponseLoading> createState() => _AiResponseLoadingState();
}

class _AiResponseLoadingState extends State<AiResponseLoading> {
  Timer? _timer;
  int _phase = 0;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2200), (timer) {
      if (_phase == 3 || !widget.showPhrases) {
        timer.cancel();
        return;
      }
      setState(() => _phase++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = HomeV2Palette.resolve(widget.dark);
    if (!widget.showPhrases) return const SizedBox.shrink();
    final labels = widget.lang.startsWith('es')
        ? AiResponseLoading.es : AiResponseLoading.pt;
    return Column(
      key: const ValueKey('global-ai-loading'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [for (var i = 0; i < labels.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Semantics(
            liveRegion: i == _phase,
            child: Text(labels[i],
              key: ValueKey('ai-loading-step-$i'),
              style: TextStyle(fontSize: 14, height: 1.4,
                fontWeight: i == _phase ? FontWeight.w700 : FontWeight.w400,
                color: i == _phase ? palette.textPrimary : palette.textSecondary)),
          ),
        ),
      ],
    );
  }
}
