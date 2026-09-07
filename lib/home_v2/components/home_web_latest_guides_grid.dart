import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/guide_model.dart';
import '../../providers/app_provider.dart';
import '../../screens/clinical_guide_article_screen.dart';
import '../../services/clinical_guides_editorial_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/medcases_webview_screen.dart';

import 'navigation/home_card_transition.dart';

// MEDCASES_WEB_HOME_40_GUIDES_2X2_ROTATING_LATEST10_V1_B_R1
//
// Web-wide Home showcase:
// - canonical pool: 10 most recent published guides (uploadedAt desc)
// - four visible cards in a 2x2 grid
// - deterministic automatic rotation through the full pool
// - card visual language mirrors the mobile editorial guide surface
// - opening happens through the nearest Navigator (the isolated 40% Web pane)
class HomeWebLatestGuidesGrid extends StatefulWidget {
  const HomeWebLatestGuidesGrid({
    required this.dark,
    required this.isEs,
    super.key,
  });

  final bool dark;
  final bool isEs;

  @override
  State<HomeWebLatestGuidesGrid> createState() =>
      _HomeWebLatestGuidesGridState();
}

class _HomeWebLatestGuidesGridState extends State<HomeWebLatestGuidesGrid> {
  static const int _poolLimit = 10;
  static const int _visibleCount = 4;
  static const Duration _rotationInterval = Duration(seconds: 20);
  static const Duration _transitionDuration = Duration(milliseconds: 320);

  List<GuideModel> _guides = const <GuideModel>[];
  Timer? _rotationTimer;
  int _offset = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final cached = await FirestoreService.loadCachedPublishedGuides();
      if (!mounted) return;
      if (cached.isNotEmpty) {
        _applyGuides(cached);
      }

      final remote = await FirestoreService.loadPublishedGuides(
        forceRemote: true,
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      if (remote.isNotEmpty) {
        _applyGuides(remote);
      } else if (_guides.isEmpty) {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _applyGuides(List<GuideModel> source) {
    final normalized = List<GuideModel>.of(source)
      ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    final latest = normalized.take(_poolLimit).toList(growable: false);

    _rotationTimer?.cancel();
    setState(() {
      _guides = latest;
      _offset = 0;
      _loading = false;
    });

    if (latest.length > _visibleCount) {
      _rotationTimer = Timer.periodic(_rotationInterval, (_) {
        if (!mounted || _guides.length <= _visibleCount) return;
        setState(() {
          // +4 over a pool of 10 walks 0→4→8→2→6→0, exposing every guide.
          _offset = (_offset + _visibleCount) % _guides.length;
        });
      });
    }
  }

  List<GuideModel> get _visibleGuides {
    if (_guides.length <= _visibleCount) return _guides;
    return List<GuideModel>.generate(
      _visibleCount,
      (index) => _guides[(_offset + index) % _guides.length],
      growable: false,
    );
  }

  Future<void> _openGuide(GuideModel guide) async {
    try {
      final article = await ClinicalGuidesEditorialService.loadById(guide.id);
      if (!mounted) return;

      if (article != null && article.hasEditorialBody) {
        final lang = context.read<AppProvider>().lang;
        FirestoreService.incrementGuideDownload(guide.id);

        await Navigator.of(context).push<void>(
          HomeCardTransition.route<void>(
            builder: (_) => ClinicalGuideArticleScreen(
              guide: article.forLanguage(lang),
              lang: lang,
            ),
          ),
        );
        return;
      }
    } catch (_) {
      // Preserve the canonical legacy-PDF fallback below.
    }

    if (!mounted) return;
    final url = guide.localizedPdfUrl(widget.isEs).trim();
    if (url.isEmpty) return;
    FirestoreService.incrementGuideDownload(guide.id);
    openAcademicSourceSecurely(
      context,
      guide.localizedTitle(widget.isEs),
      url,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _guides.isEmpty) {
      return const _LatestGuidesLoadingGrid();
    }

    if (_guides.isEmpty) {
      return const SizedBox.shrink();
    }

    final visible = _guides.length <= 4
        ? _visibleGuides
        : _guides.take(10).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.isEs ? 'GUÍAS CLÍNICAS' : 'GUIAS CLÍNICAS',
                    style: TextStyle(
                      color: widget.dark
                          ? const Color(0xFFF8FAFC)
                          : const Color(0xFF18202A),
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
                Text(
                  widget.isEs ? 'RECIENTES' : 'RECENTES',
                  style: TextStyle(
                    color: widget.dark
                        ? const Color(0xFF9AA7B7)
                        : const Color(0xFF667085),
                    fontSize: 9.5,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.55,
                  ),
                ),
              ],
            ),
          ),
          _LatestGuidesHorizontalRail(
            guides: visible,
            dark: widget.dark,
            isEs: widget.isEs,
            duration: _transitionDuration,
            onOpen: (guide) => _openGuide(guide),
          ),
        ],
      ),
    );
  }
}

class _LatestGuideCard extends StatelessWidget {
  const _LatestGuideCard({
    required this.guide,
    required this.dark,
    required this.isEs,
    required this.onTap,
  });

  final GuideModel guide;
  final bool dark;
  final bool isEs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surface = dark ? const Color(0xFF252930) : Colors.white;
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF18202A);
    final secondary = dark ? const Color(0xFF9AA7B7) : const Color(0xFF667085);
    final divider = dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);

    final imageUrl = guide.coverUrl.trim();
    final title = guide.localizedTitle(isEs).trim();
    final description = guide.localizedDescription(isEs).trim();
    final category = guide.category.trim().isEmpty
        ? (isEs ? 'General' : 'Geral')
        : guide.category.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: divider, width: 0.7),
            boxShadow: dark
                ? null
                : const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x10000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 60,
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(13)),
                  child: imageUrl.isEmpty
                      ? _GuideCoverFallback(dark: dark)
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                          errorBuilder: (_, __, ___) =>
                              _GuideCoverFallback(dark: dark),
                        ),
                ),
              ),
              Expanded(
                flex: 40,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 9,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.62,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: text,
                          fontSize: 13.5,
                          height: 1.18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Expanded(
                          child: Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: secondary,
                              fontSize: 10.5,
                              height: 1.28,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
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

class _GuideCoverFallback extends StatelessWidget {
  const _GuideCoverFallback({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: dark ? const Color(0xFF30363F) : const Color(0xFFE8EDF1),
      child: Center(
        child: Icon(
          Icons.medical_information_outlined,
          size: 28,
          color: dark ? const Color(0xFF7E8A99) : const Color(0xFF94A3B8),
        ),
      ),
    );
  }
}

class _LatestGuidesHorizontalRail extends StatefulWidget {
  const _LatestGuidesHorizontalRail({
    required this.guides,
    required this.dark,
    required this.isEs,
    required this.duration,
    required this.onOpen,
  });

  final List<dynamic> guides;
  final bool dark;
  final bool isEs;
  final Duration duration;
  final void Function(dynamic guide) onOpen;

  @override
  State<_LatestGuidesHorizontalRail> createState() =>
      _LatestGuidesHorizontalRailState();
}

class _LatestGuidesHorizontalRailState
    extends State<_LatestGuidesHorizontalRail> {
  final ScrollController _controller = ScrollController();
  bool _moving = false;

  static const double _gap = 5;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _goNext() async {
    if (_moving || !_controller.hasClients) return;

    final position = _controller.position;
    if (position.maxScrollExtent <= 0) return;

    setState(() => _moving = true);
    try {
      final current = position.pixels;
      final max = position.maxScrollExtent;
      final viewport = position.viewportDimension;
      final target = current >= max - 2
          ? 0.0
          : (current + viewport).clamp(0.0, max).toDouble();

      await _controller.animateTo(
        target,
        duration: widget.duration,
        curve: Curves.easeOutCubic,
      );
    } finally {
      if (mounted) {
        setState(() => _moving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.guides.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - _gap) / 2;
        final cardHeight = cardWidth / 1.08;

        return SizedBox(
          height: cardHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ListView.separated(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: widget.guides.length,
                separatorBuilder: (_, __) => const SizedBox(width: _gap),
                itemBuilder: (context, index) {
                  final guide = widget.guides[index];
                  return SizedBox(
                    width: cardWidth,
                    child: _LatestGuideCard(
                      guide: guide,
                      dark: widget.dark,
                      isEs: widget.isEs,
                      onTap: () => widget.onOpen(guide),
                    ),
                  );
                },
              ),
              if (widget.guides.length > 2)
                Positioned(
                  right: 7,
                  top: (cardHeight - 36) / 2,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _moving ? null : _goNext,
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: widget.dark
                              ? const Color(0xE61B1F24)
                              : const Color(0xF2FFFFFF),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: widget.dark
                                ? const Color(0xFF3A414B)
                                : const Color(0xFFD7DEE7),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: widget.dark ? 0.28 : 0.12,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: widget.dark
                              ? const Color(0xFFF4F7FA)
                              : const Color(0xFF26313D),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LatestGuidesLoadingGrid extends StatelessWidget {
  const _LatestGuidesLoadingGrid();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = dark ? const Color(0xFF252930) : const Color(0xFFF3F5F7);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 5),
      child: Row(
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 1.08,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: AspectRatio(
              aspectRatio: 1.08,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
