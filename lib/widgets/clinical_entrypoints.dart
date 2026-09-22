import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../screens/drugs_screen.dart';
import '../screens/calculadora_screen.dart';
import '../services/medcases_feature_authorization.dart';
import 'authorized_feature_navigation.dart';

/// Injectable navigation factories let tests count construction without mocking
/// a physical PlatformView. Production always uses the real screens below.
class ClinicalEntryPointScope extends InheritedWidget {
  const ClinicalEntryPointScope(
      {super.key,
      required super.child,
      required this.authorization,
      required this.drugPage,
      required this.calculatorPage});
  final MedCasesFeatureAuthorization authorization;
  final Widget Function(String) drugPage;
  final Widget Function(String?) calculatorPage;
  static ClinicalEntryPointScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ClinicalEntryPointScope>();
  @override
  bool updateShouldNotify(ClinicalEntryPointScope oldWidget) =>
      authorization != oldWidget.authorization;
}

Future<void> _drug(BuildContext context, String id, FeatureEntryPoint origin) {
  final scope = ClinicalEntryPointScope.of(context);
  return navigateAuthorizedFeature(context,
      target: FeatureTarget.drug(id),
      entrypoint: origin,
      lang: context.read<AppProvider>().lang,
      authorization: scope?.authorization,
      builder: (_) => scope?.drugPage(id) ?? DrugsScreen(initialDrugId: id));
}

Future<void> _calculator(
    BuildContext context, String? url, FeatureEntryPoint origin) {
  final scope = ClinicalEntryPointScope.of(context);
  return navigateAuthorizedFeature(context,
      target: FeatureTarget.calculator(url),
      entrypoint: origin,
      lang: context.read<AppProvider>().lang,
      authorization: scope?.authorization,
      builder: (_) =>
          scope?.calculatorPage(url) ?? CalculadoraScreen(initialUrl: url));
}

Future<void> openDrugFromHomeSearch(BuildContext c, String id) =>
    _drug(c, id, FeatureEntryPoint.homeSearch);
Future<void> openDrugFromGlobalSearch(BuildContext c, String id) =>
    _drug(c, id, FeatureEntryPoint.globalSearch);
Future<void> openDrugFromFavorite(BuildContext c, String id) =>
    _drug(c, id, FeatureEntryPoint.favorites);
Future<void> openDrugFromRecent(BuildContext c, String id) =>
    _drug(c, id, FeatureEntryPoint.recents);
Future<void> openDrugDetailEntry(BuildContext c, String id) =>
    _drug(c, id, FeatureEntryPoint.showDrugDetail);
Future<void> openDrugFromDirectNavigator(BuildContext c, String id) =>
    _drug(c, id, FeatureEntryPoint.directNavigator);
Future<void> openRestoredDrug(BuildContext c, String id) =>
    _drug(c, id, FeatureEntryPoint.restoredNavigation);
Future<void> openOfflineRestoredDrug(BuildContext c, String id) =>
    _drug(c, id, FeatureEntryPoint.offlineRestoredScreen);
Future<void> openCalculatorFromUrl(BuildContext c, String url) =>
    _calculator(c, url, FeatureEntryPoint.deeplink);
Future<void> openCalculatorFromAi(BuildContext c, String url) =>
    _calculator(c, url, FeatureEntryPoint.aiAction);
Future<void> openCalculatorFromStudy(BuildContext c, String url) =>
    _calculator(c, url, FeatureEntryPoint.studyAction);
Future<void> openCalculatorFromPlantao(BuildContext c, String url) =>
    _calculator(c, url, FeatureEntryPoint.plantaoAction);
Future<void> openCalculatorAction(BuildContext c, String? url) =>
    _calculator(c, url, FeatureEntryPoint.calculator);
