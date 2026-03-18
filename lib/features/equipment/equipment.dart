// =============================================================================
// Equipment Feature Exports
// =============================================================================
// This barrel file exports all public components of the equipment feature,
// providing a centralized import location for other modules to access
// equipment-related functionality.
//
// Usage:
// import 'package:firebase_orscheduler/features/equipment/equipment.dart';
//
// Contents:
// - Equipment model: Core data structure for equipment items
// - Equipment repository: Data access layer with CRUD operations and caching
// - EquipmentSelection widget: Reusable UI for selecting equipment with filtering
// - EquipmentCatalog screen: Full equipment browsing and detail interface
// =============================================================================

// Models - Core data structures
export 'models/equipment.dart';

// Repositories - Data access and business logic
export 'repositories/equipment_repository.dart';

// Widgets - Reusable UI components
export 'widgets/equipment_selection.dart';

// Screens - Full page interfaces
export 'screens/equipment_catalog.dart';
