import 'package:flutter/material.dart';

import '../../../home_v2/theme/home_v2_palette.dart';
// ─────────────────────────────────────────────────────────────────────────────
// Bolha do usuário — Build 170
// Long-press → modal de ações: [Copiar Mensaje] [Editar Mensaje]
// Editar: transforma o balão em campo de input inline. Ao salvar,
// apaga o histórico dali em diante e re-dispara o stream com o prompt editado.
// ─────────────────────────────────────────────────────────────────────────────
class UserBubble extends StatefulWidget {
  final String text;
  /// Canonical text used only by the edit flow.
  ///
  /// When null, editing behaves exactly as before and uses [text].
  /// This lets a user bubble render a compact projection while preserving the
  /// original semantic message for edits/re-send.
  final String? editText;
  final bool dark;
  // Build 170: callbacks para copiar e editar
  final VoidCallback? onCopy;
  final void Function(String newText)? onEdit;
  // Fix 5: desabilita ícone de edição durante streaming da IA
  final bool isAiStreaming;
  final bool cleanPlantaoPresentation;
  const UserBubble({
    super.key,
    required this.text,
    this.editText,
    required this.dark,
    this.onCopy,
    this.onEdit,
    this.isAiStreaming = false,
    this.cleanPlantaoPresentation = false,
  });

  @override
  State<UserBubble> createState() => _UserBubbleState();
}

class _UserBubbleState extends State<UserBubble> {
  bool _editing = false;
  late final TextEditingController _editCtrl;
  late final FocusNode _editFocus;

  @override
  void initState() {
    super.initState();
    _editCtrl = TextEditingController(
      text: widget.editText ?? widget.text,
    );
    _editFocus = FocusNode();
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    _editFocus.dispose();
    super.dispose();
  }

  void _startEdit() {
    final editableText = widget.editText ?? widget.text;
    setState(() {
      _editing = true;
      _editCtrl.text = editableText;
      _editCtrl.selection =
          TextSelection(baseOffset: 0, extentOffset: editableText.length);
    });
    // Abre teclado no próximo frame
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _editFocus.requestFocus());
  }

  void _saveEdit() {
    final newText = _editCtrl.text.trim();
    setState(() => _editing = false);
    final originalEditText = (widget.editText ?? widget.text).trim();
    if (newText.isNotEmpty && newText != originalEditText) {
      widget.onEdit?.call(newText);
    }
  }

  void _cancelEdit() => setState(() => _editing = false);

  void _showActions(BuildContext ctx) {
    final isEs = Localizations.localeOf(ctx).languageCode == 'es';
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _UserBubbleActionsSheet(
        dark: widget.dark,
        isEs: isEs,
        onCopy: () {
          Navigator.pop(sheetContext);
          widget.onCopy?.call();
        },
        onEdit: () {
          Navigator.pop(sheetContext);
          _startEdit();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = HomeV2Palette.resolve(widget.dark);
    final isEs =
        Localizations.localeOf(context).languageCode == 'es';

    final disabledEditColor = palette.textSecondary.withValues(
      alpha: 0.30,
    );

    if (_editing) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            14,
            12,
            10,
            10,
          ),
          decoration: BoxDecoration(
            color: palette.surfaceStrong,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: palette.border,
              width: 0.6,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEs
                    ? 'EDITAR PREGUNTA'
                    : 'EDITAR PERGUNTA',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 10.2,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _editCtrl,
                focusNode: _editFocus,
                minLines: 1,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 13.6,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: isEs
                      ? 'Edita tu pregunta'
                      : 'Edite sua pergunta',
                  hintStyle: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 13.6,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: _cancelEdit,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      child: Text(
                        isEs ? 'Cancelar' : 'Cancelar',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: _saveEdit,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: palette.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Enviar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        12,
        0,
        12,
        28,
      ),
      child: GestureDetector(
        onLongPress: () => _showActions(context),
        behavior: HitTestBehavior.translucent,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.cleanPlantaoPresentation) ...[
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: palette.accent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 11),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!widget.cleanPlantaoPresentation) ...[
                      Text(
                        isEs ? 'PREGUNTA' : 'PERGUNTA',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 10.2,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.25,
                        ),
                      ),
                      const SizedBox(height: 7),
                    ],
                    SelectableText(
                      widget.text,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize:
                            widget.cleanPlantaoPresentation ? 16.0 : 13.6,
                        height:
                            widget.cleanPlantaoPresentation ? 1.38 : 1.45,
                        fontWeight: widget.cleanPlantaoPresentation
                            ? FontWeight.w500
                            : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (
                !widget.isAiStreaming &&
                widget.onEdit != null
              )
                Padding(
                  padding: const EdgeInsets.only(
                    top: 2,
                    left: 8,
                  ),
                  child: GestureDetector(
                    onTap: _startEdit,
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: Icon(
                        Icons.edit_outlined,
                        size: 15,
                        color: disabledEditColor,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _UserBubbleActionsSheet — Build 170
// Modal de ações ao pressionar longo o balão do usuário.
// ─────────────────────────────────────────────────────────────────────────────
class _UserBubbleActionsSheet extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final VoidCallback onCopy;
  final VoidCallback onEdit;

  const _UserBubbleActionsSheet({
    required this.dark,
    required this.isEs,
    required this.onCopy,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF252930) : Colors.white;
    final textCol = dark ? Colors.white : const Color(0xFF1A1D23);
    final subCol = dark ? Colors.white54 : Colors.black45;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 18),
            decoration: BoxDecoration(
                color: dark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2)),
          ),
          // Copiar
          _ActionTile(
            icon: Icons.copy_rounded,
            label: isEs ? 'Copiar mensaje' : 'Copiar mensagem',
            sub: isEs
                ? 'Copia el texto al portapapeles'
                : 'Copia o texto para a área de transferência',
            textCol: textCol,
            subCol: subCol,
            iconColor: const Color(0xFF008CA4),
            onTap: onCopy,
          ),
          Divider(height: 1, color: dark ? Colors.white12 : Colors.black12),
          // Editar
          _ActionTile(
            icon: Icons.edit_rounded,
            label: isEs ? 'Editar mensaje' : 'Editar mensagem',
            sub: isEs
                ? 'Modifica y reenvía borrando el historial posterior'
                : 'Modifique e reenvie apagando o histórico posterior',
            textCol: textCol,
            subCol: subCol,
            iconColor: const Color(0xFFF59E0B),
            onTap: onEdit,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color textCol;
  final Color subCol;
  final Color iconColor;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.sub,
    required this.textCol,
    required this.subCol,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textCol)),
                const SizedBox(height: 2),
                Text(sub,
                    style:
                        TextStyle(fontSize: 11.5, color: subCol, height: 1.3)),
              ],
            )),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: textCol.withValues(alpha: 0.35)),
          ]),
        ),
      ),
    );
  }
}
