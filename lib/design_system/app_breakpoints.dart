import 'package:flutter/material.dart';

abstract final class AppBreakpoints {
  /// Width threshold (dp) below which the screen is considered mobile (< 600).
  static const double mobile = 600.0;

  /// Width threshold (dp) between 600 and 900 considered tablet.
  static const double tablet = 900.0;

  /// > 900 dp is desktop layout.
}

enum AppBreakpoint { mobile, tablet, desktop }

extension BreakpointExt on BuildContext {
  AppBreakpoint get breakpoint {
    final w = MediaQuery.sizeOf(this).width;
    if (w < AppBreakpoints.mobile) return AppBreakpoint.mobile;
    if (w < AppBreakpoints.tablet) return AppBreakpoint.tablet;
    return AppBreakpoint.desktop;
  }

  bool get isMobile => breakpoint == AppBreakpoint.mobile;
  bool get isTablet => breakpoint == AppBreakpoint.tablet;
  bool get isDesktop => breakpoint == AppBreakpoint.desktop;
}
