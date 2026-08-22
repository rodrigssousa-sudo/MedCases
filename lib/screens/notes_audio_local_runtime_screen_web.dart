import 'package:flutter/material.dart';

import '../models/study_long_form_audio_handoff.dart';

final class _WebAudioPalette {
  const _WebAudioPalette({
    required this.page,
    required this.card,
    required this.divider,
    required this.text,
    required this.secondary,
    required this.accent,
  });

  final Color page;
  final Color card;
  final Color divider;
  final Color text;
  final Color secondary;
  final Color accent;

  factory _WebAudioPalette.of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return _WebAudioPalette(
      page: dark ? const Color(0xFF1A1D23) : const Color(0xFFECF1F3),
      card: dark ? const Color(0xFF252930) : Colors.white,
      divider: dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC),
      text: dark ? const Color(0xFFF8FAFC) : const Color(0xFF111318),
      secondary: dark ? const Color(0xFFC6CED9) : const Color(0xFF52606D),
      accent: const Color(0xFF10B981),
    );
  }
}

class NotesAudioConsultationLocalRuntimeScreen extends StatelessWidget {
  const NotesAudioConsultationLocalRuntimeScreen({
    super.key,
    required this.isEs,
  });

  final bool isEs;

  @override
  Widget build(BuildContext context) {
    return _WebAudioUnavailableScreen(
      isEs: isEs,
      title: 'Consulta clínica',
      icon: Icons.mic_none_rounded,
      description: isEs
          ? 'La captura clínica local está disponible en la aplicación '
              'MedCases para iPhone y Android.'
          : 'A captura clínica local está disponível no aplicativo '
              'MedCases para iPhone e Android.',
    );
  }
}

class NotesAudioLongFormLocalRuntimeScreen extends StatelessWidget {
  const NotesAudioLongFormLocalRuntimeScreen({
    super.key,
    required this.isEs,
    this.onCompleted,
  });

  final bool isEs;
  final ValueChanged<StudyLongFormAudioHandoff>? onCompleted;

  @override
  Widget build(BuildContext context) {
    return _WebAudioUnavailableScreen(
      isEs: isEs,
      title: isEs ? 'Clase / audio largo' : 'Aula / áudio longo',
      icon: Icons.graphic_eq_rounded,
      description: isEs
          ? 'La grabación local M4A de larga duración está disponible en '
              'la aplicación MedCases para iPhone y Android.'
          : 'A gravação local M4A de longa duração está disponível no '
              'aplicativo MedCases para iPhone e Android.',
    );
  }
}

class _WebAudioUnavailableScreen extends StatelessWidget {
  const _WebAudioUnavailableScreen({
    required this.isEs,
    required this.title,
    required this.icon,
    required this.description,
  });

  final bool isEs;
  final String title;
  final IconData icon;
  final String description;

  @override
  Widget build(BuildContext context) {
    final palette = _WebAudioPalette.of(context);

    return Scaffold(
      backgroundColor: palette.page,
      appBar: AppBar(
        toolbarHeight: 48,
        centerTitle: true,
        elevation: 0,
        backgroundColor: palette.page,
        foregroundColor: palette.text,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(
            Icons.chevron_left_rounded,
            size: 23,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: palette.text,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.1,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 15, 14, 15),
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: palette.divider,
                  width: 0.7,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    icon,
                    size: 24,
                    color: palette.accent,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEs
                              ? 'Disponible en la aplicación móvil'
                              : 'Disponível no aplicativo móvel',
                          style: TextStyle(
                            color: palette.text,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          description,
                          style: TextStyle(
                            color: palette.secondary,
                            fontSize: 12.5,
                            height: 1.42,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isEs
                              ? 'La versión web mantiene Notas, Historial y '
                                  'la interfaz de Audio sin activar captura '
                                  'local no soportada.'
                              : 'A versão web mantém Notas, Histórico e a '
                                  'interface de Áudio sem ativar captura '
                                  'local não suportada.',
                          style: TextStyle(
                            color: palette.secondary,
                            fontSize: 11.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
