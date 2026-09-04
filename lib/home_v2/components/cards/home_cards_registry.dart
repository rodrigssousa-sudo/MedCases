class HomeCardDefinition{

  final String id;

  final String title;

  final String subtitle;

  final String route;

  final bool useWebView;

  const HomeCardDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.route,
    this.useWebView=false,
  });

}
