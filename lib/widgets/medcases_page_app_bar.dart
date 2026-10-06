import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'common_widgets.dart';

class MedCasesPageAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String titlePt;
  final String titleEs;
  final bool isEs;
  final Color accentColor;

  const MedCasesPageAppBar({
    super.key,
    required this.titlePt,
    required this.titleEs,
    required this.isEs,
    required this.accentColor,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppBar(
      backgroundColor: c.cardBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle:
          c.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      leading: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: c.textPrimary,
          ),
        ),
      ),
      title: Text(
        isEs ? titleEs : titlePt,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: c.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: c.border),
      ),
    );
  }
}
