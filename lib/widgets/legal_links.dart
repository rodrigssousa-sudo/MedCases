import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/legal_urls.dart';

class MedCasesLegalLinks extends StatelessWidget {
  const MedCasesLegalLinks(
      {super.key,
      required this.isEs,
      this.compact = false,
      this.additionalOnly = false});
  final bool isEs;
  final bool compact;
  final bool additionalOnly;
  @override
  Widget build(BuildContext context) {
    final links = <String, String>{
      if (!additionalOnly)
        isEs ? 'Términos de uso' : 'Termos de Uso': MedCasesLegalUrls.terms,
      if (!additionalOnly)
        isEs ? 'Política de privacidad' : 'Política de Privacidade':
            MedCasesLegalUrls.privacy,
      if (!compact) ...{
        isEs ? 'Suscripciones' : 'Assinaturas': MedCasesLegalUrls.subscriptions,
        'Aviso médico': MedCasesLegalUrls.medicalDisclaimer,
        isEs ? 'Eliminar cuenta y datos' : 'Excluir conta e dados':
            MedCasesLegalUrls.dataDeletion,
        isEs ? 'Soporte' : 'Suporte': MedCasesLegalUrls.support,
        isEs ? 'Contacto' : 'Contato': MedCasesLegalUrls.contact,
      },
    };
    return Wrap(
        alignment: WrapAlignment.center,
        children: links.entries
            .map((entry) => TextButton(
                  onPressed: () async {
                    try {
                      final opened = await launchUrl(
                          Uri.parse(MedCasesLegalUrls.localized(
                              entry.value, isEs ? 'es' : 'pt')),
                          mode: LaunchMode.externalApplication);
                      if (opened || !context.mounted) return;
                    } catch (_) {
                      if (!context.mounted) return;
                    }
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(isEs
                              ? 'No pudimos abrir el enlace. Inténtalo nuevamente.'
                              : 'Não foi possível abrir o link. Tente novamente.')));
                  },
                  child: Text(entry.key),
                ))
            .toList());
  }
}
