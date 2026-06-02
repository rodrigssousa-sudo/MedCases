// ── lib/widgets/lab_exam_bottom_sheet.dart ───────────────────────────────────
// BottomSheet de entrada para análise de exame laboratorial.
//
// Opções de entrada:
//   1. Tirar foto (câmera) — via file_picker com FileType.image
//   2. Enviar imagem/screenshot — via file_picker com FileType.image
//   3. Enviar PDF — via file_picker com FileType.custom (.pdf)
//   4. Colar/digitar texto do exame — TextField inline ou nova tela
//
// Fluxo após seleção:
//   → Mostra loading overlay com mensagem contextual
//   → Chama LabParserService (text/image/pdf)
//   → Navega para LabReviewScreen com os resultados
//   → Em caso de erro: SnackBar com mensagem bilíngue + botão de retry
//
// Integração: usa file_picker 8.1.7 (já presente no pubspec.yaml).
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../models/lab_result_model.dart';
import '../screens/lab_review_screen.dart';
import '../services/lab_parser_service.dart';
import '../services/gemini_service.dart';

// ── Paleta local (dark-first, alinhada ao design system) ──────────────────────

class _C {
  static const bg          = Color(0xFF101614);
  static const surface     = Color(0xFF17211D);
  static const green       = Color(0xFF46E28C);
  // ignore: unused_field
  static const greenDark   = Color(0xFF1F6B48);
  static const amber       = Color(0xFFF59E0B);
  static const amberBg     = Color(0x1DF59E0B);
  static const border      = Color(0x1AFFFFFF);
  static const textPrimary = Color(0xFFEEF2EE);
  static const textSec     = Color(0xFF7A9486);
  static const red         = Color(0xFFEF4444);
}

// ── Entry point público ────────────────────────────────────────────────────────

/// Abre o menu de opções de análise de exame laboratorial.
///
/// [locale]: 'pt' ou 'es' — controla idioma de todos os textos e do prompt Gemini.
void showAnalyzeExamBottomSheet(BuildContext context, String locale) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AnalyzeExamSheet(locale: locale),
  );
}

// ── Sheet principal ────────────────────────────────────────────────────────────

class _AnalyzeExamSheet extends StatefulWidget {
  final String locale;
  const _AnalyzeExamSheet({required this.locale});

  @override
  State<_AnalyzeExamSheet> createState() => _AnalyzeExamSheetState();
}

class _AnalyzeExamSheetState extends State<_AnalyzeExamSheet> {
  bool _loading      = false;
  String _loadingMsg = '';
  final _textCtrl = TextEditingController();
  bool _showTextInput = false;

  bool get _isEs => widget.locale.toLowerCase() == 'es';

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  // ── Handlers de cada opção ────────────────────────────────────────────────

  /// Câmera:
  ///   - Nativo (iOS/Android): image_picker → câmera real com permissão declarada
  ///   - Web: file_picker → seletor de arquivo (browser não tem câmera via FilePicker)
  Future<void> _onCamera() async {
    Navigator.pop(context);
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    if (kIsWeb) {
      // Web: abre galeria/arquivo do browser
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (!mounted) return;
      if (result == null || result.files.isEmpty) return;
      final bytes = result.files.first.bytes;
      if (bytes == null) return;
      await _analyzeImage(bytes, _guessMime(result.files.first.name));
    } else {
      // Nativo: image_picker abre câmera com NSCameraUsageDescription declarada
      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (!mounted) return;
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      await _analyzeImage(bytes, _guessMime(photo.name));
    }
  }

  /// Galeria / Screenshot:
  ///   - Nativo: image_picker → galeria com NSPhotoLibraryUsageDescription
  ///   - Web: file_picker → seletor nativo do browser
  Future<void> _onGallery() async {
    Navigator.pop(context);
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    if (kIsWeb) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (!mounted) return;
      if (result == null || result.files.isEmpty) return;
      final bytes = result.files.first.bytes;
      if (bytes == null) return;
      await _analyzeImage(bytes, _guessMime(result.files.first.name));
    } else {
      // Nativo: image_picker usa PHPickerViewController (iOS 14+)
      // sem exibir o sheet nativo sobreposto do FilePicker
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (!mounted) return;
      if (image == null) return;
      final bytes = await image.readAsBytes();
      await _analyzeImage(bytes, _guessMime(image.name));
    }
  }

  /// PDF
  Future<void> _onPdf() async {
    Navigator.pop(context);
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (!mounted) return;
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    await _analyzePdf(bytes);
  }

  /// Colar texto — expande o campo inline ou envia se já tiver texto
  void _onPasteText() {
    setState(() => _showTextInput = !_showTextInput);
  }

  Future<void> _submitText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    Navigator.pop(context);
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    await _analyzeText(text);
  }

  // ── Chamadas ao LabParserService ──────────────────────────────────────────

  Future<void> _analyzeImage(Uint8List bytes, String mime) async {
    _assertConnected();
    _startLoading(_isEs
        ? 'Analizando imagen del examen...'
        : 'Analisando imagem do exame...');
    try {
      final results = await LabParserService.parseImage(
        bytes,
        locale: widget.locale,
        mimeType: mime,
      );
      _goToReview(results);
    } on LabParseException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError(_isEs
          ? 'Error inesperado. Intente de nuevo.'
          : 'Erro inesperado. Tente novamente.');
    } finally {
      _stopLoading();
    }
  }

  Future<void> _analyzePdf(Uint8List bytes) async {
    _assertConnected();
    _startLoading(_isEs
        ? 'Procesando PDF del examen...'
        : 'Processando PDF do exame...');
    try {
      final results = await LabParserService.parsePdf(
        bytes,
        locale: widget.locale,
      );
      _goToReview(results);
    } on LabParseException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError(_isEs
          ? 'Error inesperado. Intente de nuevo.'
          : 'Erro inesperado. Tente novamente.');
    } finally {
      _stopLoading();
    }
  }

  Future<void> _analyzeText(String text) async {
    _assertConnected();
    _startLoading(_isEs
        ? 'Extrayendo parámetros del texto...'
        : 'Extraindo parâmetros do texto...');
    try {
      final results = await LabParserService.parseText(
        text,
        locale: widget.locale,
      );
      _goToReview(results);
    } on LabParseException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError(_isEs
          ? 'Error inesperado. Intente de nuevo.'
          : 'Erro inesperado. Tente novamente.');
    } finally {
      _stopLoading();
    }
  }

  // ── Navegação ─────────────────────────────────────────────────────────────

  void _goToReview(List<LabResult> results) {
    if (!mounted) return;
    if (results.isEmpty) {
      _showError(_isEs
          ? 'No se identificaron parámetros laboratoriales en el material enviado.'
          : 'Nenhum parâmetro laboratorial identificado no material enviado.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LabReviewScreen(
          initialResults: results,
          locale: widget.locale,
        ),
      ),
    );
  }

  // ── Helpers de estado ──────────────────────────────────────────────────────

  void _assertConnected() {
    if (!GeminiService.hasApiKey) {
      throw LabParseException(_isEs
          ? 'Conecta tu cuenta Google en el menú lateral para usar esta función.'
          : 'Conecte sua conta Google no menu lateral para usar esta função.');
    }
  }

  void _startLoading(String msg) {
    if (!mounted) return;
    setState(() {
      _loading    = true;
      _loadingMsg = msg;
    });
  }

  void _stopLoading() {
    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF251515),
        duration: const Duration(seconds: 5),
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: _C.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFFFB3B3), fontSize: 13),
            ),
          ),
        ]),
        action: SnackBarAction(
          label: _isEs ? 'OK' : 'OK',
          textColor: _C.red,
          onPressed: () {},
        ),
      ));
  }

  static String _guessMime(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    if (ext == 'png')  return 'image/png';
    if (ext == 'webp') return 'image/webp';
    if (ext == 'gif')  return 'image/gif';
    return 'image/jpeg';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEs = _isEs;

    return Container(
      decoration: const BoxDecoration(
        color: _C.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          // ── Conteúdo principal ─────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // Handle
                  Center(
                    child: Container(
                      width: 38, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Título
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEs ? 'Analizar Examen Clínico' : 'Analisar Exame Clínico',
                          style: const TextStyle(
                            color: _C.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          isEs
                              ? 'Extracción automática por IA + revisión manual'
                              : 'Extração automática por IA + revisão manual',
                          style: const TextStyle(
                            color: _C.textSec,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Dicas de uso
                  _TipsCard(isEs: isEs),
                  const SizedBox(height: 14),

                  // Opções
                  _OptionTile(
                    icon: Icons.camera_alt_rounded,
                    title: isEs ? 'Tirar Foto' : 'Tirar Foto',
                    subtitle: isEs
                        ? 'Capturar con la cámara del dispositivo'
                        : 'Capturar usando a câmera do dispositivo',
                    onTap: _onCamera,
                  ),
                  _OptionTile(
                    icon: Icons.image_rounded,
                    title: isEs
                        ? 'Enviar Imagen / Screenshot'
                        : 'Enviar Imagem / Screenshot',
                    subtitle: isEs
                        ? 'Seleccionar archivo desde la galería'
                        : 'Escolher arquivo direto da galeria',
                    onTap: _onGallery,
                  ),
                  _OptionTile(
                    icon: Icons.picture_as_pdf_rounded,
                    title: isEs ? 'Enviar PDF' : 'Enviar PDF',
                    subtitle: isEs
                        ? 'Procesar laudo digital integrado'
                        : 'Processar laudo digital integrado',
                    onTap: _onPdf,
                  ),

                  // Colar texto (expansível)
                  _OptionTile(
                    icon: Icons.text_snippet_rounded,
                    title: isEs
                        ? 'Pegar Texto del Examen'
                        : 'Colar Texto do Exame',
                    subtitle: isEs
                        ? 'Escribir o pegar bloques de texto del laudo'
                        : 'Digitar ou colar blocos de texto do laudo',
                    trailing: Icon(
                      _showTextInput
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: _C.textSec,
                      size: 20,
                    ),
                    onTap: _onPasteText,
                  ),

                  // Campo de texto expansível
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    child: _showTextInput
                        ? _TextInputPanel(
                            controller: _textCtrl,
                            isEs: isEs,
                            onSubmit: _submitText,
                          )
                        : const SizedBox.shrink(),
                  ),

                  // Aviso de conexão se não conectado
                  if (!GeminiService.hasApiKey) ...[
                    const SizedBox(height: 12),
                    _NoApiKeyBanner(isEs: isEs),
                  ],
                ],
              ),
            ),
          ),

          // ── Loading overlay ────────────────────────────────────────────
          if (_loading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 36, height: 36,
                      child: CircularProgressIndicator(
                        color: _C.green,
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _loadingMsg,
                      style: const TextStyle(
                        color: _C.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isEs
                          ? 'Puede tardar hasta 30 segundos...'
                          : 'Pode levar até 30 segundos...',
                      style: const TextStyle(color: _C.textSec, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Card de dicas de captura ───────────────────────────────────────────────────

class _TipsCard extends StatelessWidget {
  final bool isEs;
  const _TipsCard({required this.isEs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        children: [
          _TipRow(
            icon: Icons.lightbulb_outline_rounded,
            text: isEs
                ? 'Use buena iluminación y evite reflejos sobre el papel.'
                : 'Use boa iluminação e evite reflexos sobre o papel.',
          ),
          const SizedBox(height: 6),
          _TipRow(
            icon: Icons.crop_free_rounded,
            text: isEs
                ? 'Encuadre el documento completo con la cámara recta.'
                : 'Enquadre o documento completo mantendo a câmera reta.',
          ),
          const SizedBox(height: 6),
          _TipRow(
            icon: Icons.text_format_rounded,
            text: isEs
                ? 'Para PDF digital, el resultado será más preciso.'
                : 'Para PDF digital, o resultado será mais preciso.',
          ),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TipRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: _C.green),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(color: _C.textSec, fontSize: 12),
        ),
      ),
    ]);
  }
}

// ── Tile de opção ──────────────────────────────────────────────────────────────

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: _C.green.withValues(alpha: 0.08),
          highlightColor: _C.green.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: _C.green.withValues(alpha: 0.10),
                ),
                child: Icon(icon, color: _C.green, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _C.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _C.textSec,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              trailing ??
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _C.textSec,
                    size: 20,
                  ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Painel de entrada de texto ─────────────────────────────────────────────────

class _TextInputPanel extends StatelessWidget {
  final TextEditingController controller;
  final bool isEs;
  final VoidCallback onSubmit;

  const _TextInputPanel({
    required this.controller,
    required this.isEs,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: 7,
          minLines: 4,
          autofocus: true,
          style: const TextStyle(
            color: _C.textPrimary,
            fontSize: 13,
            height: 1.5,
          ),
          decoration: InputDecoration(
            hintText: isEs
                ? 'Pegue aquí el texto del laboratorio...\n\n'
                  'Ejemplo:\n'
                  'Na: 138 mEq/L\n'
                  'K: 4.2 mEq/L\n'
                  'Cr: 1.1 mg/dL\n'
                  'Hb: 12.5 g/dL'
                : 'Cole aqui o texto do laudo...\n\n'
                  'Exemplo:\n'
                  'Na: 138 mEq/L\n'
                  'K: 4,2 mEq/L\n'
                  'Cr: 1,1 mg/dL\n'
                  'Hb: 12,5 g/dL',
            hintStyle: const TextStyle(
              color: _C.textSec,
              fontSize: 12,
              height: 1.5,
            ),
            filled: true,
            fillColor: _C.surface,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.green, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: onSubmit,
          icon: const Icon(Icons.send_rounded, size: 16),
          label: Text(
            isEs ? 'Analizar Texto' : 'Analisar Texto',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _C.green,
            foregroundColor: Colors.black,
            minimumSize: const Size(double.infinity, 46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ── Banner: API key não configurada ───────────────────────────────────────────

class _NoApiKeyBanner extends StatelessWidget {
  final bool isEs;
  const _NoApiKeyBanner({required this.isEs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.amberBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _C.amber.withValues(alpha: 0.30),
        ),
      ),
      child: Row(children: [
        const Icon(Icons.link_off_rounded, color: _C.amber, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            isEs
                ? 'IA no conectada. Ve al menú lateral → "Conectar IA" para activar '
                  'la extracción automática.'
                : 'IA não conectada. Acesse o menu lateral → "Conectar IA" para '
                  'ativar a extração automática.',
            style: const TextStyle(
              color: _C.amber,
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ]),
    );
  }
}
