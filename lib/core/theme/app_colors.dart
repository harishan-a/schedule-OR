import 'package:flutter/material.dart';

/// Centralized color constants for the application.
/// Status colors consolidate the 10+ duplicate _getStatusColor implementations.
class AppColors {
  AppColors._();

  // Primary palette
  static const Color primary = Colors.blue;
  static const Color primaryDark = Color(0xFF1565C0);
  static const Color secondary = Colors.orange;
  static const Color secondaryDark = Color(0xFFE65100);

  // Surgery status colors (consolidated from 10+ duplicate implementations)
  static const Color statusScheduled = Colors.blue;
  static const Color statusInProgress = Colors.orange;
  static const Color statusCompleted = Colors.green;
  static const Color statusCancelled = Colors.red;
  static const Color statusDefault = Colors.grey;

  /// Get color for a surgery status string.
  /// Consolidates all duplicate _getStatusColor implementations.
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return statusScheduled;
      case 'in progress':
        return statusInProgress;
      case 'completed':
        return statusCompleted;
      case 'cancelled':
        return statusCancelled;
      default:
        return statusDefault;
    }
  }

  // Background colors
  static const Color backgroundLight = Colors.white;
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceLight = Color(0xFFFAFAFA); // Colors.grey[50]
  static const Color surfaceDark = Color(0xFF1E1E1E);

  // Semantic colors
  static const Color success = Colors.green;
  static const Color warning = Colors.orange;
  static const Color error = Colors.red;
  static const Color info = Colors.blue;
}
