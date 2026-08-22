import 'package:flutter/material.dart';

import '../../../services/ai/ai_finalization_transaction.dart' show AiSessionSummary;

class ChatHistorySheet extends StatelessWidget {
  // sessions is passed from the Selector builder — no manual param tracking.
  final List<AiSessionSummary> sessions;
  final bool dark;
  final String lang;
  final void Function(AiSessionSummary) onRestoreSummary;
  final Future<bool> Function(AiSessionSummary) onDelete;

  const ChatHistorySheet({
    super.key,
    required this.sessions,
    required this.dark,
    required this.lang,
    required this.onRestoreSummary,
    required this.onDelete,
  });

  String _formatDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    return '$day/$month/${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF1A1D23) : Colors.white;
    final textP = dark ? Colors.white : const Color(0xFF1A1D23);
    final textS = dark ? Colors.white54 : Colors.black45;
    final divC = dark ? Colors.white10 : const Color(0xFFEEEEEE);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 4),
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: dark ? Colors.white24 : Colors.black12,
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFF10B981).withOpacity(0.15),
              ),
              child: const Icon(Icons.history_rounded,
                  size: 16, color: Color(0xFF10B981)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                lang == 'es'
                    ? 'Historial de consultas'
                    : 'Histórico de consultas',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: textP,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dark ? Colors.white10 : Colors.black.withOpacity(0.06),
                ),
                child: Icon(Icons.close_rounded, size: 16, color: textS),
              ),
            ),
          ]),
        ),

        // Divisor
        Container(
            height: 1, color: divC, margin: const EdgeInsets.only(bottom: 4)),

        // Lista de sessões — driven by Selector<AppProvider, List<AiSessionSummary>>
        sessions.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(40),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.chat_bubble_outline_rounded,
                      size: 40, color: dark ? Colors.white24 : Colors.black26),
                  const SizedBox(height: 12),
                  Text(
                    lang == 'es'
                        ? 'Aún no hay consultas guardadas.\nInicia un "Nuevo Chat" para crear una sesión.'
                        : 'Nenhuma consulta salva ainda.\nInicie um "Novo Chat" para criar uma sessão.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: textS, height: 1.5),
                  ),
                ]),
              )
            : Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 20),
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) => Container(
                      height: 1,
                      color: divC,
                      margin: const EdgeInsets.symmetric(horizontal: 18)),
                  itemBuilder: (context, i) {
                    final s = sessions[i];
                    // Identidade visual única do histórico MedCases.
                    const brandColor = Color(0xFF10B981);
                    // Date from millisecond epoch.
                    final updatedDt =
                        DateTime.fromMillisecondsSinceEpoch(s.updatedAt)
                            .toLocal();
                    return Dismissible(
                      key: ValueKey(s.sessionId),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: const Color(0xFFCC2222).withOpacity(0.1),
                        child: const Icon(Icons.delete_outline_rounded,
                            color: Color(0xFFCC2222), size: 22),
                      ),
                      confirmDismiss: (_) => onDelete(s),
                      child: InkWell(
                        onTap: () => onRestoreSummary(s),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          child: Row(children: [
                            // Session icon with source-coloured index badge.
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: brandColor.withOpacity(0.1),
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: brandColor),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.title.isNotEmpty ? s.title : '(sem resumo)',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: textP,
                                      height: 1.3),
                                ),
                                const SizedBox(height: 3),
                                Row(children: [
                                  Text(
                                    'M+',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: brandColor,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '/',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: textS,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    _formatDate(updatedDt),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: textS,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '/',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: textS,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    _formatTime(updatedDt),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: textS,
                                    ),
                                  ),
                                ]),
                              ],
                            )),
                            const SizedBox(width: 8),
                            Icon(Icons.chevron_right_rounded,
                                size: 18, color: textS),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ]),
    );
  }
}
