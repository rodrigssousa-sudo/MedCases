import 'package:flutter/material.dart';
import '../../widgets/medcases_page_app_bar.dart';

PreferredSizeWidget organizationAppBar(String title) => MedCasesPageAppBar(
    titlePt: title,
    titleEs: title,
    isEs: false,
    accentColor: Colors.transparent);
void dismissOrganizationKeyboard() =>
    FocusManager.instance.primaryFocus?.unfocus();

class OrganizationSurface extends StatelessWidget {
  const OrganizationSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: .4))),
          clipBehavior: Clip.antiAlias,
          child: Padding(padding: const EdgeInsets.all(16), child: child)));
}

Widget organizationSection(
        BuildContext context, String title, List<Widget> children) =>
    OrganizationSurface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 12),
      ...children,
    ]));

InputDecoration organizationInput(
        BuildContext context, String label) =>
    InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: .4),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none));

ButtonStyle organizationSegments(BuildContext context) => ButtonStyle(
    visualDensity: VisualDensity.compact,
    side: WidgetStatePropertyAll(BorderSide(
        color: Theme.of(context)
            .colorScheme
            .outlineVariant
            .withValues(alpha: .5))),
    foregroundColor: WidgetStateProperty.resolveWith((states) =>
        states.contains(WidgetState.selected)
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSurfaceVariant),
    backgroundColor: WidgetStateProperty.resolveWith((states) =>
        states.contains(WidgetState.selected)
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surfaceContainerLow));
