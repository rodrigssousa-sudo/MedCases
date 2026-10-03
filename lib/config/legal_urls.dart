class MedCasesLegalUrls {
  const MedCasesLegalUrls._();
  static String localized(String url, String language) => Uri.parse(url)
      .replace(fragment: language == 'es' ? 'es' : 'pt')
      .toString();

  static const home = 'https://medcasespro.com';
  static const privacy = 'https://medcasespro.com/privacy';
  static const terms = 'https://medcasespro.com/terms';
  static const subscriptions = 'https://medcasespro.com/subscriptions';
  static const medicalDisclaimer = 'https://medcasespro.com/medical-disclaimer';
  static const dataDeletion = 'https://medcasespro.com/data-deletion';
  static const support = 'https://medcasespro.com/support';
  static const contact = 'https://medcasespro.com/contact';
}
