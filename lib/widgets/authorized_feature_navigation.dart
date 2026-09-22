import 'package:flutter/material.dart';
import '../services/medcases_feature_authorization.dart';
import '../screens/upgrade_screen.dart';

Future<void> navigateAuthorizedFeature(
  BuildContext context, {
  required FeatureTarget target,
  required FeatureEntryPoint entrypoint,
  required WidgetBuilder builder,
  required String lang,
  MedCasesFeatureAuthorization? authorization,
}) async {
  final navigator = Navigator.of(context);
  await (authorization ?? MedCasesFeatureAuthorization.instance).execute<void>(
    target,
    entrypoint: entrypoint,
    presentPaywall: () async {
      if (navigator.mounted)
        await showUpgradeScreen(navigator.context, lang: lang);
    },
    action: () async {
      if (navigator.mounted)
        await navigator.push(MaterialPageRoute<void>(builder: builder));
    },
  );
}
