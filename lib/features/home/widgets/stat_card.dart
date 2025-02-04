// =============================================================================
// Statistics Card Widget
// =============================================================================
// A reusable card widget that displays statistical information with:
// - Color-coded icons and values
// - Gradient background effects
// - Consistent styling with the app's design system
// - Responsive layout for different screen sizes
//
// The card shows:
// - Statistic title
// - Numeric value
// - Associated icon
//
// Usage:
// ```dart
// StatCard(
//   title: 'Completed',
//   value: '42',
//   color: Colors.green,
//   icon: Icons.check_circle,
// )
// ```
// =============================================================================

import 'package:flutter/material.dart';

/// A card widget that displays a single statistic with associated
/// icon and color-coded styling.
class StatCard extends StatelessWidget {
  /// The title or label for the statistic
  final String title;
  
  /// The value to display (typically a number)
  final String value;
  
  /// The accent color for the card
  final Color color;
  
  /// The icon to display with the statistic
  final IconData icon;

  /// Creates a statistics card
  /// 
  /// All parameters are required and must not be null.
  /// The [color] parameter is used for the icon and value styling.
  const StatCard({
    Key? key,
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Card with consistent border radius and subtle elevation
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          // Subtle gradient background for visual depth
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Statistic icon with consistent sizing
            Icon(
              icon,
              size: 24,
              color: color,
            ),
            const SizedBox(width: 8),
            // Title and value column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title with reduced opacity for hierarchy
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: color.withOpacity(0.8),
                    ),
                  ),
                  // Value with prominent styling
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

