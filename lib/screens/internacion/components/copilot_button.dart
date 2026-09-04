// MEDCASES_COPILOT_PRE_R013_VISUAL_RESTORED_V1
// ─────────────────────────────────────────────────────────────────────────────
// CopilotButton — Build 160 — Botão Medcases Inteligente
//
// Botão proeminente que abre bottom sheet multimodal (texto + imagem/PDF).
// Mostra shimmer durante o processamento da IA.
// Após resposta, dispara RevisionSheet (Human-in-the-Loop).
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import '../services/soap_copilot_service.dart';
import '../../../services/gemini_service.dart';
import 'internacion_theme.dart';
import 'revision_sheet.dart';

import '../../../design_system/foundation/med_typography.dart';

// ── Callback de aprovação passada para o pai ──────────────────────────────────
typedef OnAiApproved = void Function(SoapDraftResult draft);

// ═════════════════════════════════════════════════════════════════════════════
// Widget principal
// ═════════════════════════════════════════════════════════════════════════════
class CopilotButton extends StatefulWidget {
  final bool dark;
  final String lang;
  final OnAiApproved onApproved;

  const CopilotButton({
    super.key,
    required this.dark,
    required this.lang,
    required this.onApproved,
  });

  @override
  State<CopilotButton> createState() => _CopilotButtonState();
}

class _CopilotButtonState extends State<CopilotButton>
    with SingleTickerProviderStateMixin {
  // Shimmer animation controller
  late final AnimationController _shimmerCtrl;
  late final Animation<double> _shimmerAnim;
  bool _isLoading = false;

  bool get isEs => widget.lang == 'es';

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _shimmerAnim = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  // ── Abre o bottom sheet de input ─────────────────────────────────────────
  void _openInputSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CopilotInputSheet(
        dark: widget.dark,
        lang: widget.lang,
        onSubmit: _handleSubmit,
      ),
    );
  }

  // ── Processa o input e chama a IA ────────────────────────────────────────
  Future<void> _handleSubmit(
      String text, List<_ImageAttachment> attachments) async {
    if (!mounted) return;

    final apiKey = GeminiService.apiKeyForLab;
    if (apiKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEs
              ? 'Configura tu API Key de Gemini en Ajustes primero.'
              : 'Configure sua API Key do Gemini em Configurações primeiro.'),
          backgroundColor: InternacionTheme.amber,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final images = attachments.map((a) => a.bytes).toList();
      final mimes = attachments.map((a) => a.mimeType).toList();

      final draft = await SoapCopilotService.extractSoap(
        text: text,
        images: images.isEmpty ? null : images,
        imagesMimeType: mimes.isEmpty ? null : mimes,
        apiKey: apiKey,
      );

      if (!mounted) return;

      // Abre o RevisionSheet — nada é injetado sem aprovação
      await RevisionSheet.show(
        context: context,
        draft: draft,
        dark: widget.dark,
        lang: widget.lang,
        onDiscard: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(isEs ? 'Datos descartados.' : 'Dados descartados.'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 1),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ));
          }
        },
        onApprove: () {
          widget.onApproved(draft);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Row(children: [
                const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 15),
                const SizedBox(width: 8),
                Text(isEs
                    ? '${draft.filledCount} campos rellenados por IA'
                    : '${draft.filledCount} campos preenchidos pela IA'),
              ]),
              backgroundColor: InternacionTheme.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ));
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${isEs ? 'Error de IA' : 'Erro da IA'}: $e'),
          backgroundColor: InternacionTheme.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  @override
  @override
  @override
  @override
  Widget build(BuildContext context) {
    // MEDCASES_PACIENTES_HOME_COMPACT_COPILOT_V1_B_R0
    // MEDCASES_PACIENTES_FINAL_AI_EMPHASIS_V1_B_R0
    // MEDCASES_PACIENTES_AI_SIGNATURE_CARD_V1_B_R0
    final dark = widget.dark;
    final surface =
        dark ? const Color(0xFF202A29) : const Color(0xFFF4FAF7);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _isLoading ? null : _openInputSheet,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 21.5, 14, 21.5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              surface,
              dark ? const Color(0xFF17342C) : const Color(0xFFE7F7F0),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: InternacionTheme.accentLight.withOpacity(
                dark ? 0.14 : 0.09,
              ),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: _isLoading ? _buildLoadingState() : _buildIdleState(),
      ),
    );
  }

  // ── Estado idle (botão normal) ────────────────────────────────────────────
  Widget _buildIdleState() {
    final textPrimary =
        widget.dark ? Colors.white : const Color(0xFF111827);
    final textSecondary =
        widget.dark ? const Color(0xFFCBD5E1) : const Color(0xFF667085);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _shimmerCtrl,
          builder: (_, child) {
            final t = _shimmerCtrl.value;
            final lift = 1.5 * (1 - ((2 * t) - 1).abs());

            return Transform.translate(
              offset: Offset(0, -lift),
              child: child,
            );
          },
          child: SizedBox(
            width: 58,
            height: 58,
            child: SvgPicture.asset(
              'assets/icons/home_v2/ic_ia.svg',
              width: 58,
              height: 58,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [

              const Text(
                'IA CLÍNICA · SOAP',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.75,
                  color: InternacionTheme.accentLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'MedCases Inteligente',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                isEs
                    ? 'Texto o imagen → organiza el SOAP'
                    : 'Texto ou imagem → organiza o SOAP',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: textSecondary,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: InternacionTheme.accentLight.withOpacity(
              widget.dark ? 0.13 : 0.10,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Abrir',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: InternacionTheme.accentLight,
                ),
              ),
              SizedBox(width: 2),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: InternacionTheme.accentLight,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Estado de carregamento com shimmer ───────────────────────────────────
  Widget _buildLoadingState() {
    return AnimatedBuilder(
      animation: _shimmerAnim,
      builder: (_, __) {
        final textPrimary =
            widget.dark ? Colors.white : const Color(0xFF111827);
        final textSecondary =
            widget.dark ? const Color(0xFFCBD5E1) : const Color(0xFF667085);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 38,
              height: 38,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: 0.42,
                    child: SvgPicture.asset(
                      'assets/icons/home_v2/ic_ia.svg',
                      width: 38,
                      height: 38,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      valueColor: AlwaysStoppedAnimation(
                        InternacionTheme.accentLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: InternacionTheme.accentLight.withOpacity(
                        widget.dark ? 0.14 : 0.10,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'IA CLÍNICA',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.55,
                        color: InternacionTheme.accentLight,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isEs ? 'Organizando SOAP…' : 'Organizando SOAP…',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isEs
                        ? 'Revisa antes de aplicar'
                        : 'Revise antes de aplicar',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

}

// ═════════════════════════════════════════════════════════════════════════════
// Bottom Sheet de Input Multimodal
// ═════════════════════════════════════════════════════════════════════════════

class _ImageAttachment {
  final Uint8List bytes;
  final String mimeType;
  final String name;

  const _ImageAttachment({
    required this.bytes,
    required this.mimeType,
    required this.name,
  });
}

typedef _OnSubmit = void Function(
    String text, List<_ImageAttachment> attachments);

class _CopilotInputSheet extends StatefulWidget {
  final bool dark;
  final String lang;
  final _OnSubmit onSubmit;

  const _CopilotInputSheet({
    required this.dark,
    required this.lang,
    required this.onSubmit,
  });

  @override
  State<_CopilotInputSheet> createState() => _CopilotInputSheetState();
}

class _CopilotInputSheetState extends State<_CopilotInputSheet> {
  final _textCtrl = TextEditingController();
  final List<_ImageAttachment> _attachments = [];
  final _picker = ImagePicker();

  bool get isEs => widget.lang == 'es';

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  // ── Pick imagem da galeria ou câmera ──────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final mime = picked.mimeType ?? 'image/jpeg';
      setState(() => _attachments.add(_ImageAttachment(
            bytes: bytes,
            mimeType: mime,
            name: picked.name,
          )));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${isEs ? 'Error al cargar imagen' : 'Erro ao carregar imagem'}: $e'),
          backgroundColor: InternacionTheme.red,
        ));
      }
    }
  }

  void _removeAttachment(int idx) {
    setState(() => _attachments.removeAt(idx));
  }

  void _submit() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty && _attachments.isEmpty) return;
    Navigator.of(context).pop();
    widget.onSubmit(text, List.from(_attachments));
  }

  bool get _canSubmit =>
      _textCtrl.text.trim().isNotEmpty || _attachments.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = InternacionTheme(widget.dark);
    final bg = widget.dark ? const Color(0xFF0F1116) : Colors.white;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: const Color(0xFF0D6B57).withOpacity(0.30),
            width: 1.2,
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Row(children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D6B57), Color(0xFF0D6B57)],
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEs ? 'Copiloto Medcases' : 'Copiloto Medcases',
                    style: TextStyle(
                      fontSize: MedTypography.clinicalBodySize,
                      fontWeight: FontWeight.w800,
                      color: theme.textPrimary,
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(
                  isEs
                      ? 'Dicta notas rápidas, pega valores o sube fotos de monitores y labs.'
                      : 'Dite notas rápidas, cole valores ou suba fotos de monitores e labs.',
                  style: TextStyle(
                      fontSize: MedTypography.auxiliarySize,
                      color: theme.textSecondary,
                      height: 1.4),
                ),
                const SizedBox(height: 14),

                // Área de texto
                Container(
                  decoration: BoxDecoration(
                    color: theme.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.border, width: 0.9),
                  ),
                  child: TextField(
                    controller: _textCtrl,
                    maxLines: 6,
                    minLines: 3,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(
                      fontSize: MedTypography.clinicalBodySize,
                      color: theme.textPrimary,
                      height: 1.5,
                    ),
                    decoration: InputDecoration(
                      hintText: isEs
                          ? 'Ej: "paciente bien, pa 120/80, sin dor, Hb 10.2, vou manter atb..."'
                          : 'Ex: "paciente bem, pa 120/80, sem dor, Hb 10.2, vou manter atb..."',
                      hintStyle: TextStyle(
                        fontSize: MedTypography.auxiliarySize,
                        color: theme.textSecondary.withOpacity(0.6),
                      ),
                      contentPadding: const EdgeInsets.all(14),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Attachments preview
                if (_attachments.isNotEmpty) ...[
                  SizedBox(
                    height: 72,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _attachments.length,
                      itemBuilder: (_, i) => _AttachmentThumbnail(
                        attachment: _attachments[i],
                        dark: widget.dark,
                        onRemove: () => _removeAttachment(i),
                        theme: theme,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Botões de ação
                Row(children: [
                  // Galeria
                  _AttachBtn(
                    icon: Icons.photo_library_rounded,
                    label: isEs ? 'Galería' : 'Galeria',
                    dark: widget.dark,
                    theme: theme,
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                  const SizedBox(width: 8),
                  // Câmera
                  _AttachBtn(
                    icon: Icons.camera_alt_rounded,
                    label: isEs ? 'Cámara' : 'Câmera',
                    dark: widget.dark,
                    theme: theme,
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                  const Spacer(),

                  // Enviar
                  GestureDetector(
                    onTap: _canSubmit ? _submit : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: _canSubmit
                            ? const LinearGradient(
                                colors: [Color(0xFF0D6B57), Color(0xFF0D6B57)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color:
                            _canSubmit ? null : theme.border.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _canSubmit
                            ? [
                                BoxShadow(
                                  color:
                                      const Color(0xFF0D6B57).withOpacity(0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : [],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.send_rounded,
                            size: 15, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          isEs ? 'Analizar' : 'Analisar',
                          style: TextStyle(
                            fontSize: MedTypography.auxiliarySize,
                            fontWeight: FontWeight.w700,
                            color:
                                _canSubmit ? Colors.white : theme.textSecondary,
                          ),
                        ),
                      ]),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Botão de anexar ────────────────────────────────────────────────────────
class _AttachBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool dark;
  final InternacionTheme theme;
  final VoidCallback onTap;

  const _AttachBtn({
    required this.icon,
    required this.label,
    required this.dark,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.border, width: 0.9),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: InternacionTheme.cyan),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                fontSize: MedTypography.sectionLabelSize,
                fontWeight: FontWeight.w600,
                color: theme.textPrimary,
              )),
        ]),
      ),
    );
  }
}

// ── Thumbnail de imagem anexada ────────────────────────────────────────────
class _AttachmentThumbnail extends StatelessWidget {
  final _ImageAttachment attachment;
  final bool dark;
  final InternacionTheme theme;
  final VoidCallback onRemove;

  const _AttachmentThumbnail({
    required this.attachment,
    required this.dark,
    required this.theme,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              attachment.bytes,
              width: 68,
              height: 68,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 68,
                height: 68,
                color: theme.card,
                child: const Icon(Icons.insert_drive_file_rounded,
                    color: InternacionTheme.cyan),
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 11, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
