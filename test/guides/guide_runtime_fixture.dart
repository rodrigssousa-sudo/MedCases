import 'dart:async';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/providers/app_provider.dart';
import 'package:medcases/screens/library_screen.dart';
import 'package:medcases/screens/clinical_guide_article_screen.dart';

/// Synthetic Firebase IO only. Real Library, services, ordering, pagination,
/// search delegate and Navigator execute unchanged.
class GuideStore extends FirebaseFirestorePlatform {
  final rows = List.generate(
      23,
      (i) => <String, dynamic>{
            'id': 'guide-$i',
            'title': 'Guia $i',
            'summary': 'Resumo $i',
            'category': 'Cardiologia',
            'hasEditorialContent': true,
            'isPublished': true,
            'status': 'published',
            'uploadedAt': DateTime.utc(2026, 9, 23 - i).toIso8601String(),
            'bodyBlocks': [
              {'type': 'paragraph', 'text': 'Conteúdo editorial $i'}
            ],
            'localizations': {
              'pt': {'title': 'Guia $i', 'subtitle': 'Subtítulo $i'},
              'es': {'title': 'Guía $i', 'subtitle': 'Subtítulo $i'}
            },
            'searchPrefixes': ['guia', 'cardio', 'cardiologia', 'renal'],
          });
  final writes = <Map<String, dynamic>>[];
  final queries = <Map<String, dynamic>>[];
  final opened = <String>[];
  int subscriptionsCancelled = 0;
  @override
  FirebaseFirestorePlatform delegateFor(
          {required FirebaseApp app, required String databaseId}) =>
      this;
  @override
  CollectionReferencePlatform collection(String path) => GuideQuery(this, path);
  @override
  DocumentReferencePlatform doc(String path) => GuideDoc(this, path);
}

class GuideQuery extends CollectionReferencePlatform {
  GuideQuery(this.store, String path,
      {this.conditions = const [],
      this.orders = const [],
      this.cursor,
      this.pageLimit})
      : super(store, path) {
    parameters.addAll({
      'where': conditions,
      'orderBy': orders,
      'startAfter': cursor == null ? null : [cursor],
      'limit': pageLimit
    });
  }
  final GuideStore store;
  final List<List<dynamic>> conditions, orders;
  final String? cursor;
  final int? pageLimit;
  GuideQuery copy(
          {List<List<dynamic>>? conditions,
          List<List<dynamic>>? orders,
          String? cursor,
          int? pageLimit}) =>
      GuideQuery(store, path,
          conditions: conditions ?? this.conditions,
          orders: orders ?? this.orders,
          cursor: cursor ?? this.cursor,
          pageLimit: pageLimit ?? this.pageLimit);
  @override
  QueryPlatform where(List<List<dynamic>> conditions) =>
      copy(conditions: conditions);
  @override
  QueryPlatform orderBy(Iterable<List<dynamic>> orders) =>
      copy(orders: orders.toList());
  @override
  QueryPlatform startAfter(Iterable<dynamic> fields) =>
      copy(cursor: fields.single as String);
  @override
  QueryPlatform limit(int limit) => copy(pageLimit: limit);
  @override
  DocumentReferencePlatform doc([String? path]) =>
      GuideDoc(store, '${this.path}/$path');
  @override
  Future<QuerySnapshotPlatform> get(
      [GetOptions options = const GetOptions()]) async {
    store.queries.add({
      'path': path,
      'conditions': conditions,
      'orders': orders,
      'cursor': cursor,
      'limit': pageLimit
    });
    var data = store.rows
        .where((r) =>
            cursor == null ||
            (r['uploadedAt'] as String).compareTo(cursor!) < 0)
        .toList();
    for (final condition in conditions) {
      final field = condition[0] is FieldPath
          ? (condition[0] as FieldPath).components.join('.')
          : condition[0] is List
              ? (condition[0] as List).join('.')
              : condition[0].toString();
      if (condition[1] == '==') {
        data = data.where((r) => r[field] == condition[2]).toList();
      }
      if (condition[1] == 'array-contains') {
        data = data
            .where((r) => (r[field] as List?)?.contains(condition[2]) ?? false)
            .toList();
      }
    }
    data.sort((a, b) =>
        (b['uploadedAt'] as String).compareTo(a['uploadedAt'] as String));
    return QuerySnapshotPlatform(
        data
            .take(pageLimit ?? data.length)
            .map((r) => DocumentSnapshotPlatform(
                store,
                '$path/${r['id']}',
                r,
                PigeonSnapshotMetadata(
                    hasPendingWrites: false, isFromCache: false)))
            .toList(),
        [],
        SnapshotMetadataPlatform(false, false));
  }

  @override
  Stream<QuerySnapshotPlatform> snapshots(
      {bool includeMetadataChanges = false,
      required ListenSource listenSource}) {
    late StreamController<QuerySnapshotPlatform> controller;
    controller = StreamController(
        onListen: () async => controller.add(await get()),
        onCancel: () {
          store.subscriptionsCancelled++;
        });
    return controller.stream;
  }
}

class GuideDoc extends DocumentReferencePlatform {
  GuideDoc(this.store, String path) : super(store, path);
  final GuideStore store;
  @override
  Future<DocumentSnapshotPlatform> get(
      [GetOptions options = const GetOptions()]) async {
    store.opened.add(id);
    return DocumentSnapshotPlatform(
        store,
        path,
        store.rows.singleWhere((r) => r['id'] == id),
        PigeonSnapshotMetadata(hasPendingWrites: false, isFromCache: false));
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    store.writes.add({'path': path, ...data});
  }

  @override
  Future<void> update(Map<FieldPath, dynamic> data) async {}
}

class GuideAppProvider extends AppProvider {
  GuideAppProvider(this.language);
  final String language;
  @override
  String get lang => language;
  @override
  bool get darkMode => false;
}

final guideStore = GuideStore();

class GuideHarness {
  GuideHarness(this.tester, this.store, this.provider);
  final WidgetTester tester;
  final GuideStore store;
  final GuideAppProvider provider;
  static Future<GuideHarness> open(WidgetTester tester,
      {String language = 'pt', GuideStore? suppliedStore}) async {
    SharedPreferences.setMockInitialValues(
        {'clinical_guides_cache_first_open_reset_v2': true});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final method in [
      'registerIdTokenListener',
      'registerAuthStateListener'
    ]) {
      final event = 'guide-test-$method';
      messenger.setMockMessageHandler(
          'dev.flutter.pigeon.firebase_auth_platform_interface.FirebaseAuthHostApi.$method',
          (_) async => const StandardMessageCodec().encodeMessage([event]));
      messenger.setMockMessageHandler(event,
          (_) async => const StandardMethodCodec().encodeSuccessEnvelope(null));
    }
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    final store = suppliedStore ?? guideStore;
    store.queries.clear();
    store.writes.clear();
    store.opened.clear();
    store.subscriptionsCancelled = 0;
    FirebaseFirestorePlatform.instance = store;
    final provider = GuideAppProvider(language);
    await tester.pumpWidget(ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: MaterialApp(
            locale: Locale(language),
            supportedLocales: const [Locale('pt'), Locale('es')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const Scaffold(body: ClinicalGuideScreen()))));
    await tester.pumpAndSettle();
    return GuideHarness(tester, store, provider);
  }

  Future<void> close() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    provider.dispose();
  }
}

void testVerticalPortal() {
  testWidgets('current portal is vertical, editorial and navigable',
      (tester) async {
    final h = await GuideHarness.open(tester);
    expect(find.text('Guia 0'), findsOneWidget);
    expect(find.text('Guia 1'), findsOneWidget);
    final a = tester.getRect(find.text('Guia 0'));
    final b = tester.getRect(find.text('Guia 1'));
    expect(b.top, greaterThan(a.top));
    expect(b.left, a.left);
    expect(find.byIcon(Icons.picture_as_pdf), findsNothing);
    expect(find.textContaining('KB'), findsNothing);
    await tester.tap(find.text('Guia 0'));
    await tester.pumpAndSettle();
    expect(find.byType(ClinicalGuideArticleScreen), findsOneWidget);
    expect(find.text('Conteúdo editorial 0'), findsOneWidget);
    expect(h.store.opened, contains('guide-0'));
    await h.close();
  });
}

void testPortalLabels() {
  for (final lang in ['pt', 'es']) {
    testWidgets('current portal labels $lang', (tester) async {
      final h = await GuideHarness.open(tester, language: lang);
      expect(
          find.text(lang == 'pt' ? 'DESTAQUES' : 'DESTACADOS'), findsOneWidget);
      expect(find.text(lang == 'pt' ? '10 guias' : '10 guías'), findsOneWidget);
      expect(find.text(lang == 'pt' ? 'Guia 0' : 'Guía 0'), findsOneWidget);
      expect(find.textContaining('Desliz'), findsNothing);
      await h.close();
    });
  }
}

void testCountHeader() {
  testWidgets('no separate count header; exactly one editorial count',
      (tester) async {
    final h = await GuideHarness.open(tester);
    expect(find.text('10 guias'), findsOneWidget);
    final headings = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where((s) => s.toLowerCase().contains('10 guia'))
        .toList();
    expect(headings, ['10 guias']);
    expect(tester.getTopLeft(find.text('DESTAQUES')).dy,
        lessThan(tester.getTopLeft(find.text('Guia 0')).dy));
    await h.close();
  });
}

void testPagination() {
  testWidgets('vertical scroll queries next ten with actual last cursor',
      (tester) async {
    final h = await GuideHarness.open(tester);
    final scroll = find.byType(CustomScrollView).first;
    await tester.drag(scroll, const Offset(0, -4200));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    final pages = h.store.queries.where((q) => q['cursor'] != null).toList();
    expect(pages, isNotEmpty);
    expect(pages.first['limit'], 10);
    expect(pages.first['cursor'], h.store.rows[9]['uploadedAt']);
    expect(h.store.subscriptionsCancelled, greaterThan(0));
    expect(find.text('Guia 10'), findsOneWidget);
    expect(find.text('Guia 0'), findsOneWidget);
    await tester.drag(scroll, const Offset(0, -8000));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(find.text('23 guias'), findsOneWidget);
    final allPages = h.store.queries.where((q) => q['cursor'] != null).toList();
    expect(allPages.length, 2);
    expect(allPages.last['limit'], 10);
    expect(allPages.last['cursor'], h.store.rows[19]['uploadedAt']);
    final count = h.store.queries.length;
    await tester.drag(scroll, const Offset(0, -8000));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(h.store.queries.length, count);
    await h.close();
  });
}

void testSearchBridge() {
  testWidgets('search and selection execute real editorial bridge',
      (tester) async {
    final h = await GuideHarness.open(tester);
    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Guia 3');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Guia 3'));
    await tester.pumpAndSettle();
    expect(find.byType(ClinicalGuideArticleScreen), findsOneWidget);
    expect(find.text('Conteúdo editorial 3'), findsOneWidget);
    expect(h.store.opened, contains('guide-3'));
    await h.close();
  });
}
