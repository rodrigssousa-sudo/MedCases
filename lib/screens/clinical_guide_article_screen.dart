// MEDCASES_PRODUCTIVE_SECOND_BRAND_B1_V2_R1_GUIDE_ARTICLE
import 'package:flutter/material.dart';

import '../models/clinical_guide_article.dart';

class ClinicalGuideArticleScreen extends StatelessWidget {
  const ClinicalGuideArticleScreen({
    super.key,
    required this.guide,
    required this.lang,
  });

  final ClinicalGuideArticle guide;
  final String lang;

  bool get _isEs => lang.toLowerCase() == 'es';

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? const Color(0xFF1A1D23) : const Color(0xFFF4F7FA);
    final surface = dark ? const Color(0xFF252930) : Colors.white;
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF18202A);
    final secondary = dark ? const Color(0xFF9AA7B7) : const Color(0xFF64748B);
    final divider = dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _ArticleTopBar(
              title: _isEs ? 'Guía clínica' : 'Guia clínico',
              dark: dark,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (guide.heroImageUrl.isNotEmpty)
                          _HeroImage(url: guide.heroImageUrl),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            20,
                            20,
                            20,
                            0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SpecialtyChip(
                                label: guide.specialty,
                                dark: dark,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                guide.title,
                                style: TextStyle(
                                  color: text,
                                  fontSize: 28,
                                  height: 1.12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              if (guide.subtitle.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  guide.subtitle,
                                  style: TextStyle(
                                    color: secondary,
                                    fontSize: 17,
                                    height: 1.38,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                              if (guide.authors.isNotEmpty ||
                                  guide.year.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Text(
                                  [
                                    guide.authors,
                                    guide.year,
                                  ]
                                      .where((value) => value.isNotEmpty)
                                      .join(' · '),
                                  style: TextStyle(
                                    color: secondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              if (guide.summary.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: surface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: divider,
                                      width: 0.7,
                                    ),
                                  ),
                                  child: Text(
                                    guide.summary,
                                    style: TextStyle(
                                      color: text,
                                      fontSize: 16,
                                      height: 1.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 22),
                              if (guide.bodyBlocks.isEmpty)
                                _LegacyGuideNotice(
                                  isEs: _isEs,
                                  text: secondary,
                                  surface: surface,
                                  divider: divider,
                                )
                              else
                                ...guide.bodyBlocks.map(
                                  (block) => _GuideBlockView(
                                    block: block,
                                    dark: dark,
                                    text: text,
                                    secondary: secondary,
                                    surface: surface,
                                    divider: divider,
                                  ),
                                ),
                              if (guide.references.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                Divider(
                                  height: 1,
                                  thickness: 0.7,
                                  color: divider,
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  _isEs ? 'Referencias' : 'Referências',
                                  style: TextStyle(
                                    color: text,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ...guide.references.indexed.map(
                                  (entry) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      '${entry.$1 + 1}. ${entry.$2}',
                                      style: TextStyle(
                                        color: secondary,
                                        fontSize: 13,
                                        height: 1.45,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              if (guide.pdfUrl.isNotEmpty) ...[
                                const SizedBox(height: 22),
                                Text(
                                  _isEs
                                      ? 'Documento original disponible como referencia.'
                                      : 'Documento original disponível como referência.',
                                  style: TextStyle(
                                    color: secondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticleTopBar extends StatelessWidget {
  const _ArticleTopBar({
    required this.title,
    required this.dark,
    required this.onBack,
  });

  final String title;
  final bool dark;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final text = dark ? Colors.white : const Color(0xFF18202A);
    final divider = dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);

    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        color: dark
            ? const Color(0xFF1A1D23).withOpacity(0.92)
            : Colors.white.withOpacity(0.92),
        border: Border(
          bottom: BorderSide(
            color: divider,
            width: 0.7,
          ),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 8,
            top: 6,
            child: SizedBox(
              width: 36,
              height: 36,
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: onBack,
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: text,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 52),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFFE8EDF1),
          alignment: Alignment.center,
          child: const Icon(
            Icons.image_not_supported_outlined,
            size: 28,
            color: Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}

class _SpecialtyChip extends StatelessWidget {
  const _SpecialtyChip({
    required this.label,
    required this.dark,
  });

  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final normalized = label.trim().isEmpty ? 'Geral' : label.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF123B30) : const Color(0xFFE8F8F2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 6,
        ),
        child: Text(
          normalized.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF0D6B57),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
          ),
        ),
      ),
    );
  }
}

class _GuideBlockView extends StatelessWidget {
  const _GuideBlockView({
    required this.block,
    required this.dark,
    required this.text,
    required this.secondary,
    required this.surface,
    required this.divider,
  });

  final ClinicalGuideBlock block;
  final bool dark;
  final Color text;
  final Color secondary;
  final Color surface;
  final Color divider;

  @override
  Widget build(BuildContext context) {
    final type = block.type.trim().toLowerCase();

    if (type == 'heading' || type == 'section') {
      final value = block.title.isNotEmpty ? block.title : block.text;
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 10),
        child: Text(
          value,
          style: TextStyle(
            color: text,
            fontSize: 20,
            height: 1.22,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    if (type == 'bullets' || type == 'bulletlist' || type == 'list') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (block.title.isNotEmpty) ...[
              Text(
                block.title,
                style: TextStyle(
                  color: text,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
            ],
            ...block.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: SizedBox(
                        width: 5,
                        height: 5,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFF0D6B57),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          color: text,
                          fontSize: 15,
                          height: 1.48,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (type == 'callout' || type == 'warning' || type == 'note') {
      return Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: divider,
            width: 0.7,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (block.title.isNotEmpty) ...[
              Text(
                block.title,
                style: const TextStyle(
                  color: Color(0xFF0D6B57),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
            ],
            Text(
              block.text,
              style: TextStyle(
                color: text,
                fontSize: 15,
                height: 1.48,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (block.title.isNotEmpty) ...[
            Text(
              block.title,
              style: TextStyle(
                color: text,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
          ],
          SelectableText(
            block.text,
            style: TextStyle(
              color: text,
              fontSize: 15,
              height: 1.52,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegacyGuideNotice extends StatelessWidget {
  const _LegacyGuideNotice({
    required this.isEs,
    required this.text,
    required this.surface,
    required this.divider,
  });

  final bool isEs;
  final Color text;
  final Color surface;
  final Color divider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: divider,
          width: 0.7,
        ),
      ),
      child: Text(
        isEs
            ? 'Este documento aún no tiene contenido editorial estructurado. '
                'Se mantiene disponible como guía heredada durante la migración.'
            : 'Este documento ainda não possui conteúdo editorial estruturado. '
                'Ele permanece disponível como guia legado durante a migração.',
        style: TextStyle(
          color: text,
          fontSize: 14,
          height: 1.45,
        ),
      ),
    );
  }
}
