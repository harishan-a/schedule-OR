import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A versatile avatar widget that can display images from various sources:
/// - Network image (imageUrl)
/// - Local file (file)
/// - Asset image (assetPath)
/// - Text initials (name)
///
/// Will fallback to initials if no image source is available
class UserAvatar extends StatelessWidget {
  /// User's full name for generating initials
  final String name;

  /// URL for remote image
  final String? imageUrl;

  /// Local file path for image
  final File? file;

  /// Asset path for default avatars
  final String? assetPath;

  /// Avatar size (radius)
  final double radius;

  /// Background color for avatar or initials
  final Color? backgroundColor;

  /// Text color for initials
  final Color? textColor;

  /// Whether to show a border
  final bool showBorder;

  /// Border color (if showBorder is true)
  final Color? borderColor;

  /// Border width (if showBorder is true)
  final double borderWidth;

  /// Creates a UserAvatar widget
  const UserAvatar({
    Key? key,
    required this.name,
    this.imageUrl,
    this.file,
    this.assetPath,
    required this.radius,
    this.backgroundColor,
    this.textColor,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth = 2,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine the final avatar content based on available sources
    Widget avatarContent;

    // Apply border if required
    BoxBorder? border = showBorder
        ? Border.all(
            color: borderColor ?? Theme.of(context).colorScheme.background,
            width: borderWidth,
          )
        : null;

    // Get initials from name (fallback)
    String initials = _getInitials(name);

    // Local file has highest priority
    if (file != null) {
      avatarContent = CircleAvatar(
        radius: radius,
        backgroundColor:
            backgroundColor ?? Theme.of(context).colorScheme.primary,
        backgroundImage: FileImage(file!),
      );
    }
    // Next priority is asset path
    else if (assetPath != null && assetPath!.isNotEmpty) {
      avatarContent = CircleAvatar(
        radius: radius,
        backgroundColor:
            backgroundColor ?? Theme.of(context).colorScheme.primary,
        backgroundImage: AssetImage(assetPath!),
      );
    }
    // Next is network image
    else if (imageUrl != null && imageUrl!.isNotEmpty) {
      avatarContent = ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholder: (context, url) => CircleAvatar(
            radius: radius,
            backgroundColor:
                backgroundColor ?? Theme.of(context).colorScheme.primary,
            child: SizedBox(
              width: radius * 0.8,
              height: radius * 0.8,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
          errorWidget: (context, url, error) => CircleAvatar(
            radius: radius,
            backgroundColor:
                backgroundColor ?? Theme.of(context).colorScheme.primary,
            child: Text(
              initials,
              style: TextStyle(
                color: textColor ?? Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.6,
              ),
            ),
          ),
        ),
      );
    }
    // Fallback to initials
    else {
      avatarContent = CircleAvatar(
        radius: radius,
        backgroundColor:
            backgroundColor ?? Theme.of(context).colorScheme.primary,
        child: Text(
          initials,
          style: TextStyle(
            color: textColor ?? Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.6,
          ),
        ),
      );
    }

    // Apply border if needed
    if (border != null) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: border,
        ),
        child: avatarContent,
      );
    }

    return avatarContent;
  }

  /// Extracts initials from the provided name
  String _getInitials(String fullName) {
    if (fullName.isEmpty) return '';

    List<String> nameParts = fullName.split(' ');
    String initials = '';

    // Get first letter of first name
    if (nameParts.isNotEmpty && nameParts[0].isNotEmpty) {
      initials += nameParts[0][0].toUpperCase();
    }

    // Get first letter of last name (if available)
    if (nameParts.length > 1 && nameParts[1].isNotEmpty) {
      initials += nameParts[1][0].toUpperCase();
    }

    return initials;
  }
}
