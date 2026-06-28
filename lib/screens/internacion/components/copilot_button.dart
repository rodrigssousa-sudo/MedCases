// ─────────────────────────────────────────────────────────────────────────────
// CopilotButton — Build 160 — Botão Medcases Inteligente
//
// Botão proeminente que abre bottom sheet multimodal (texto + imagem/PDF).
// Mostra shimmer durante o processamento da IA.
// Após resposta, dispara RevisionSheet (Human-in-the-Loop).
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/soap_copilot_service.dart';
import '../../../services/gemini_service.dart';
import 'internacion_theme.dart';
import 'revision_sheet.dart';

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
  Future<void> _handleSubmit(String text, List<_ImageAttachment> attachments) async {
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              content: Text(isEs
                  ? 'Datos descartados.'
                  : 'Dados descartados.'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;

    return GestureDetector(
      onTap: _isLoading ? null : _openInputSheet,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          gradient: _isLoading
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: _isLoading
              ? (dark ? const Color(0xFF1A1E28) : const Color(0xFFF0F2F5))
              : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isLoading
                ? const Color(0xFF059669).withOpacity(0.40)
                : const Color(0xFF059669).withOpacity(0.60),
            width: 1.5,
          ),
          boxShadow: _isLoading
              ? []
              : [
                  BoxShadow(
                    color: const Color(0xFF059669).withOpacity(0.20),
                    blurRadius: 20,
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
    return Row(
      children: [
        // Ícone animado com gradiente
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF059669), Color(0xFF047857)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.auto_awesome_rounded,
              size: 20, color: Colors.white),
        ),
        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Medcases Inteligente',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
              Text(
                isEs
                    ? 'pegar texto, sube imagen — IA extrae'
                    : 'colar texto, subir imagem — IA extrai',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.70),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF059669).withOpacity(0.20),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF059669).withOpacity(0.50),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_rounded,
                  size: 12, color: Color(0xFF059669)),
              const SizedBox(width: 3),
              const Text('IA', style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF059669),
              )),
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
        return Row(
          children: [
            // Ícone pulsante
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Color(0xFF059669)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shimmer bar 1
                  _shimmerBar(width: 160, height: 14),
                  const SizedBox(height: 6),
                  // Shimmer bar 2
                  _shimmerBar(width: 220, height: 10),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _shimmerBar({required double width, required double height}) {
    final dark = widget.dark;
    final base = dark ? const Color(0xFF2D3340) : const Color(0xFFE0E4EA);
    final highlight = dark ? const Color(0xFF3D4A5A) : const Color(0xFFF5F7FA);

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: AnimatedBuilder(
        animation: _shimmerAnim,
        builder: (_, __) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                (_shimmerAnim.value - 0.3).clamp(0.0, 1.0),
                _shimmerAnim.value.clamp(0.0, 1.0),
                (_shimmerAnim.value + 0.3).clamp(0.0, 1.0),
              ],
              colors: [base, highlight, base],
            ),
          ),
        ),
      ),
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

typedef _OnSubmit = void Function(String text, List<_ImageAttachment> attachments);

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
          content: Text('${isEs ? 'Error al cargar imagen' : 'Erro ao carregar imagem'}: $e'),
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
            color: const Color(0xFF059669).withOpacity(0.30),
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
                    width: 36, height: 4,
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
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF059669), Color(0xFF047857)],
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
                      fontSize: 16, fontWeight: FontWeight.w800,
                      color: theme.textPrimary,
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(
                  isEs
                      ? 'Dicta notas rápidas, pega valores o sube fotos de monitores y labs.'
                      : 'Dite notas rápidas, cole valores ou suba fotos de monitores e labs.',
                  style: TextStyle(fontSize: 12, color: theme.textSecondary, height: 1.4),
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
                      fontSize: 14, color: theme.textPrimary, height: 1.5,
                    ),
                    decoration: InputDecoration(
                      hintText: isEs
                          ? 'Ej: "paciente bien, pa 120/80, sin dor, Hb 10.2, vou manter atb..."'
                          : 'Ex: "paciente bem, pa 120/80, sem dor, Hb 10.2, vou manter atb..."',
                      hintStyle: TextStyle(
                        fontSize: 13, color: theme.textSecondary.withOpacity(0.6),
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
                                colors: [Color(0xFF34D399), Color(0xFF047857)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: _canSubmit
                            ? null
                            : theme.border.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _canSubmit
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF059669)
                                      .withOpacity(0.35),
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
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _canSubmit
                                ? Colors.white
                                : theme.textSecondary,
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
    required this.icon, required this.label, required this.dark,
    required this.theme, required this.onTap,
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
          Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
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
    required this.attachment, required this.dark,
    required this.theme, required this.onRemove,
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
              width: 68, height: 68,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 68, height: 68,
                color: theme.card,
                child: const Icon(Icons.insert_drive_file_rounded,
                    color: InternacionTheme.cyan),
              ),
            ),
          ),
          Positioned(
            top: 2, right: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 18, height: 18,
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
