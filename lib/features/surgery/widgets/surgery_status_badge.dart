import 'package:flutter/material.dart';
import 'package:firebase_orscheduler/core/enums/surgery_status.dart';

/// A reusable surgery status badge widget.
/// Uses the centralized SurgeryStatus enum for colors and display names.
class SurgeryStatusBadge extends StatelessWidget {
  final String status;
  final double? fontSize;
  final EdgeInsetsGeometry? padding;

  const SurgeryStatusBadge({
    super.key,
    required this.status,
    this.fontSize,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final surgeryStatus = SurgeryStatus.fromString(status);

    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: surgeryStatus.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: surgeryStatus.color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(surgeryStatus.icon,
              size: (fontSize ?? 12) + 2, color: surgeryStatus.color),
          const SizedBox(width: 6),
          Text(
            surgeryStatus.displayName,
            style: TextStyle(
              color: surgeryStatus.color,
              fontWeight: FontWeight.w600,
              fontSize: fontSize ?? 12,
            ),
          ),
        ],
      ),
    );
  }
}
