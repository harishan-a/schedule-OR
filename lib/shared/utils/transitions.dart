// =============================================================================
// App Transition Utilities
// =============================================================================
// Provides consistent transition animations throughout the app
// for improved user experience and UI consistency.
// =============================================================================

import 'package:flutter/material.dart';

/// A consistent page route builder that applies a standard transition animation
/// throughout the app for seamless navigation experience.
///
/// Features a subtle slide animation combined with a fade effect.
class AppPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;

  AppPageRoute({
    required this.page,
    this.duration = const Duration(milliseconds: 270),
  }) : super(
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) =>
              page,
          transitionDuration: duration,
          transitionsBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            // Enhanced transition that combines fade and slide
            const begin = Offset(0.05, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;

            var slideTween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var fadeTween =
                Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(slideTween),
              child: FadeTransition(
                opacity: animation.drive(fadeTween),
                child: child,
              ),
            );
          },
        );
}

/// Helper functions for creating transitions

/// Creates a standard app transition that combines a subtle slide with a fade effect
Route<T> createAppTransition<T>(Widget page, {Duration? duration}) {
  return AppPageRoute<T>(
    page: page,
    duration: duration ?? const Duration(milliseconds: 270),
  );
}

/// Transitions without changing routes (for in-place transitions)
Widget animatedTransition({
  required Widget child,
  required Animation<double> animation,
  Offset begin = const Offset(0.05, 0.0),
  Offset end = Offset.zero,
  Curve curve = Curves.easeOutCubic,
}) {
  var slideTween =
      Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
  var fadeTween = Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));

  return SlideTransition(
    position: animation.drive(slideTween),
    child: FadeTransition(
      opacity: animation.drive(fadeTween),
      child: child,
    ),
  );
}
