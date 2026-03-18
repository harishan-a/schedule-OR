// =============================================================================
// DurationInput: Specialized Duration Selection Widget
// =============================================================================
// A reusable widget for inputting durations with:
// - Increment/decrement buttons for easy adjustment
// - Preset common durations for quick selection
// - Input validation for time constraints
// - Visual feedback for selected values
//
// Features:
// - Responsive design adapting to different screen sizes
// - Clear visual presentation of duration values
// - Support for hours and minutes inputs
// - Configurable min/max duration limits
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Callback for when a duration value changes
typedef DurationChangedCallback = void Function(int minutes);

/// A specialized input widget for duration values
class DurationInput extends StatefulWidget {
  /// Label to display for this input
  final String label;

  /// Current duration value in minutes
  final int initialMinutes;

  /// Callback for when the duration changes
  final DurationChangedCallback onDurationChanged;

  /// Minimum allowed duration in minutes
  final int minDuration;

  /// Maximum allowed duration in minutes
  final int maxDuration;

  /// Step size for increment/decrement in minutes
  final int stepSize;

  /// List of preset duration values in minutes
  final List<int>? presetDurations;

  /// Whether to show hour and minute inputs separately
  final bool showHoursMinutes;

  /// Icon to display next to the label
  final IconData? icon;

  /// Whether the duration is required
  final bool isRequired;

  /// Creates a DurationInput widget
  const DurationInput({
    super.key,
    required this.label,
    required this.initialMinutes,
    required this.onDurationChanged,
    this.minDuration = 0,
    this.maxDuration = 1440, // 24 hours
    this.stepSize = 5,
    this.presetDurations,
    this.showHoursMinutes = false,
    this.icon,
    this.isRequired = false,
  })  : assert(minDuration >= 0, 'Minimum duration cannot be negative'),
        assert(maxDuration > minDuration,
            'Maximum duration must be greater than minimum'),
        assert(stepSize > 0, 'Step size must be positive');

  @override
  State<DurationInput> createState() => _DurationInputState();
}

class _DurationInputState extends State<DurationInput> {
  late int _minutes;
  late TextEditingController _minutesController;
  late TextEditingController _hoursController;

  // For preset selection UI state
  int? _selectedPresetIndex;

  @override
  void initState() {
    super.initState();
    _minutes = widget.initialMinutes;
    _updateControllers();
  }

  @override
  void didUpdateWidget(DurationInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMinutes != widget.initialMinutes) {
      _minutes = widget.initialMinutes;
      _updateControllers();
    }
  }

  void _updateControllers() {
    // Initialize or update controllers based on current minutes
    if (widget.showHoursMinutes) {
      final hours = _minutes ~/ 60;
      final mins = _minutes % 60;

      if (!mounted) return;

      // Create new controllers with current values
      // First dispose existing controllers if already initialized
      try {
        _hoursController.dispose();
        _minutesController.dispose();
      } catch (e) {
        // Ignore if controllers haven't been initialized yet
      }

      _hoursController = TextEditingController(text: hours.toString());
      _minutesController =
          TextEditingController(text: mins.toString().padLeft(2, '0'));
    } else {
      // Create a new controller with the current value
      // First dispose existing controller if already initialized
      try {
        _minutesController.dispose();
      } catch (e) {
        // Ignore if controller hasn't been initialized yet
      }

      _minutesController = TextEditingController(text: _minutes.toString());
    }
  }

  @override
  void dispose() {
    _minutesController.dispose();
    if (widget.showHoursMinutes) {
      _hoursController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label row with required indicator if needed
        Row(
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
            ],
            Text(
              widget.label,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            if (widget.isRequired)
              Text(
                ' *',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Main duration input with hours/minutes or total minutes
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outline.withOpacity(0.5),
            ),
            color: colorScheme.surface,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: widget.showHoursMinutes
              ? _buildHoursMinutesInput(theme)
              : _buildTotalMinutesInput(theme),
        ),

        // Preset durations if provided
        if (widget.presetDurations != null &&
            widget.presetDurations!.isNotEmpty)
          _buildPresets(theme),
      ],
    );
  }

  /// Builds the hours and minutes input fields
  Widget _buildHoursMinutesInput(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        // Hours input
        Expanded(
          flex: 1,
          child: TextFormField(
            controller: _hoursController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              labelText: 'hrs',
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            onChanged: (value) {
              // Update duration when hours change
              final hours = int.tryParse(value) ?? 0;
              final mins = int.tryParse(_minutesController.text) ?? 0;
              _updateDuration(hours * 60 + mins);
            },
          ),
        ),

        // Separator
        Text(
          ':',
          style: theme.textTheme.headlineSmall,
        ),

        // Minutes input
        Expanded(
          flex: 1,
          child: TextFormField(
            controller: _minutesController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              labelText: 'mins',
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
              // Ensure minutes are < 60
              TextInputFormatter.withFunction((oldValue, newValue) {
                final value = int.tryParse(newValue.text) ?? 0;
                if (value < 60) {
                  return newValue;
                }
                return oldValue;
              }),
            ],
            onChanged: (value) {
              // Update duration when minutes change
              final hours = int.tryParse(_hoursController.text) ?? 0;
              final mins = int.tryParse(value) ?? 0;
              _updateDuration(hours * 60 + mins);
            },
          ),
        ),

        // Increment/decrement buttons
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildIconButton(
              icon: Icons.arrow_drop_up,
              onPressed: () => _incrementDuration(widget.stepSize),
            ),
            _buildIconButton(
              icon: Icons.arrow_drop_down,
              onPressed: () => _decrementDuration(widget.stepSize),
            ),
          ],
        ),
      ],
    );
  }

  /// Builds the total minutes input with increment/decrement buttons
  Widget _buildTotalMinutesInput(ThemeData theme) {
    return Row(
      children: [
        // Minutes input
        Expanded(
          child: TextFormField(
            controller: _minutesController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              suffixText: 'minutes',
              border: InputBorder.none,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            onChanged: (value) {
              final newValue = int.tryParse(value) ?? 0;
              _updateDuration(newValue);
            },
          ),
        ),

        // Vertical divider
        const SizedBox(
          height: 36,
          child: VerticalDivider(),
        ),

        // Increment/decrement controls
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildIconButton(
              icon: Icons.arrow_drop_up,
              onPressed: () => _incrementDuration(widget.stepSize),
            ),
            _buildIconButton(
              icon: Icons.arrow_drop_down,
              onPressed: () => _decrementDuration(widget.stepSize),
            ),
          ],
        ),
      ],
    );
  }

  /// Builds a small icon button
  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 32,
      height: 24,
      child: IconButton(
        icon: Icon(icon, size: 20),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
      ),
    );
  }

  /// Builds the preset duration chips
  Widget _buildPresets(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Presets',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
              widget.presetDurations!.length,
              (index) {
                final duration = widget.presetDurations![index];
                final isSelected = _selectedPresetIndex == index;

                return ChoiceChip(
                  label: Text(_formatDuration(duration)),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedPresetIndex = selected ? index : null;
                      _updateDuration(duration);
                    });
                  },
                  backgroundColor: colorScheme.surface,
                  selectedColor: colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Increments the duration by the specified amount
  void _incrementDuration(int amount) {
    final newValue = _minutes + amount;
    if (newValue <= widget.maxDuration) {
      _updateDuration(newValue);
    }
  }

  /// Decrements the duration by the specified amount
  void _decrementDuration(int amount) {
    final newValue = _minutes - amount;
    if (newValue >= widget.minDuration) {
      _updateDuration(newValue);
    }
  }

  /// Updates the duration and controllers
  void _updateDuration(int newMinutes) {
    // Enforce min/max constraints
    newMinutes = newMinutes.clamp(widget.minDuration, widget.maxDuration);

    setState(() {
      _minutes = newMinutes;

      // Update controllers based on new value
      if (widget.showHoursMinutes) {
        final hours = _minutes ~/ 60;
        final mins = _minutes % 60;

        _hoursController.text = hours.toString();
        _minutesController.text = mins.toString().padLeft(2, '0');
      } else {
        _minutesController.text = _minutes.toString();
      }
    });

    // Notify parent
    widget.onDurationChanged(_minutes);
  }

  /// Formats duration for display
  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    if (hours > 0) {
      return '$hours h ${mins > 0 ? '$mins m' : ''}';
    } else {
      return '$mins m';
    }
  }
}

/// Extension to create a DurationInput with common preset values
extension PresetDurationInput on DurationInput {
  /// Creates a DurationInput for prep time with common presets
  static DurationInput forPrepTime({
    required int initialMinutes,
    required DurationChangedCallback onDurationChanged,
    bool isRequired = false,
  }) {
    return DurationInput(
      label: 'Preparation Time',
      initialMinutes: initialMinutes,
      onDurationChanged: onDurationChanged,
      minDuration: 0,
      maxDuration: 120, // 2 hours max for prep
      stepSize: 5,
      presetDurations: const [0, 15, 30, 45, 60],
      icon: Icons.timer,
      isRequired: isRequired,
    );
  }

  /// Creates a DurationInput for cleanup time with common presets
  static DurationInput forCleanupTime({
    required int initialMinutes,
    required DurationChangedCallback onDurationChanged,
    bool isRequired = false,
  }) {
    return DurationInput(
      label: 'Cleanup Time',
      initialMinutes: initialMinutes,
      onDurationChanged: onDurationChanged,
      minDuration: 0,
      maxDuration: 120, // 2 hours max for cleanup
      stepSize: 5,
      presetDurations: const [0, 15, 30, 45, 60],
      icon: Icons.cleaning_services,
      isRequired: isRequired,
    );
  }

  /// Creates a DurationInput for surgery duration with common presets
  static DurationInput forSurgeryDuration({
    required int initialMinutes,
    required DurationChangedCallback onDurationChanged,
    bool isRequired = true,
  }) {
    return DurationInput(
      label: 'Surgery Duration',
      initialMinutes: initialMinutes,
      onDurationChanged: onDurationChanged,
      minDuration: 15,
      maxDuration: 480, // 8 hours max for surgery
      stepSize: 15,
      presetDurations: const [30, 60, 120, 180, 240],
      showHoursMinutes: true,
      icon: Icons.medical_services,
      isRequired: isRequired,
    );
  }
}
