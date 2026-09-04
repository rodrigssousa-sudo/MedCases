/// Categorias responsivas oficiais do MedCases Next.
enum MedWindowClass {
  mobile,
  tablet,
  desktop,
  wideDesktop,
}

/// Breakpoints centralizados da nova plataforma.
abstract final class MedBreakpoints {
  static const double mobileMax = 599;
  static const double tabletMin = 600;
  static const double tabletMax = 1023;
  static const double desktopMin = 1024;
  static const double desktopMax = 1439;
  static const double wideDesktopMin = 1440;

  static MedWindowClass resolve(double width) {
    if (width < tabletMin) {
      return MedWindowClass.mobile;
    }

    if (width < desktopMin) {
      return MedWindowClass.tablet;
    }

    if (width < wideDesktopMin) {
      return MedWindowClass.desktop;
    }

    return MedWindowClass.wideDesktop;
  }

  static bool isMobile(double width) {
    return resolve(width) == MedWindowClass.mobile;
  }

  static bool isTablet(double width) {
    return resolve(width) == MedWindowClass.tablet;
  }

  static bool isDesktop(double width) {
    final windowClass = resolve(width);
    return windowClass == MedWindowClass.desktop ||
        windowClass == MedWindowClass.wideDesktop;
  }
}
