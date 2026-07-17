import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Bolha do usuário — Build 170
// Long-press → modal de ações: [Copiar Mensaje] [Editar Mensaje]
// Editar: transforma o balão em campo de input inline. Ao salvar,
// apaga o histórico dali em diante e re-dispara o stream com o prompt editado.
// ─────────────────────────────────────────────────────────────────────────────
class UserBubble extends StatefulWidget {
  final String text;
  final bool dark;
  // Build 170: callbacks para copiar e editar
  final VoidCallback? onCopy;
  final void Function(String newText)? onEdit;
  // Fix 5: desabilita ícone de edição durante streaming da IA
  final bool isAiStreaming;
  const UserBubble({
    super.key,
    required this.text,
    required this.dark,
    this.onCopy,
    this.onEdit,
    this.isAiStreaming = false,
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
    _editCtrl = TextEditingController(text: widget.text);
    _editFocus = FocusNode();
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    _editFocus.dispose();
    super.dispose();
  }

  void _startEdit() {
    setState(() {
      _editing = true;
      _editCtrl.text = widget.text;
      _editCtrl.selection =
          TextSelection(baseOffset: 0, extentOffset: widget.text.length);
    });
    // Abre teclado no próximo frame
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _editFocus.requestFocus());
  }

  void _saveEdit() {
    final newText = _editCtrl.text.trim();
    setState(() => _editing = false);
    if (newText.isNotEmpty && newText != widget.text) {
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
    // ── ORDEM VISUAL 04 M2: iOS Flat / Minimalista ────────────────────────────
    // Bolha neutra e suave — não compete com o conteúdo clínico da IA.
    // dark: grafite suave 0xFF2A2D35 / light: cinza gelo 0xFFF0F2F5
    // Sem borda desenhada — bloco sólido de cor plana.
    final bubbleColor =
        widget.dark ? const Color(0xFF2A2D35) : const Color(0xFFF0F2F5);
    final textColor = widget.dark ? Colors.white : const Color(0xFF1A1D23);
    // Cor primária do botão "Enviar" (único elemento de destaque)
    final sendColor =
        widget.dark ? const Color(0xFF00E5FF) : const Color(0xFF008CA4);

    const borderRadius = BorderRadius.only(
      topLeft: Radius.circular(16),
      topRight: Radius.circular(16),
      bottomLeft: Radius.circular(16),
      bottomRight: Radius.circular(4),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Align(
        alignment: Alignment.centerRight,
        child: _editing
            // ── Modo edição inline — paleta flat neutra ────────────────────
            ? Container(
                constraints: const BoxConstraints(maxWidth: 320),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: borderRadius,
                  // Sem borda — bloco sólido flat
                ),
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TextField(
                      controller: _editCtrl,
                      focusNode: _editFocus,
                      maxLines: null,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: textColor,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: _cancelEdit,
                          child: Text(
                            'Cancelar',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: widget.dark
                                    ? Colors.white54
                                    : Colors.black45),
                          ),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: _saveEdit,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: sendColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('Enviar',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            // ── Modo normal — bolha flat sem borda ────────────────────────
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  GestureDetector(
                    onLongPress: () => _showActions(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: borderRadius,
                        color: bubbleColor,
                        // Sem border — design flat puro
                      ),
                      child: Text(widget.text,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: textColor,
                              height: 1.45)),
                    ),
                  ),
                  // Ícone de edição discreto abaixo do balão
                  // Desabilitado e invisível durante streaming/thinking da IA
                  if (!widget.isAiStreaming && widget.onEdit != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3, right: 2),
                      child: GestureDetector(
                        onTap: _startEdit,
                        child: Icon(
                          Icons.edit_outlined,
                          size: 14,
                          color: widget.dark
                              ? Colors.white.withValues(alpha: 0.30)
                              : Colors.black.withValues(alpha: 0.28),
                        ),
                      ),
                    ),
                ],
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
