import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read() => File('lib/screens/library_screen.dart').readAsStringSync();

String _between(
  String source,
  String start,
  String end,
  String label,
) {
  final a = source.indexOf(start);
  final b = source.indexOf(end, a + start.length);
  expect(a, greaterThanOrEqualTo(0), reason: '$label start missing');
  expect(b, greaterThan(a), reason: '$label end missing');
  return source.substring(a, b);
}

void main() {
  late String source;
  late String guideCard;
  late String shareMethod;
  late String portalCard;

  setUpAll(() {
    source = _read();

    guideCard = _between(
      source,
      'class _GuideCard extends StatelessWidget',
      'class _LibraryTabEmptyState',
      '_GuideCard',
    );

    shareMethod = _between(
      guideCard,
      '// MEDCASES_GUIDE_PDF_SHARE_CARD_ACTION_V1_B_R1',
      '@override\n  Widget build(BuildContext context)',
      '_sharePdf',
    );

    portalCard = _between(
      guideCard,
      'Widget portalCard(GuideModel item)',
      'if (loadingMore)',
      'portalCard',
    );
  });

  test('guide card owns a top-right PDF share action', () {
    expect(portalCard, contains('top: 12'));
    expect(portalCard, contains('right: 14'));
    expect(portalCard, contains('Icons.ios_share_rounded'));
    expect(portalCard, contains('onTap: () => _sharePdf(context, isEs, item)'));
    expect(portalCard, contains('width: 36'));
    expect(portalCard, contains('height: 36'));
  });

  test('PDF share uses localized PDF and published fail-closed guard', () {
    expect(shareMethod, contains('item.localizedPdfUrl(isEs).trim()'));
    expect(shareMethod, contains('!item.isPublished || pdfUrl.isEmpty'));
    expect(shareMethod, contains("uri.scheme != 'https'"));
    expect(shareMethod, contains("uri.scheme != 'http'"));
  });

  test('PDF bytes are verified and shared cross-platform from memory', () {
    expect(source, isNot(contains("import 'dart:io';")));
    expect(source,
        isNot(contains("import 'package:path_provider/path_provider.dart';")));
    expect(source, contains("import 'package:http/http.dart' as http;"));
    expect(source, contains("import 'package:share_plus/share_plus.dart';"));
    expect(shareMethod, contains('response.bodyBytes'));
    expect(shareMethod, contains('bytes[0] == 0x25'));
    expect(shareMethod, contains('bytes[1] == 0x50'));
    expect(shareMethod, contains('bytes[2] == 0x44'));
    expect(shareMethod, contains('bytes[3] == 0x46'));
    expect(shareMethod, contains('XFile.fromData('));
    expect(shareMethod, contains("'application/pdf'"));
    expect(shareMethod, contains('fileNameOverrides: <String>[fileName]'));
    expect(shareMethod, contains('SharePlus.instance.share'));
  });

  test('share payload is PDF-only with social links deliberately absent', () {
    expect(shareMethod, contains('files: <XFile>['));
    expect(shareMethod, isNot(contains('medcasespro.com')));
    expect(shareMethod, isNot(contains('utm_')));
    expect(shareMethod, isNot(contains('instagram')));
    expect(shareMethod, isNot(contains('facebook')));
    expect(shareMethod, isNot(contains('whatsapp')));
    expect(shareMethod, isNot(contains('telegram')));
  });

  test('existing card open and guide reader routes are preserved', () {
    expect(guideCard, contains('onTap: () => onOpenGuide(item)'));
    expect(source, contains('void _openPdf(GuideModel g)'));
    expect(source, contains('Future<void> _openGuide(GuideModel g) async'));
    expect(source, contains('ClinicalGuideArticleScreen('));
    expect(source, contains('openAcademicSourceSecurely('));
  });

  test('scope does not add deep-link or platform routing behavior', () {
    expect(source, isNot(contains('AppLinks(')));
    expect(source, isNot(contains('associated-domains')));
    expect(source, isNot(contains('android:autoVerify')));
    expect(source, isNot(contains('utm_campaign=clinical_guide')));
  });
}
