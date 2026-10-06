import 'package:shared_preferences/shared_preferences.dart';
import '../services/canonical_catalog_cipher.dart';
// MEDCASES_PRODUCTIVE_SECOND_BRAND_BATCH_3A_V2_B_R1_GENERIC_CONTEXTS
// clinical_recorder_sheet.dart
//
// Gravador Clínico Inteligente Multimodal — MedCases Pro Build 331+
//
// Fluxo completo em 4 fases:
//   Fase 0 — FlowSelectionModal: 3 opções de entrada
//   Fase 1 — ClinicalRecorderPage: UI de gravação com texto crescendo em tempo real
//   Fase 2 — SoapReviewPage: revisão dos campos SOAP antes de injetar
//   Fase 3 — OcrScannerPage: OCR de exame (acessível de fora ou dentro do fluxo)
//
// Entry points:
//   ClinicalRecorderSheet.showFlowSelection(context, onManual, onSoapData)
//   ClinicalRecorderSheet.showOcrScanner(context, onResult)
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/clinical_recorder_service.dart';
import '../services/soap_ai_processor.dart';
import 'durable_recording_screen.dart';
import '../services/audio/recording_session_controller.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// ENTRY POINTS ESTÁTICOS
// ═══════════════════════════════════════════════════════════════════════════════
class ClinicalRecorderSheet {
  /// Exibe modal de seleção de fluxo.
  /// [onManual] → usuário escolheu digitar manualmente
  /// [onSoapData] → retorna SoapData após gravar + processar IA
  static Future<void> showFlowSelection(
    BuildContext context, {
    required VoidCallback onManual,
    required void Function(SoapData) onSoapData,
  }) async {
    final lang = context.read<AppProvider>().lang;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FlowSelectionModal(
        lang: lang,
        onManual: onManual,
        onSoapData: onSoapData,
      ),
    );
  }

  // MEDCASES_HC_NEW_HISTORY_WORKSPACE_V1_B_R0_RECORDER_ROUTE_API
  // Reutiliza o _RecorderPage produtivo; não duplica STT, SOAP ou revisão.
  static Future<void> openContinuousRecorder(
    BuildContext context, {
    required void Function(SoapData) onSoapData,
  }) {
    return _openRecorderMode(
      context,
      mode: RecorderMode.continuous,
      onSoapData: onSoapData,
    );
  }

  static Future<void> openSoapBlocksRecorder(
    BuildContext context, {
    required void Function(SoapData) onSoapData,
  }) {
    return _openRecorderMode(
      context,
      mode: RecorderMode.soapBlocks,
      onSoapData: onSoapData,
    );
  }

  static Future<void> _openRecorderMode(
    BuildContext context, {
    required RecorderMode mode,
    required void Function(SoapData) onSoapData,
  }) async {
    final lang = context.read<AppProvider>().lang;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _RecorderPage(
          mode: mode,
          lang: lang,
          onSoapData: onSoapData,
        ),
      ),
    );
  }

  /// Exibe scanner OCR direto.
  /// [onResult] → texto estruturado extraído do exame
  static Future<void> showOcrScanner(
    BuildContext context, {
    required void Function(String) onResult,
  }) async {
    final lang = context.read<AppProvider>().lang;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OcrScannerModal(lang: lang, onResult: onResult),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FASE 0 — Modal de Seleção de Fluxo
// ═══════════════════════════════════════════════════════════════════════════════
class _FlowSelectionModal extends StatelessWidget {
  final String lang;
  final VoidCallback onManual;
  final void Function(SoapData) onSoapData;

  const _FlowSelectionModal({
    required this.lang,
    required this.onManual,
    required this.onSoapData,
  });

  @override
  Widget build(BuildContext context) {
    // MEDCASES_HC_CAPTURE_PREMIUM_CHOOSER_V1_B_R0
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF1A1D23) : const Color(0xFFECF1F3);
    final textColor = dark ? const Color(0xFFF1F5F9) : const Color(0xFF05070A);
    final subColor = dark ? const Color(0xFFA8B2C1) : const Color(0xFF59636E);
    final handleColor =
        dark ? const Color(0xFF4B5563) : const Color(0xFFC7D0D8);
    final media = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: media.size.height * 0.86,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        9,
        16,
        12 + media.padding.bottom + media.viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 3,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: handleColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              lang == 'es' ? 'Nueva Historia Clínica' : 'Nova História Clínica',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.15,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              lang == 'es'
                  ? 'Seleccione cómo desea capturar la historia clínica.'
                  : 'Selecione como deseja capturar a história clínica.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: subColor,
                fontSize: 12.5,
                height: 1.3,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 14),
            _FlowOption(
              iconData: Icons.mic_rounded,
              title: lang == 'es'
                  ? 'Grabar consulta y transcribir todo'
                  : 'Gravar consulta e transcrever tudo',
              subtitle: lang == 'es'
                  ? 'Flujo continuo médico-paciente — IA estructura el SOAP automáticamente'
                  : 'Fluxo contínuo médico-paciente — IA estrutura o SOAP automaticamente',
              showIaBadge: true,
              onTap: () {
                Navigator.pop(context);
                _openRecorder(context, RecorderMode.continuous);
              },
            ),
            const SizedBox(height: 8),
            _FlowOption(
              iconData: Icons.edit_outlined,
              title: lang == 'es'
                  ? 'Completar manualmente'
                  : 'Preencher manualmente',
              subtitle: lang == 'es'
                  ? 'Formulario tradicional con campos SOAP'
                  : 'Formulário tradicional com campos SOAP',
              showIaBadge: false,
              onTap: () {
                Navigator.pop(context);
                onManual();
              },
            ),
            const SizedBox(height: 8),
            _FlowOption(
              iconData: Icons.view_agenda_outlined,
              title: lang == 'es'
                  ? 'Grabar por bloques SOAP'
                  : 'Gravar por blocos SOAP',
              subtitle: lang == 'es'
                  ? 'Dictado segmentado por categoría clínica'
                  : 'Ditado segmentado por categoria clínica',
              showIaBadge: false,
              onTap: () {
                Navigator.pop(context);
                _openRecorder(context, RecorderMode.soapBlocks);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openRecorder(BuildContext context, RecorderMode mode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _RecorderPage(
          mode: mode,
          lang: lang,
          onSoapData: onSoapData,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card de opção de fluxo — Design Apple/Stripe Premium (Build 332+)
// Fundo cinza-escuro uniforme 0xFF1C2232, borda fina 0xFF2C354A 0.5px,
// ícone vetorial 22px, tipografia hierárquica, badge IA discreto.
// ─────────────────────────────────────────────────────────────────────────────
class _FlowOption extends StatelessWidget {
  // LIGHT_MODE_PREMIUM_V1_A_R14_FLOW_OPTION
  final IconData iconData;
  final String title;
  final String subtitle;
  final bool showIaBadge;
  final VoidCallback onTap;

  const _FlowOption({
    required this.iconData,
    required this.title,
    required this.subtitle,
    required this.showIaBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // MEDCASES_HC_CAPTURE_PREMIUM_FLOW_OPTION_V1_B_R0
    final dark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final subtitleColor =
        dark ? const Color(0xFFA8B2C1) : const Color(0xFF64748B);
    final iconColor = showIaBadge
        ? const Color(0xFF0E8000)
        : (dark ? const Color(0xFFD1D5DB) : const Color(0xFF475569));
    final chevronColor =
        dark ? const Color(0xFF7D8794) : const Color(0xFF94A3B8);
    final dividerColor =
        dark ? const Color(0xFF374151) : const Color(0xFFE2E8F0);
    final surfaceColor = showIaBadge
        ? (dark ? const Color(0xFF202A29) : const Color(0xFFF4FAF7))
        : (dark ? const Color(0xFF252930) : Colors.white);
    final borderColor = showIaBadge
        ? const Color(0xFF0E8000).withOpacity(dark ? 0.42 : 0.30)
        : dividerColor;
    final iconSurface = showIaBadge
        ? const Color(0xFF0E8000).withOpacity(dark ? 0.12 : 0.09)
        : (dark ? const Color(0xFF2D3340) : const Color(0xFFEFF2F5));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: const Color(0xFF0E8000).withOpacity(0.08),
        highlightColor: const Color(0xFF0E8000).withOpacity(0.04),
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 10, 9, 10),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: borderColor,
              width: showIaBadge ? 0.8 : 0.7,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(
                  iconData,
                  size: 20,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                              color: titleColor,
                            ),
                          ),
                        ),
                        if (showIaBadge) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0E8000)
                                  .withOpacity(dark ? 0.11 : 0.08),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color:
                                    const Color(0xFF0E8000).withOpacity(0.42),
                                width: 0.7,
                              ),
                            ),
                            child: const Text(
                              'IA',
                              style: TextStyle(
                                color: Color(0xFF0E8000),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.35,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.3,
                        fontWeight: FontWeight.w400,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: chevronColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FASE 1 — Página de Gravação
// ═══════════════════════════════════════════════════════════════════════════════
class _RecorderPage extends StatefulWidget {
  final RecorderMode mode;
  final String lang;
  final void Function(SoapData) onSoapData;

  const _RecorderPage({
    required this.mode,
    required this.lang,
    required this.onSoapData,
  });

  @override
  State<_RecorderPage> createState() => _RecorderPageState();
}

class _RecorderPageState extends State<_RecorderPage> {
  @override
  Widget build(BuildContext context) => DurableRecordingScreen(
      isEs: widget.lang == 'es',
      mode: widget.mode.name,
      onTranscript: (text) async {
        // SOAP is downstream from the durable transcript; failure cannot lose audio.
        try {
          final owner = RecordingSessionController.instance.session?.ownerUid;
          final id = RecordingSessionController.instance.session?.sessionId;
          final soap = await SoapAiProcessor.structure(text, lang: widget.lang);
          if (!context.mounted ||
              owner == null ||
              RecordingSessionController.instance.session?.ownerUid != owner ||
              RecordingSessionController.instance.session?.sessionId != id)
            return;
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => _SoapReviewPage(
                      soap: soap,
                      lang: widget.lang,
                      onConfirm: (confirmed) {
                        if (!context.mounted) return;
                        if (RecordingSessionController
                                    .instance.session?.ownerUid !=
                                owner ||
                            RecordingSessionController
                                    .instance.session?.sessionId !=
                                id) return;
                        Navigator.pop(context);
                        widget.onSoapData(confirmed);
                      })));
        } catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(widget.lang == 'es'
                  ? 'No se pudo estructurar. La transcripción se conserva.'
                  : 'Não foi possível estruturar. A transcrição foi preservada.')));
        }
      });
}

// ═══════════════════════════════════════════════════════════════════════════════
// FASE 2 — Revisão SOAP
// ═══════════════════════════════════════════════════════════════════════════════
class _SoapReviewPage extends StatefulWidget {
  final SoapData soap;
  final String lang;
  final void Function(SoapData) onConfirm;

  const _SoapReviewPage({
    required this.soap,
    required this.lang,
    required this.onConfirm,
  });

  @override
  State<_SoapReviewPage> createState() => _SoapReviewPageState();
}

class _SoapReviewPageState extends State<_SoapReviewPage> {
  late final Map<String, TextEditingController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = {
      'subjective': TextEditingController(text: widget.soap.subjective),
      'objective': TextEditingController(text: widget.soap.objective),
      'assessment': TextEditingController(text: widget.soap.assessment),
      'plan': TextEditingController(text: widget.soap.plan),
      'medications': TextEditingController(text: widget.soap.medications),
      'exams': TextEditingController(text: widget.soap.exams),
    };
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) c.dispose();
    super.dispose();
  }

  void _confirm() {
    final confirmed = SoapData(
      subjective: _ctrls['subjective']!.text.trim(),
      objective: _ctrls['objective']!.text.trim(),
      assessment: _ctrls['assessment']!.text.trim(),
      plan: _ctrls['plan']!.text.trim(),
      medications: _ctrls['medications']!.text.trim(),
      exams: _ctrls['exams']!.text.trim(),
      rawTranscript: widget.soap.rawTranscript,
    );
    widget.onConfirm(confirmed);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF111622) : const Color(0xFFF8FAFC);
    final l = widget.lang;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF111622),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          l == 'es' ? 'Revisar y Confirmar SOAP' : 'Revisar e Confirmar SOAP',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton.icon(
            onPressed: _confirm,
            icon: const Icon(Icons.check_rounded, color: Color(0xFF0D6B57)),
            label: Text(
              l == 'es' ? 'Confirmar' : 'Confirmar',
              style: const TextStyle(
                  color: Color(0xFF0D6B57), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner de info
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Text('✨', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l == 'es'
                        ? 'La IA estructuró la transcripción. Revise y edite los campos antes de confirmar.'
                        : 'A IA estruturou a transcrição. Revise e edite os campos antes de confirmar.',
                    style:
                        const TextStyle(fontSize: 13, color: Color(0xFF818CF8)),
                  ),
                ),
              ],
            ),
          ),
          _SoapField(
              label: '🗣️ ${l == 'es' ? 'Subjetivo' : 'Subjetivo'}',
              ctrl: _ctrls['subjective']!,
              dark: dark),
          _SoapField(
              label: '🩺 ${l == 'es' ? 'Objetivo' : 'Objetivo'}',
              ctrl: _ctrls['objective']!,
              dark: dark),
          _SoapField(
              label: '🧠 ${l == 'es' ? 'Evaluación' : 'Avaliação'}',
              ctrl: _ctrls['assessment']!,
              dark: dark),
          _SoapField(
              label: '📋 ${l == 'es' ? 'Plan' : 'Plano'}',
              ctrl: _ctrls['plan']!,
              dark: dark),
          _SoapField(
              label: '💊 ${l == 'es' ? 'Medicaciones' : 'Medicações'}',
              ctrl: _ctrls['medications']!,
              dark: dark),
          _SoapField(
              label: '🔬 ${l == 'es' ? 'Exámenes' : 'Exames'}',
              ctrl: _ctrls['exams']!,
              dark: dark),
          const SizedBox(height: 16),

          // Transcrição bruta (colapsável)
          if (widget.soap.rawTranscript.isNotEmpty)
            _RawTranscriptCard(
                raw: widget.soap.rawTranscript, dark: dark, lang: l),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D6B57),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.save_rounded),
              label: Text(
                l == 'es'
                    ? 'Confirmar e ingresar al prontuario'
                    : 'Confirmar e inserir no prontuário',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SoapField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool dark;

  const _SoapField(
      {required this.label, required this.ctrl, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1E2330) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dark ? const Color(0xFF2D3340) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: dark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          TextField(
            controller: ctrl,
            maxLines: null,
            minLines: ctrl.text.isEmpty ? 2 : null,
            style: TextStyle(
              fontSize: 14,
              color: dark ? Colors.white : const Color(0xFF111111),
              height: 1.5,
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              border: InputBorder.none,
              hintText: '(vazio — nenhuma informação detectada)',
              hintStyle: TextStyle(
                color: dark ? Colors.grey[600] : Colors.grey[400],
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RawTranscriptCard extends StatefulWidget {
  final String raw;
  final bool dark;
  final String lang;
  const _RawTranscriptCard(
      {required this.raw, required this.dark, required this.lang});

  @override
  State<_RawTranscriptCard> createState() => _RawTranscriptCardState();
}

class _RawTranscriptCardState extends State<_RawTranscriptCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.dark ? const Color(0xFF1E2330) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              widget.dark ? const Color(0xFF2D3340) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Text('📄', style: TextStyle(fontSize: 20)),
            title: Text(
              widget.lang == 'es' ? 'Transcripción bruta' : 'Transcrição bruta',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SelectableText(
                widget.raw,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: widget.dark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FASE 3 — OCR Scanner de Exames
// ═══════════════════════════════════════════════════════════════════════════════
class _OcrScannerModal extends StatefulWidget {
  final String lang;
  final void Function(String) onResult;

  const _OcrScannerModal({required this.lang, required this.onResult});

  @override
  State<_OcrScannerModal> createState() => _OcrScannerModalState();
}

class _OcrScannerModalState extends State<_OcrScannerModal> {
  bool _isProcessing = false;
  String _result = '';
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickAndProcess(ImageSource source) async {
    final provider = context.read<AppProvider>();
    final uid = provider.currentUser?.uid;
    final epoch = provider.sessionEpoch;
    if (uid == null) return;
    bool current() => mounted && provider.isCurrentSession(uid, epoch);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted || !current()) return;
      final consentKey = 'remote_image_consent.v1.${catalogUidHash(uid)}';
      if (prefs.getBool(consentKey) != true) {
        final es = widget.lang == 'es';
        final accepted = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
                  title: Text(es
                      ? 'Procesamiento remoto de imágenes'
                      : 'Processamento remoto de imagens'),
                  content: Text(es
                      ? 'La imagen que seleccione se enviará a la infraestructura remota de MedCases y a proveedores contratados de IA para extraer la información solicitada. ¿Desea continuar?'
                      : 'A imagem selecionada será enviada à infraestrutura remota do MedCases e a fornecedores contratados de IA para extrair as informações solicitadas. Deseja continuar?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: Text(es ? 'Cancelar' : 'Cancelar')),
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: Text(es ? 'Continuar' : 'Continuar')),
                  ],
                ));
        if (!current() || accepted != true) return;
        await prefs.setBool(consentKey, true);
        if (!current()) return;
      }
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (!current() || file == null) return;

      final bytes = await file.readAsBytes();
      if (!current()) return;
      setState(() {
        _isProcessing = true;
        _result = '';
      });

      final text = await SoapAiProcessor.ocrExam(bytes, lang: widget.lang);

      if (!current()) return;
      setState(() {
        _isProcessing = false;
        _result = text;
      });
    } catch (e) {
      if (!current()) return;
      setState(() {
        _isProcessing = false;
        _result = widget.lang == 'es'
            ? 'Error al procesar la imagen.'
            : 'Erro ao processar a imagem.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF1A1D23) : Colors.white;
    final textColor = dark ? Colors.white : const Color(0xFF111111);
    final subColor = dark ? Colors.grey[400]! : Colors.grey[600]!;
    final l = widget.lang;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 8,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: dark ? Colors.grey[700] : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            children: [
              const Text('🔬', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Text(
                l == 'es' ? 'Escanear Examen' : 'Escanear Exame',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: textColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l == 'es'
                ? 'Capture una foto del examen o selecciónela de la galería. La IA extraerá los resultados automáticamente.'
                : 'Tire uma foto do exame ou selecione da galeria. A IA extrairá os resultados automaticamente.',
            style: TextStyle(fontSize: 12, color: subColor),
          ),
          const SizedBox(height: 20),

          if (!_isProcessing && _result.isEmpty) ...[
            _OcrSourceBtn(
              icon: Icons.camera_alt_outlined,
              label: l == 'es' ? 'Tomar foto' : 'Tirar foto',
              subtitle: l == 'es' ? 'Usar la cámara' : 'Usar a câmera',
              onTap: () => _pickAndProcess(ImageSource.camera),
            ),
            const Divider(
              height: 1,
              thickness: 0.6,
              indent: 36,
              color: Color(0xFF374151),
            ),
            _OcrSourceBtn(
              icon: Icons.photo_library_outlined,
              label: l == 'es' ? 'Elegir de la galería' : 'Escolher da galeria',
              subtitle: l == 'es'
                  ? 'Seleccionar una imagen existente'
                  : 'Selecionar imagem existente',
              onTap: () => _pickAndProcess(ImageSource.gallery),
            ),
          ] else if (_isProcessing) ...[
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              l == 'es'
                  ? 'Analizando examen con IA...'
                  : 'Analisando exame com IA...',
              style: TextStyle(color: subColor),
            ),
          ] else ...[
            // Resultado OCR
            Flexible(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:
                      dark ? const Color(0xFF1E2330) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: dark
                        ? const Color(0xFF2D3340)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _result,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: dark ? Colors.white : const Color(0xFF111111),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _result = '';
                    }),
                    icon: const Icon(Icons.refresh_rounded),
                    label:
                        Text(l == 'es' ? 'Nuevo escaneo' : 'Novo escaneamento'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onResult(_result);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D6B57),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check_rounded),
                    label: Text(l == 'es' ? 'Insertar' : 'Inserir'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _OcrSourceBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _OcrSourceBtn({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 21,
                color: const Color(0xFF0D6B57),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE8F0EC),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF8D9A94),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
