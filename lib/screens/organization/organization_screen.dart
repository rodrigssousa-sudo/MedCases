import 'organization_presentation.dart';
import 'package:flutter/material.dart';
import '../../services/entitlement_service.dart';
import '../../services/medcases_feature_authorization.dart';
import '../../widgets/authorized_feature_navigation.dart';
import 'organization_timer_screen.dart';
import 'agenda_screen.dart';

class OrganizationScreen extends StatelessWidget {
  const OrganizationScreen({super.key, required this.isEs, this.authorization});
  final bool isEs;
  final MedCasesFeatureAuthorization? authorization;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable:
          (authorization ?? MedCasesFeatureAuthorization.instance).entitlement,
      builder: (context, _) => Scaffold(
          appBar: organizationAppBar(isEs ? 'Organización' : 'Organização'),
          body: ListView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
              children: [
                Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                            color: Theme.of(context)
                                .dividerColor
                                .withValues(alpha: 0.12))),
                    clipBehavior: Clip.antiAlias,
                    child: Column(children: [
                      _card(
                          context,
                          Icons.timer_outlined,
                          'Timer',
                          isEs
                              ? 'Control de tiempo y sesiones de enfoque'
                              : 'Controle de tempo e sessões de foco',
                          () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) =>
                                      OrganizationTimerScreen(isEs: isEs)))),
                      const Divider(height: 1, indent: 80),
                      _card(
                          context,
                          Icons.calendar_month_outlined,
                          'Agenda',
                          isEs
                              ? 'Compromisos, horarios y recordatorios'
                              : 'Compromissos, horários e lembretes',
                          () => navigateAuthorizedFeature(context,
                              target: const FeatureTarget.capability(
                                  MedCasesCapability.agenda),
                              entrypoint: FeatureEntryPoint.directNavigator,
                              lang: isEs ? 'es' : 'pt',
                              authorization: authorization,
                              builder: (_) => AgendaScreen(
                                  isEs: isEs, authorization: authorization)),
                          premium: !(authorization ??
                                  MedCasesFeatureAuthorization.instance)
                              .allows(const FeatureTarget.capability(
                                  MedCasesCapability.agenda))),
                    ])),
              ])));
  Widget _card(BuildContext context, IconData icon, String title,
          String subtitle, VoidCallback onTap, {bool premium = false}) =>
      ListTile(
          contentPadding: const EdgeInsets.all(20),
          leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, size: 24)),
          title: Row(children: [
            Expanded(
                child: Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700))),
            if (premium) ...[
              const SizedBox(width: 12),
              Icon(Icons.lock_outline,
                  size: 18,
                  semanticLabel: isEs ? 'Acceso Premium' : 'Acesso Premium')
            ]
          ]),
          subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant))),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap);
}
