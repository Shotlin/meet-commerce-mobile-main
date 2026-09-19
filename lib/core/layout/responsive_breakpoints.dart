/// Shared width thresholds for adaptive Flutter layouts.
class ResponsiveBreakpoints {
  ResponsiveBreakpoints._();

  static const double tablet = 600;
  static const double desktop = 1024;
  static const double desktopContentMaxWidth = 1440;

  static bool isDesktop(double width) => width >= desktop;
}
