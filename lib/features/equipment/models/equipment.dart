// =============================================================================
// Equipment Model
// =============================================================================
// A model class representing medical equipment in the OR scheduling system.
// Handles data representation, serialization, and validation for equipment:
// - Core equipment details (name, category, specifications)
// - Location tracking
// - Availability status
//
// Firebase Integration:
// - Serialization to/from Firestore documents
// - Null-safety implementation
//
// The model follows the repository pattern structure of the application
// =============================================================================

/// Represents a piece of medical equipment with all associated details
class Equipment {
  /// Unique identifier for the equipment
  /// Non-null, required for database operations
  final String id;

  /// Name of the equipment
  /// Non-null, required field
  final String name;

  /// Category of the equipment (e.g., "Imaging", "Monitoring", "Surgical")
  /// Non-null, used for filtering and categorization
  final String category;

  /// Identifier for the equipment's storage location
  /// Non-null, required for tracking
  final String locationId;

  /// Current availability status of the equipment
  /// Non-null, used for scheduling
  final bool isAvailable;

  /// Technical specifications and additional details
  /// Map structure allows for flexible properties
  final Map<String, dynamic> specifications;

  /// Creates a new Equipment instance with required and optional fields
  ///
  /// All required fields must be non-null
  Equipment({
    required this.id,
    required this.name,
    required this.category,
    required this.locationId,
    required this.isAvailable,
    this.specifications = const {},
  }) {
    // Validate inputs
    if (name.isEmpty) {
      throw ArgumentError('Equipment name cannot be empty');
    }
    if (category.isEmpty) {
      throw ArgumentError('Equipment category cannot be empty');
    }
    if (locationId.isEmpty) {
      throw ArgumentError('Equipment location ID cannot be empty');
    }
  }

  /// Creates an Equipment instance from a Firestore document
  ///
  /// Handles:
  /// - Null safety for all fields
  /// - Default values for optional fields
  factory Equipment.fromFirestore(String id, Map<String, dynamic> data) {
    return Equipment(
      id: id,
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? '',
      locationId: data['locationId'] as String? ?? '',
      isAvailable: data['isAvailable'] as bool? ?? true,
      specifications: data['specifications'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Converts the Equipment instance to a Firestore document
  ///
  /// Handles:
  /// - Null safety for optional fields
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'category': category,
      'locationId': locationId,
      'isAvailable': isAvailable,
      'specifications': specifications,
    };
  }

  /// Creates a copy of the equipment with modified fields
  Equipment copyWith({
    String? name,
    String? category,
    String? locationId,
    bool? isAvailable,
    Map<String, dynamic>? specifications,
  }) {
    return Equipment(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      locationId: locationId ?? this.locationId,
      isAvailable: isAvailable ?? this.isAvailable,
      specifications: specifications ?? this.specifications,
    );
  }

  /// Provides a string representation of this equipment for debugging
  @override
  String toString() {
    return 'Equipment(id: $id, name: $name, category: $category, '
        'locationId: $locationId, isAvailable: $isAvailable, '
        'specifications: $specifications)';
  }

  /// Compares this equipment with another for equality
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Equipment &&
        other.id == id &&
        other.name == name &&
        other.category == category &&
        other.locationId == locationId &&
        other.isAvailable == isAvailable &&
        _mapsEqual(other.specifications, specifications);
  }

  /// Provides a consistent hash code for this equipment
  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        category.hashCode ^
        locationId.hashCode ^
        isAvailable.hashCode ^
        specifications.hashCode;
  }

  /// Helper method to compare two specification maps
  bool _mapsEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;

    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) {
        return false;
      }
    }

    return true;
  }
}
