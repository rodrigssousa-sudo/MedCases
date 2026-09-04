class _HistorialCompactCard extends StatefulWidget {
  final bool dark;
  final bool isEs;
  final Function(String) openProtocol;
  final VoidCallback onOpenNotes;
  final VoidCallback? onCheckUpdate;

  const _HistorialCompactCard({
    required this.dark,
    required this.isEs,
    required this.openProtocol,
    required this.onOpenNotes,
    this.onCheckUpdate,
  });

  @override
  State<_HistorialCompactCard> createState() => _HistorialCompactCardState();
}
