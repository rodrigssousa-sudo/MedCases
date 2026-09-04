import 'package:flutter/material.dart';

class RemoteClinicalContentSheet extends StatelessWidget {
  final String title;
  final Map<String, dynamic> content;

  const RemoteClinicalContentSheet({
    super.key,
    required this.title,
    required this.content,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required Map<String, dynamic> content,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => RemoteClinicalContentSheet(
        title: title,
        content: content,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sections = _sections(content);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.42,
      maxChildSize: 0.94,
      builder: (_, controller) {
        return ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (sections.isNotEmpty) const SizedBox(height: 14),
            for (final section in sections) ...[
              _RemoteContentSection(section: section),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _RemoteContentSection extends StatelessWidget {
  final _ContentSection section;

  const _RemoteContentSection({required this.section});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (section.title.isNotEmpty) ...[
            Text(
              section.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
          ],
          for (final row in section.rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (row.label.isNotEmpty) ...[
                    SizedBox(
                      width: 112,
                      child: Text(
                        row.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      row.value,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ContentSection {
  final String title;
  final List<_ContentRow> rows;

  const _ContentSection({
    required this.title,
    required this.rows,
  });
}

class _ContentRow {
  final String label;
  final String value;

  const _ContentRow({
    required this.label,
    required this.value,
  });
}

List<_ContentSection> _sections(Map<String, dynamic> content) {
  final rawSections = content['sections'];

  if (rawSections is List) {
    return rawSections
        .whereType<Map>()
        .map((raw) {
          final map = raw.map(
            (key, value) => MapEntry(key.toString(), value),
          );
          final rows = _rows(map['rows']);
          return _ContentSection(
            title: map['title']?.toString() ?? '',
            rows: rows,
          );
        })
        .where((section) => section.rows.isNotEmpty)
        .toList(growable: false);
  }

  final fallbackRows = <_ContentRow>[];
  for (final entry in content.entries) {
    if (entry.key == 'title' || entry.key == 'sections') continue;
    if (entry.value == null) continue;
    fallbackRows.add(
      _ContentRow(
        label: entry.key,
        value: _displayValue(entry.value),
      ),
    );
  }

  if (fallbackRows.isEmpty) return const <_ContentSection>[];

  return <_ContentSection>[
    _ContentSection(
      title: content['title']?.toString() ?? '',
      rows: fallbackRows,
    ),
  ];
}

List<_ContentRow> _rows(Object? value) {
  if (value is! List) return const <_ContentRow>[];

  return value
      .whereType<Map>()
      .map((raw) {
        final map = raw.map(
          (key, child) => MapEntry(key.toString(), child),
        );
        return _ContentRow(
          label: map['label']?.toString() ?? '',
          value: _displayValue(map['value']),
        );
      })
      .where((row) => row.value.isNotEmpty)
      .toList(growable: false);
}

String _displayValue(Object? value) {
  if (value == null) return '';
  if (value is List) {
    return value.map((item) => item.toString()).join('\n');
  }
  return value.toString();
}
