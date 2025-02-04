// =============================================================================
// AppTheme: Core Theme Configuration
// =============================================================================
// This file manages the application's theme system, providing:
// - Dynamic theme switching (light/dark modes)
// - Accessibility features (large text, high contrast)
// - Consistent styling across the entire application
// 
// The theme system is implemented using InheritedWidget for efficient updates
// and rebuilds only when theme properties change.
//
// Usage:
//   final theme = AppTheme.of(context);
//   theme.updateTheme(isDark, isLargeText, isHighContrast);
// =============================================================================

import 'package:flutter/material.dart';

class AppTheme extends InheritedWidget {
  // Core theme configuration properties
  final bool isDark;           // Controls light/dark mode
  final bool isLargeText;      // Controls text scaling for accessibility
  final bool isHighContrast;   // Controls color contrast for accessibility
  final Function(bool isDark, bool isLargeText, bool isHighContrast) updateTheme;

  const AppTheme({
    super.key,
    required super.child,
    required this.isDark,
    required this.isLargeText,
    required this.isHighContrast,
    required this.updateTheme,
  });

  // Provides access to the nearest AppTheme instance in the widget tree
  static AppTheme of(BuildContext context) {
    final AppTheme? result = context.dependOnInheritedWidgetOfExactType<AppTheme>();
    assert(result != null, 'No AppTheme found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(AppTheme oldWidget) {
    return isDark != oldWidget.isDark ||
        isLargeText != oldWidget.isLargeText ||
        isHighContrast != oldWidget.isHighContrast;
  }

  // Creates a complete ThemeData instance based on the current configuration
  // Parameters:
  //   forceDark: When true, creates a dark theme regardless of isDark setting
  ThemeData _createTheme(bool forceDark) {
    // Base colors for theme generation
    final brightness = forceDark ? Brightness.dark : Brightness.light;
    final primaryColor = forceDark ? Colors.blue[300]! : Colors.blue;      // Primary brand color
    final backgroundColor = forceDark ? const Color(0xFF121212) : Colors.white;  // Material 3 background
    final surfaceColor = forceDark ? const Color(0xFF1E1E1E) : Colors.grey[50]!;  // Surface color
    final onSurfaceColor = forceDark ? Colors.white : Colors.black;  // Text/icon color on surface
    final secondaryColor = forceDark ? Colors.orange[300]! : Colors.orange;  // Accent color
    
    // Text theme configuration with accessibility scaling
    final textTheme = (forceDark ? ThemeData.dark() : ThemeData.light()).textTheme.copyWith(
      // Body text styles
      bodyLarge: TextStyle(
        fontSize: isLargeText ? 16.0 : 14.0,  // +2px for accessibility
        color: onSurfaceColor,
      ),
      bodyMedium: TextStyle(
        fontSize: isLargeText ? 14.0 : 12.0,  // +2px for accessibility
        color: onSurfaceColor,
      ),
      // Header text styles
      titleLarge: TextStyle(
        fontSize: isLargeText ? 22.0 : 20.0,  // +2px for accessibility
        fontWeight: FontWeight.bold,
        color: onSurfaceColor,
      ),
      titleMedium: TextStyle(
        fontSize: isLargeText ? 18.0 : 16.0,  // +2px for accessibility
        fontWeight: FontWeight.w600,
        color: onSurfaceColor,
      ),
      labelLarge: TextStyle(
        fontSize: isLargeText ? 16.0 : 14.0,  // +2px for accessibility
        fontWeight: FontWeight.w500,
        color: onSurfaceColor,
      ),
    );

    // Color scheme configuration based on accessibility settings
    final colorScheme = isHighContrast
        ? ColorScheme(  // High contrast color scheme for accessibility
            brightness: brightness,
            primary: primaryColor,
            onPrimary: Colors.white,
            secondary: secondaryColor,
            onSecondary: Colors.white,
            error: forceDark ? Colors.red[300]! : Colors.red,
            onError: Colors.white,
            background: backgroundColor,
            onBackground: onSurfaceColor,
            surface: surfaceColor,
            onSurface: onSurfaceColor,
            surfaceTint: surfaceColor,
            primaryContainer: primaryColor.withOpacity(0.1),
            onPrimaryContainer: primaryColor,
            secondaryContainer: secondaryColor.withOpacity(0.1),
            onSecondaryContainer: secondaryColor,
          )
        : ColorScheme.fromSeed(  // Standard color scheme with Material 3 color generation
            seedColor: primaryColor,
            brightness: brightness,
          ).copyWith(
            background: backgroundColor,
            surface: surfaceColor,
            onSurface: onSurfaceColor,
            surfaceTint: surfaceColor,
            primaryContainer: primaryColor.withOpacity(0.1),
            onPrimaryContainer: primaryColor,
            secondaryContainer: secondaryColor.withOpacity(0.1),
            onSecondaryContainer: secondaryColor,
          );

    return ThemeData(
      useMaterial3: true,  // Enables Material 3 design system
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.background,

      // AppBar theme configuration
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: colorScheme.surface,
        elevation: 0,  // Flat design following Material 3 guidelines
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
        ),
      ),

      // Card theme configuration
      cardTheme: CardTheme(
        color: colorScheme.surface,
        surfaceTintColor: colorScheme.surface,
        elevation: forceDark ? 0 : 1,  // Reduced elevation in dark mode for better contrast
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),  // Consistent corner radius
          side: forceDark 
              ? BorderSide(color: colorScheme.onSurface.withOpacity(0.1))  // Subtle border in dark mode
              : BorderSide.none,
        ),
      ),

      // ListTile theme configuration
      listTileTheme: ListTileThemeData(
        tileColor: colorScheme.surface,
        textColor: colorScheme.onSurface,
        iconColor: colorScheme.primary,
      ),

      // Bottom navigation theme configuration
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurface.withOpacity(0.6),
        elevation: 8.0,  // Elevation for visual separation
        type: BottomNavigationBarType.fixed,
        landscapeLayout: BottomNavigationBarLandscapeLayout.centered,
      ),

      // Navigation bar theme (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        elevation: 8.0,
        height: 65.0,  // Standard height for comfortable touch targets
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        // Icon theming based on selection state
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return IconThemeData(color: colorScheme.onPrimaryContainer);
          }
          return IconThemeData(color: colorScheme.onSurface.withOpacity(0.6));
        }),
        // Label theming based on selection state
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return textTheme.labelLarge?.copyWith(color: colorScheme.onPrimaryContainer);
          }
          return textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.6),
          );
        }),
      ),

      // Switch theme configuration
      switchTheme: SwitchThemeData(
        // Thumb color based on selection state
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return colorScheme.primary;
          }
          return null;  // Default color
        }),
        // Track color based on selection state
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return colorScheme.primary.withOpacity(0.5);
          }
          return null;  // Default color
        }),
      ),

      // Elevated button theme configuration
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          surfaceTintColor: colorScheme.surface,
          elevation: forceDark ? 0 : 2,  // Reduced elevation in dark mode
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),  // Comfortable touch target
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),  // Consistent corner radius
          ),
        ),
      ),

      // Input decoration theme configuration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: colorScheme.onSurface.withOpacity(0.1),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: colorScheme.onSurface.withOpacity(0.1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: colorScheme.primary,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: colorScheme.error,
          ),
        ),
      ),

      // Divider theme configuration
      dividerTheme: DividerThemeData(
        color: colorScheme.onSurface.withOpacity(0.1),  // Subtle divider color
      ),

      // SnackBar theme configuration
      snackBarTheme: SnackBarThemeData(
        backgroundColor: forceDark ? colorScheme.surface : colorScheme.onSurface,
        contentTextStyle: TextStyle(
          color: forceDark ? colorScheme.onSurface : colorScheme.surface,
        ),
        behavior: SnackBarBehavior.floating,  // Floating style for better visibility
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      // Dialog theme configuration
      dialogTheme: DialogTheme(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),  // Consistent corner radius
        ),
      ),

      // Bottom sheet theme configuration
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surface,
        modalBackgroundColor: colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),  // Rounded top corners
        ),
      ),

      // Popup menu theme configuration
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surface,
        surfaceTintColor: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),  // Consistent corner radius
        ),
      ),

      // Page transitions theme configuration
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),  // iOS-style transitions
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  // Public getters for accessing light and dark themes
  ThemeData get theme => _createTheme(false);     // Light theme
  ThemeData get darkTheme => _createTheme(true);  // Dark theme
} 
