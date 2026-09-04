import 'package:flutter/material.dart';

import '../services/audio/clinical_long_form_remote_audio_consent_store.dart';
import 'legal_screen.dart';

/// Purpose-specific consent UI for optional remote audio transcription.
///
/// This widget is intentionally reusable and is NOT wired to any production
/// recorder/transcription callsite yet. A future remote transcription owner
/// must invoke [showIfNeeded] before transmitting audio.
final class ClinicalLongFormRemoteAudioConsentUi {
  const ClinicalLongFormRemoteAudioConsentUi._();

  static const bool uiFoundationCertified = true;
  static const bool productionCallsiteWired = false;
  static const bool productionRemoteAudioEnabled = false;

  static Future<bool> showIfNeeded(
    BuildContext context, {
    required String language,
    ClinicalLongFormRemoteAudioConsentStore store =
        const ClinicalLongFormRemoteAudioConsentStore(),
  }) async {
    if (await store.hasActiveConsent()) {
      return true;
    }

    if (!context.mounted) {
      return false;
    }

    final normalizedLanguage =
        language.trim().toLowerCase().startsWith('es') ? 'es' : 'pt';

    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _RemoteAudioConsentSheet(
        language: normalizedLanguage,
        store: store,
      ),
    );

    return accepted ?? false;
  }
}

final class _RemoteAudioConsentSheet extends StatefulWidget {
  const _RemoteAudioConsentSheet({
    required this.language,
    required this.store,
  });

  final String language;
  final ClinicalLongFormRemoteAudioConsentStore store;

  @override
  State<_RemoteAudioConsentSheet> createState() =>
      _RemoteAudioConsentSheetState();
}

final class _RemoteAudioConsentSheetState
    extends State<_RemoteAudioConsentSheet> {
  bool _explicitlyAccepted = false;
  bool _saving = false;

  bool get _isEs => widget.language == 'es';

  String get _title =>
      _isEs ? 'Transcripción remota de audio' : 'Transcrição remota de áudio';

  String get _intro => _isEs
      ? 'Para transcribir este audio con mayor precisión, los segmentos '
          'seleccionados podrán enviarse cifrados en tránsito a través del '
          'backend de MedCases Pro a un proveedor externo de IA.'
      : 'Para transcrever este áudio com maior precisão, os segmentos '
          'selecionados poderão ser enviados com criptografia em trânsito '
          'pelo backend do MedCases Pro a um provedor externo de IA.';

  String get _temporaryCopy => _isEs
      ? 'MedCases Pro utiliza solamente una copia temporal durante el '
          'procesamiento y no debe conservar el audio de forma duradera '
          'en su backend.'
      : 'O MedCases Pro utiliza somente uma cópia temporária durante o '
          'processamento e não deve conservar o áudio de forma durável '
          'em seu backend.';

  String get _reviewLifecycle => _isEs
      ? 'En el dispositivo, el audio permanece disponible para revisión. '
          'Después de su confirmación, se elimina por defecto y se conserva '
          'la transcripción o los materiales derivados elegidos.'
      : 'No dispositivo, o áudio permanece disponível para revisão. '
          'Após sua confirmação, ele é excluído por padrão e permanecem '
          'a transcrição ou os materiais derivados escolhidos.';

  String get _revocation => _isEs
      ? 'Este consentimiento es opcional, específico para audio y puede '
          'revocarse. El consentimiento general de la app no lo sustituye.'
      : 'Este consentimento é opcional, específico para áudio e pode ser '
          'revogado. O consentimento geral do app não o substitui.';

  String get _checkboxLabel => _isEs
      ? 'Comprendo y autorizo la transcripción remota de audio cuando '
          'solicite esta función.'
      : 'Compreendo e autorizo a transcrição remota de áudio quando '
          'solicitar este recurso.';

  String get _privacyLabel =>
      _isEs ? 'Leer Política de Privacidad' : 'Ler Política de Privacidade';

  String get _declineLabel => _isEs ? 'Ahora no' : 'Agora não';

  String get _acceptLabel =>
      _isEs ? 'Aceptar y continuar' : 'Concordar e continuar';

  Future<void> _accept() async {
    if (!_explicitlyAccepted || _saving) {
      return;
    }

    setState(() => _saving = true);

    try {
      await widget.store.accept(language: widget.language);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEs
                ? 'No se pudo registrar el consentimiento. Inténtalo de nuevo.'
                : 'Não foi possível registrar o consentimento. Tente novamente.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    final page = dark ? const Color(0xFF1A1D23) : const Color(0xFFECF1F3);
    final card = dark ? const Color(0xFF252930) : Colors.white;
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111318);
    final secondary = dark ? const Color(0xFFC6CED9) : const Color(0xFF52606D);
    final divider = dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);
    final accent = const Color(0xFF10B981);

    return Material(
      color: page,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          MediaQuery.viewPaddingOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _title,
                    style: TextStyle(
                      color: text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: IconButton(
                    tooltip: _isEs ? 'Cerrar' : 'Fechar',
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(false),
                    icon: Icon(Icons.close_rounded, color: secondary, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _InfoCard(
              background: card,
              divider: divider,
              textColor: text,
              secondaryColor: secondary,
              children: [
                _InfoLine(
                  icon: Icons.lock_outline_rounded,
                  text: _intro,
                  color: secondary,
                ),
                _InfoLine(
                  icon: Icons.delete_outline_rounded,
                  text: _temporaryCopy,
                  color: secondary,
                ),
                _InfoLine(
                  icon: Icons.fact_check_outlined,
                  text: _reviewLifecycle,
                  color: secondary,
                ),
                _InfoLine(
                  icon: Icons.verified_user_outlined,
                  text: _revocation,
                  color: secondary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _saving
                  ? null
                  : () => setState(
                        () => _explicitlyAccepted = !_explicitlyAccepted,
                      ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: divider, width: 0.7),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color:
                            _explicitlyAccepted ? accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: _explicitlyAccepted ? accent : secondary,
                          width: 1.4,
                        ),
                      ),
                      child: _explicitlyAccepted
                          ? const Icon(
                              Icons.check_rounded,
                              size: 15,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _checkboxLabel,
                        style: TextStyle(
                          color: text,
                          fontSize: 12.5,
                          height: 1.42,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _saving
                  ? null
                  : () => showLegalSheet(
                        context,
                        LegalType.privacy,
                        widget.language,
                      ),
              style: TextButton.styleFrom(
                foregroundColor: accent,
                disabledForegroundColor: secondary,
                overlayColor: Colors.transparent,
                shadowColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
              ),
              child: Text(
                _privacyLabel,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: text,
                        disabledForegroundColor: secondary,
                        backgroundColor: Colors.transparent,
                        side: BorderSide(color: divider, width: 0.8),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        surfaceTintColor: Colors.transparent,
                        overlayColor: Colors.transparent,
                      ),
                      child: Text(_declineLabel),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 42,
                    child: FilledButton(
                      onPressed:
                          _explicitlyAccepted && !_saving ? _accept : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            dark ? const Color(0xFF2D3340) : divider,
                        disabledForegroundColor: secondary,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        surfaceTintColor: Colors.transparent,
                        overlayColor: Colors.transparent,
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Text(_acceptLabel),
                    ),
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

final class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.background,
    required this.divider,
    required this.textColor,
    required this.secondaryColor,
    required this.children,
  });

  final Color background;
  final Color divider;
  final Color textColor;
  final Color secondaryColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: divider, width: 0.7),
      ),
      child: Column(children: children),
    );
  }
}

final class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                height: 1.42,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
