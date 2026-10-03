import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../screens/clinical_guide_article_screen.dart';
import '../services/clinical_guides_editorial_service.dart';
import '../services/guide_navigation_intent.dart';

/// Mounted only behind existing account/professional gates. Reads through the
/// canonical authenticated guide loader; never embeds protected content.
class GuideIntentEntry extends StatefulWidget {
  const GuideIntentEntry({super.key, required this.child});
  final Widget child;
  @override
  State<GuideIntentEntry> createState() => _GuideIntentEntryState();
}

class _GuideIntentEntryState extends State<GuideIntentEntry> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (!kIsWeb) return;
    final slug = Uri.base.queryParameters['guide'];
    if (slug != null) await GuideNavigationIntent.request(slug);
    final id = await GuideNavigationIntent.pendingId();
    if (id == null || !mounted) return;
    final provider = context.read<AppProvider>();
    final uid = provider.currentUser?.uid;
    try {
      final guide = await ClinicalGuidesEditorialService.loadById(id)
          .timeout(const Duration(seconds: 15));
      if (!mounted || uid == null || provider.currentUser?.uid != uid) return;
      if (guide == null || !guide.isPublished || !guide.hasEditorialBody)
        throw StateError('GUIDE_UNAVAILABLE');
      await GuideNavigationIntent.clear();
      if (!mounted) return;
      final lang = provider.lang;
      await Navigator.of(context).push<void>(MaterialPageRoute(
          builder: (_) => ClinicalGuideArticleScreen(
              guide: guide.forLanguage(lang), lang: lang)));
    } catch (_) {
      if (!mounted) return;
      final es = provider.lang == 'es';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(es
              ? 'No pudimos abrir la guía. Inténtalo nuevamente.'
              : 'Não foi possível abrir o guia. Tente novamente.'),
          action: SnackBarAction(
              label: es ? 'Reintentar' : 'Tentar novamente',
              onPressed: _open)));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
