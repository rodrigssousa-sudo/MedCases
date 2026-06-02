// ── lib/widgets/lab_exam_bottom_sheet.dart ───────────────────────────────────
// BottomSheet de entrada para análise de exame laboratorial.
//
// ARQUITETURA DE CONTEXTO (crítico para iOS):
//   ❌ ERRADO: Navigator.pop(context) ANTES da operação → invalida o context,
//      quebra mounted checks, ScaffoldMessenger e Navigator.push no iOS.
//   ✅ CORRETO: sheet permanece aberto durante toda a operação; loading overlay
//      cobre o conteúdo; sheet só fecha via Navigator.pushReplacement ao
//      navegar para LabReviewScreen, ou o usuário fecha em caso de erro.
//
// Permissões (Apple Guideline 5.1):
//   - Câmera: Permission.camera.request() — dialog no idioma do sistema iOS
//     (NSCameraUsageDescription em Info.plist)
//   - Galeria: Permission.photos.request() — dialog no idioma do sistema iOS
//     (NSPhotoLibraryUsageDescription em Info.plist)
//   - Textos dos diálogos IN-APP (negado/permanentemente negado) seguem
//     o locale passado ao widget ('pt' ou 'es').
//
// Integração: image_picker ^1.1.2 + permission_handler ^11.3.1 + file_picker 8.1.7
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/lab_result_model.dart';
import '../screens/lab_review_screen.dart';
import '../services/lab_parser_service.dart';
import '../services/gemini_service.dart';

// ── Paleta local (dark-first) ─────────────────────────────────────────────────
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
/// [locale]: 'pt' ou 'es' — controla idioma de todos os textos e prompts.
void showAnalyzeExamBottomSheet(BuildContext context, String locale) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: true,
    enableDrag: true,
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
  bool   _loading      = false;
  String _loadingMsg   = '';
  final  _textCtrl     = TextEditingController();
  bool   _showTextInput = false;

  bool get _isEs => widget.locale.toLowerCase() == 'es';

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  // ── Handlers de cada opção ──────────────────────────────────────────────────
  //
  // REGRA FUNDAMENTAL: NÃO chamar Navigator.pop(context) antes da operação.
  // O sheet fica aberto mostrando o loading overlay durante o processamento.
  // Só fecha ao navegar para LabReviewScreen (pushReplacement) ou em erro.

  /// Câmera — nativo: pede permissão → image_picker | web: file_picker
  Future<void> _onCamera() async {
    if (_loading) return;

    if (kIsWeb) {
      // Web: file_picker abre o seletor nativo do browser
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (!mounted) return;
      if (result == null || result.files.isEmpty) return;
      final bytes = result.files.first.bytes;
      if (bytes == null) return;
      await _analyzeImage(bytes, _guessMime(result.files.first.name));
      return;
    }

    // Nativo: solicitar permissão de câmera
    // O iOS exibe o diálogo nativo com NSCameraUsageDescription no idioma
    // configurado pelo sistema — não é controlado pelo app.
    final status = await Permission.camera.request();
    if (!mounted) return;

    if (status.isGranted) {
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

    } else if (status.isPermanentlyDenied) {
      _showPermissionDeniedDialog(isCamera: true);

    } else {
      // Negado desta vez
      _showError(_isEs
          ? 'Se necesita acceso a la cámara para fotografiar el examen.'
          : 'É necessário acesso à câmera para fotografar o exame.');
    }
  }

  /// Galeria — nativo: pede permissão → image_picker | web: file_picker
  Future<void> _onGallery() async {
    if (_loading) return;

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
      return;
    }

    // Nativo: PHPickerViewController (iOS 14+) — isLimited = acesso parcial ok
    final status = await Permission.photos.request();
    if (!mounted) return;

    if (status.isGranted || status.isLimited) {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (!mounted) return;
      if (image == null) return;
      final bytes = await image.readAsBytes();
      await _analyzeImage(bytes, _guessMime(image.name));

    } else if (status.isPermanentlyDenied) {
      _showPermissionDeniedDialog(isCamera: false);

    } else {
      _showError(_isEs
          ? 'Se necesita acceso a la galería para seleccionar el examen.'
          : 'É necessário acesso à galeria para selecionar o exame.');
    }
  }

  /// PDF — file_picker em todas as plataformas (não requer permissão extra)
  Future<void> _onPdf() async {
    if (_loading) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (!mounted) return;
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) {
      _showError(_isEs
          ? 'No se pudo leer el PDF. Intente de nuevo.'
          : 'Não foi possível ler o PDF. Tente novamente.');
      return;
    }

    await _analyzePdf(bytes);
  }

  /// Colar texto — expande/recolhe o campo inline
  void _onPasteText() {
    if (_loading) return;
    setState(() => _showTextInput = !_showTextInput);
  }

  Future<void> _submitText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    await _analyzeText(text);
  }

  // ── Chamadas ao LabParserService ────────────────────────────────────────────

  Future<void> _analyzeImage(Uint8List bytes, String mime) async {
    if (!_checkConnected()) return;
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
      _stopLoading();
      _showError(e.message);
    } catch (_) {
      _stopLoading();
      _showError(_isEs
          ? 'Error inesperado. Intente de nuevo.'
          : 'Erro inesperado. Tente novamente.');
    }
  }

  Future<void> _analyzePdf(Uint8List bytes) async {
    if (!_checkConnected()) return;
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
      _stopLoading();
      _showError(e.message);
    } catch (_) {
      _stopLoading();
      _showError(_isEs
          ? 'Error inesperado. Intente de nuevo.'
          : 'Erro inesperado. Tente novamente.');
    }
  }

  Future<void> _analyzeText(String text) async {
    if (!_checkConnected()) return;
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
      _stopLoading();
      _showError(e.message);
    } catch (_) {
      _stopLoading();
      _showError(_isEs
          ? 'Error inesperado. Intente de nuevo.'
          : 'Erro inesperado. Tente novamente.');
    }
  }

  // ── Navegação ───────────────────────────────────────────────────────────────

  void _goToReview(List<LabResult> results) {
    if (!mounted) return;
    if (results.isEmpty) {
      _stopLoading();
      _showError(_isEs
          ? 'No se identificaron parámetros laboratoriales en el material enviado.'
          : 'Nenhum parâmetro laboratorial identificado no material enviado.');
      return;
    }
    // Fecha o sheet e navega — pushReplacement preserva o contexto pai
    Navigator.of(context).pop();
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

  // ── Helpers de estado ───────────────────────────────────────────────────────

  bool _checkConnected() {
    if (!GeminiService.hasApiKey) {
      _showError(_isEs
          ? 'Conecta tu cuenta Google en el menú lateral para usar esta función.'
          : 'Conecte sua conta Google no menu lateral para usar esta função.');
      return false;
    }
    return true;
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

  // ── Diálogo de permissão permanentemente negada ─────────────────────────────
  // Textos no idioma do usuário (locale passado ao widget).
  void _showPermissionDeniedDialog({required bool isCamera}) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF101614),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(
            isCamera ? Icons.camera_alt_rounded : Icons.photo_library_rounded,
            color: _C.amber, size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isEs
                  ? (isCamera ? 'Acceso a la Cámara' : 'Acceso a la Galería')
                  : (isCamera ? 'Acesso à Câmera'    : 'Acesso à Galeria'),
              style: const TextStyle(
                color: _C.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ]),
        content: Text(
          _isEs
              ? (isCamera
                  ? 'MedCases Pro necesita acceso a la cámara para fotografiar '
                    'exámenes clínicos. Toque "Configuración" para habilitar el permiso.'
                  : 'MedCases Pro necesita acceso a la galería para importar '
                    'imágenes de exámenes. Toque "Configuración" para habilitar el permiso.')
              : (isCamera
                  ? 'O MedCases Pro precisa de acesso à câmera para fotografar '
                    'exames clínicos. Toque em "Configurações" para habilitar a permissão.'
                  : 'O MedCases Pro precisa de acesso à galeria para importar '
                    'imagens de exames. Toque em "Configurações" para habilitar a permissão.'),
          style: const TextStyle(color: _C.textSec, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              _isEs ? 'Cancelar' : 'Cancelar',
              style: const TextStyle(color: _C.textSec),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings(); // abre Ajustes do iOS direto na tela do app
            },
            child: Text(
              _isEs ? 'Configuración' : 'Configurações',
              style: const TextStyle(
                color: _C.green, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
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
          label: 'OK',
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

  // ── Build ───────────────────────────────────────────────────────────────────

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
          // ── Conteúdo principal ───────────────────────────────────────────
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
                    onTap: _loading ? null : _onCamera,
                  ),
                  _OptionTile(
                    icon: Icons.image_rounded,
                    title: isEs
                        ? 'Enviar Imagen / Screenshot'
                        : 'Enviar Imagem / Screenshot',
                    subtitle: isEs
                        ? 'Seleccionar archivo desde la galería'
                        : 'Escolher arquivo direto da galeria',
                    onTap: _loading ? null : _onGallery,
                  ),
                  _OptionTile(
                    icon: Icons.picture_as_pdf_rounded,
                    title: isEs ? 'Enviar PDF' : 'Enviar PDF',
                    subtitle: isEs
                        ? 'Procesar laudo digital integrado'
                        : 'Processar laudo digital integrado',
                    onTap: _loading ? null : _onPdf,
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
                    onTap: _loading ? null : _onPasteText,
                  ),

                  // Campo de texto expansível
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    child: _showTextInput
                        ? _TextInputPanel(
                            controller: _textCtrl,
                            isEs: isEs,
                            onSubmit: _loading ? () {} : _submitText,
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

          // ── Loading overlay ──────────────────────────────────────────────
          if (_loading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.80),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 40, height: 40,
                      child: CircularProgressIndicator(
                        color: _C.green,
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _loadingMsg,
                      style: const TextStyle(
                        color: _C.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
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
        child: Text(text,
          style: const TextStyle(color: _C.textSec, fontSize: 12)),
      ),
    ]);
  }
}

// ── Tile de opção ──────────────────────────────────────────────────────────────
class _OptionTile extends StatelessWidget {
  final IconData       icon;
  final String         title;
  final String         subtitle;
  final VoidCallback?  onTap;      // nullable → desabilitado durante loading
  final Widget?        trailing;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
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
          child: Opacity(
            opacity: disabled ? 0.45 : 1.0,
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
                      Text(title,
                        style: const TextStyle(
                          color: _C.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        )),
                      const SizedBox(height: 1),
                      Text(subtitle,
                        style: const TextStyle(
                          color: _C.textSec,
                          fontSize: 12,
                        )),
                    ],
                  ),
                ),
                trailing ??
                    const Icon(Icons.chevron_right_rounded,
                        color: _C.textSec, size: 20),
              ]),
            ),
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
        border: Border.all(color: _C.amber.withValues(alpha: 0.30)),
      ),
      child: Row(children: [
        const Icon(Icons.link_off_rounded, color: _C.amber, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            isEs
                ? 'IA no conectada. Ve al menú lateral → "Conectar IA" para '
                  'activar la extracción automática.'
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
