// =============================================================================
// TimeSelector: Advanced Time Selection Widget
// =============================================================================
// A reusable widget for visually selecting time ranges with:
// - 5-minute increment selection
// - Visual timeline display
// - Drag-and-drop functionality for start and end times
// - Clear indicators for selected time range
// - Helper methods for time validation
//
// Features:
// - Responsive design for different screen sizes
// - Adjustable time ranges with minimum/maximum constraints
// - Optional snap-to-grid functionality for precise time selection
// - Customizable appearance and theming
// =============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Callback for when a time range is selected
typedef TimeRangeChangedCallback = void Function(
    TimeOfDay start, TimeOfDay end);

/// A visual time selector widget with drag-and-drop functionality
class TimeSelector extends StatefulWidget {
  /// Initial start time for the selection
  final TimeOfDay initialStartTime;

  /// Initial end time for the selection
  final TimeOfDay initialEndTime;

  /// Minimum selectable time (optional)
  final TimeOfDay? minTime;

  /// Maximum selectable time (optional)
  final TimeOfDay? maxTime;

  /// Callback when the time range is changed
  final TimeRangeChangedCallback onTimeRangeChanged;

  /// Time increment in minutes (default: 5 minutes)
  final int timeIncrementMinutes;

  /// Whether to enforce the time increment strictly (snap to grid)
  final bool enforceTimeIncrement;

  /// The height of the timeline
  final double timelineHeight;

  /// Whether to show time labels on the timeline
  final bool showTimeLabels;

  /// Whether to show the timeline grid
  final bool showGrid;

  /// The theme colors for the widget
  final TimelineColors? colors;

  /// The date to display for the time selector (defaults to today)
  final DateTime? date;

  /// Creates a TimeSelector widget
  const TimeSelector({
    super.key,
    required this.initialStartTime,
    required this.initialEndTime,
    required this.onTimeRangeChanged,
    this.minTime,
    this.maxTime,
    this.timeIncrementMinutes = 5,
    this.enforceTimeIncrement = true,
    this.timelineHeight = 80,
    this.showTimeLabels = true,
    this.showGrid = true,
    this.colors,
    this.date,
  }) : assert(timeIncrementMinutes > 0 && timeIncrementMinutes <= 60,
            'Time increment must be between 1 and 60 minutes');

  @override
  State<TimeSelector> createState() => _TimeSelectorState();
}

/// Custom colors for the timeline
class TimelineColors {
  /// Color for the timeline background
  final Color background;

  /// Color for the timeline grid lines
  final Color gridLines;

  /// Color for the selected time range
  final Color selectedRange;

  /// Color for the start handle
  final Color startHandle;

  /// Color for the end handle
  final Color endHandle;

  /// Text color for the time labels
  final Color timeLabels;

  /// Creates TimelineColors with the specified colors or defaults
  const TimelineColors({
    required this.background,
    required this.gridLines,
    required this.selectedRange,
    required this.startHandle,
    required this.endHandle,
    required this.timeLabels,
  });

  /// Creates TimelineColors from the current theme
  factory TimelineColors.fromTheme(BuildContext context) {
    final theme = Theme.of(context);
    return TimelineColors(
      background: theme.colorScheme.surface,
      gridLines: theme.colorScheme.onSurface.withOpacity(0.1),
      selectedRange: theme.colorScheme.primaryContainer,
      startHandle: theme.colorScheme.primary,
      endHandle: theme.colorScheme.tertiary ?? theme.colorScheme.secondary,
      timeLabels: theme.colorScheme.onSurface.withOpacity(0.7),
    );
  }
}

class _TimeSelectorState extends State<TimeSelector> {
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late TimelineColors _colors;

  // For drag calculations
  double _startPosition = 0.0;
  double _endPosition = 0.0;
  double _timelineWidth = 0.0;

  // Time range constants
  static const int _minutesInDay = 1440; // 24 hours * 60 minutes
  static const int _minutesInHour = 60;
  static const int _hoursDisplayed = 12; // Display 12 hours at a time

  @override
  void initState() {
    super.initState();
    _startTime = widget.initialStartTime;
    _endTime = widget.initialEndTime;
  }

  @override
  void didUpdateWidget(TimeSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStartTime != widget.initialStartTime ||
        oldWidget.initialEndTime != widget.initialEndTime) {
      _startTime = widget.initialStartTime;
      _endTime = widget.initialEndTime;
      _updatePositionsFromTimes();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _colors = widget.colors ?? TimelineColors.fromTheme(context);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _timelineWidth = constraints.maxWidth;
        _updatePositionsFromTimes();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time labels display
            _buildTimeDisplay(),
            const SizedBox(height: 8),

            // Timeline with draggable handles
            _buildTimeline(constraints.maxWidth),

            if (widget.showTimeLabels) const SizedBox(height: 4),

            // Hour markers below the timeline
            if (widget.showTimeLabels) _buildTimeLabels(constraints.maxWidth),
          ],
        );
      },
    );
  }

  /// Builds the display for the selected time range
  Widget _buildTimeDisplay() {
    final textTheme = Theme.of(context).textTheme;
    String dateStr = '';

    if (widget.date != null) {
      dateStr = '${DateFormat('EEE, MMM d').format(widget.date!)} | ';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            '$dateStr${_formatTime(_startTime)} - ${_formatTime(_endTime)}',
            style: textTheme.titleMedium,
          ),
        ),
        // Duration display
        Text(
          _formatDuration(_startTime, _endTime),
          style: textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Builds the visual timeline with draggable handles
  Widget _buildTimeline(double width) {
    return Container(
      height: widget.timelineHeight,
      width: width,
      decoration: BoxDecoration(
        color: _colors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _colors.gridLines,
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // Grid lines (if enabled)
          if (widget.showGrid) _buildGridLines(width),

          // Selected time range
          Positioned(
            left: _startPosition,
            width: _endPosition - _startPosition,
            top: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: _colors.selectedRange,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),

          // Start time handle
          _buildDraggableHandle(
            position: _startPosition,
            color: _colors.startHandle,
            isStart: true,
          ),

          // End time handle
          _buildDraggableHandle(
            position: _endPosition,
            color: _colors.endHandle,
            isStart: false,
          ),
        ],
      ),
    );
  }

  /// Builds the grid lines for the timeline
  Widget _buildGridLines(double width) {
    // Calculate number of lines based on time increment
    final minutesPerPixel = (_hoursDisplayed * _minutesInHour) / width;
    final pixelsPerHour = width / _hoursDisplayed;

    return CustomPaint(
      size: Size(width, widget.timelineHeight),
      painter: _TimelineGridPainter(
        pixelsPerHour: pixelsPerHour,
        hoursDisplayed: _hoursDisplayed,
        gridLineColor: _colors.gridLines,
      ),
    );
  }

  /// Builds a draggable handle for start or end time
  Widget _buildDraggableHandle({
    required double position,
    required Color color,
    required bool isStart,
  }) {
    const handleWidth = 16.0;
    const handleHeight = 24.0;

    return Positioned(
      left: position - (handleWidth / 2),
      top: (widget.timelineHeight - handleHeight) / 2,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) => _handleDrag(details, isStart),
        onHorizontalDragEnd: (details) => _handleDragEnd(),
        child: Container(
          width: handleWidth,
          height: handleHeight,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 2,
              height: 12,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the time labels below the timeline
  Widget _buildTimeLabels(double width) {
    // Create hour labels
    final pixelsPerHour = width / _hoursDisplayed;
    final hourLabels = <Widget>[];

    // Get the start hour (usually 8 AM for a work day)
    int startHour = _getStartHourOfTimeline();

    for (int i = 0; i <= _hoursDisplayed; i++) {
      final hour = (startHour + i) % 24;
      final label = _formatHourLabel(hour);
      final amPm = hour < 12 ? 'AM' : 'PM';

      hourLabels.add(
        Positioned(
          left: i * pixelsPerHour - 20, // Center the label
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _colors.timeLabels,
                ),
              ),
              Text(
                amPm,
                style: TextStyle(
                  fontSize: 10,
                  color: _colors.timeLabels.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 30,
      width: width,
      child: Stack(children: hourLabels),
    );
  }

  /// Handles drag gestures for the time handles
  void _handleDrag(DragUpdateDetails details, bool isStart) {
    // Calculate new position with bounds checking
    double newPosition;

    if (isStart) {
      newPosition = _startPosition + details.delta.dx;
      newPosition = newPosition.clamp(0, _endPosition - 20); // Minimum 20px gap
    } else {
      newPosition = _endPosition + details.delta.dx;
      newPosition = newPosition.clamp(
          _startPosition + 20, _timelineWidth); // Minimum 20px gap
    }

    setState(() {
      if (isStart) {
        _startPosition = newPosition;
        _startTime = _calculateTimeFromPosition(_startPosition);
      } else {
        _endPosition = newPosition;
        _endTime = _calculateTimeFromPosition(_endPosition);
      }

      // Enforce time increment if enabled
      if (widget.enforceTimeIncrement) {
        _snapTimesToIncrement();
        _updatePositionsFromTimes();
      }
    });

    // Notify the parent about the change
    widget.onTimeRangeChanged(_startTime, _endTime);
  }

  /// Handles end of drag gestures
  void _handleDragEnd() {
    // Snap times to the configured increment
    if (widget.enforceTimeIncrement) {
      setState(() {
        _snapTimesToIncrement();
        _updatePositionsFromTimes();
      });

      // Notify the parent about the final values
      widget.onTimeRangeChanged(_startTime, _endTime);
    }
  }

  /// Updates the handle positions based on start and end times
  void _updatePositionsFromTimes() {
    if (_timelineWidth <= 0) return;

    final startHour = _getStartHourOfTimeline();
    final startMinutes = startHour * _minutesInHour;

    final startTimeMinutes =
        _startTime.hour * _minutesInHour + _startTime.minute;
    final endTimeMinutes = _endTime.hour * _minutesInHour + _endTime.minute;

    // Handle day wrap-around (e.g., if end time is on the next day)
    final adjustedEndTimeMinutes = endTimeMinutes < startTimeMinutes
        ? endTimeMinutes + _minutesInDay
        : endTimeMinutes;

    // Calculate positions
    final minutesDisplayed = _hoursDisplayed * _minutesInHour;
    final pixelsPerMinute = _timelineWidth / minutesDisplayed;

    _startPosition = ((startTimeMinutes - startMinutes) * pixelsPerMinute)
        .clamp(0, _timelineWidth);
    _endPosition = ((adjustedEndTimeMinutes - startMinutes) * pixelsPerMinute)
        .clamp(0, _timelineWidth);

    // Ensure minimum gap
    if (_endPosition - _startPosition < 20) {
      _endPosition = _startPosition + 20;
    }
  }

  /// Calculates time from a position on the timeline
  TimeOfDay _calculateTimeFromPosition(double position) {
    final minutesDisplayed = _hoursDisplayed * _minutesInHour;
    final minutesPerPixel = minutesDisplayed / _timelineWidth;
    final startHour = _getStartHourOfTimeline();
    final startMinutes = startHour * _minutesInHour;

    // Calculate minutes from start of timeline
    final minutes = (position * minutesPerPixel + startMinutes).round();

    // Convert to hours and minutes
    final hours = (minutes ~/ _minutesInHour) % 24;
    final mins = minutes % _minutesInHour;

    return TimeOfDay(hour: hours, minute: mins);
  }

  /// Snap times to the configured increment
  void _snapTimesToIncrement() {
    // Snap start time
    final startMinutes = _startTime.hour * _minutesInHour + _startTime.minute;
    final snappedStartMinutes =
        ((startMinutes + widget.timeIncrementMinutes / 2) ~/
                widget.timeIncrementMinutes) *
            widget.timeIncrementMinutes;

    // Snap end time
    final endMinutes = _endTime.hour * _minutesInHour + _endTime.minute;
    final snappedEndMinutes = ((endMinutes + widget.timeIncrementMinutes / 2) ~/
            widget.timeIncrementMinutes) *
        widget.timeIncrementMinutes;

    // Update times
    _startTime = TimeOfDay(
      hour: (snappedStartMinutes ~/ _minutesInHour) % 24,
      minute: snappedStartMinutes % _minutesInHour,
    );

    _endTime = TimeOfDay(
      hour: (snappedEndMinutes ~/ _minutesInHour) % 24,
      minute: snappedEndMinutes % _minutesInHour,
    );

    // Check for min/max constraints
    if (widget.minTime != null) {
      final minMinutes =
          widget.minTime!.hour * _minutesInHour + widget.minTime!.minute;
      if (snappedStartMinutes < minMinutes) {
        _startTime = widget.minTime!;
      }
    }

    if (widget.maxTime != null) {
      final maxMinutes =
          widget.maxTime!.hour * _minutesInHour + widget.maxTime!.minute;
      if (snappedEndMinutes > maxMinutes) {
        _endTime = widget.maxTime!;
      }
    }

    // Ensure end time is after start time
    final startTotalMinutes =
        _startTime.hour * _minutesInHour + _startTime.minute;
    final endTotalMinutes = _endTime.hour * _minutesInHour + _endTime.minute;

    if (endTotalMinutes <= startTotalMinutes) {
      _endTime = TimeOfDay(
        hour: (_startTime.hour +
                (widget.timeIncrementMinutes ~/ _minutesInHour)) %
            24,
        minute: (_startTime.minute +
                (widget.timeIncrementMinutes % _minutesInHour)) %
            _minutesInHour,
      );
    }
  }

  /// Get the start hour of the timeline (typically 8 AM for work day)
  int _getStartHourOfTimeline() {
    // For a typical workday, start at 8 AM
    return 8;
  }

  /// Format a time for display
  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  /// Format an hour label (12-hour format)
  String _formatHourLabel(int hour) {
    return (hour == 0 || hour == 12) ? '12' : '${hour % 12}';
  }

  /// Format the duration between two times
  String _formatDuration(TimeOfDay start, TimeOfDay end) {
    final startMinutes = start.hour * 60 + start.minute;
    var endMinutes = end.hour * 60 + end.minute;

    // Handle case where end time is on the next day
    if (endMinutes < startMinutes) {
      endMinutes += 24 * 60; // Add a full day
    }

    final durationMinutes = endMinutes - startMinutes;
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}

/// Custom painter for drawing the timeline grid
class _TimelineGridPainter extends CustomPainter {
  final double pixelsPerHour;
  final int hoursDisplayed;
  final Color gridLineColor;

  _TimelineGridPainter({
    required this.pixelsPerHour,
    required this.hoursDisplayed,
    required this.gridLineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridLineColor
      ..strokeWidth = 1;

    // Draw vertical lines for hours
    for (int i = 0; i <= hoursDisplayed; i++) {
      final x = i * pixelsPerHour;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw lighter lines for 30-minute marks
    paint.color = gridLineColor.withOpacity(0.5);
    for (int i = 0; i < hoursDisplayed; i++) {
      final x = i * pixelsPerHour + (pixelsPerHour / 2);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw even lighter lines for 15-minute marks
    paint.color = gridLineColor.withOpacity(0.3);
    for (int i = 0; i < hoursDisplayed; i++) {
      final x1 = i * pixelsPerHour + (pixelsPerHour / 4);
      final x2 = i * pixelsPerHour + (pixelsPerHour * 3 / 4);
      canvas.drawLine(Offset(x1, 0), Offset(x1, size.height), paint);
      canvas.drawLine(Offset(x2, 0), Offset(x2, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

/// Helper methods for time validation and manipulation
class TimeHelper {
  /// Rounds a time to the nearest increment in minutes
  static TimeOfDay roundToNearestIncrement(
      TimeOfDay time, int incrementMinutes) {
    final totalMinutes = time.hour * 60 + time.minute;
    final roundedMinutes =
        ((totalMinutes + incrementMinutes / 2) ~/ incrementMinutes) *
            incrementMinutes;

    return TimeOfDay(
      hour: (roundedMinutes ~/ 60) % 24,
      minute: roundedMinutes % 60,
    );
  }

  /// Checks if a time is within a given range
  static bool isTimeInRange(TimeOfDay time, TimeOfDay start, TimeOfDay end) {
    final timeMinutes = time.hour * 60 + time.minute;
    final startMinutes = start.hour * 60 + start.minute;
    var endMinutes = end.hour * 60 + end.minute;

    // Handle case where end time is on the next day
    if (endMinutes < startMinutes) {
      endMinutes += 24 * 60; // Add a full day
    }

    return timeMinutes >= startMinutes && timeMinutes <= endMinutes;
  }

  /// Adds minutes to a TimeOfDay
  static TimeOfDay addMinutes(TimeOfDay time, int minutes) {
    final totalMinutes = time.hour * 60 + time.minute + minutes;
    return TimeOfDay(
      hour: (totalMinutes ~/ 60) % 24,
      minute: totalMinutes % 60,
    );
  }

  /// Calculates the difference between two times in minutes
  static int minutesBetween(TimeOfDay start, TimeOfDay end) {
    final startMinutes = start.hour * 60 + start.minute;
    var endMinutes = end.hour * 60 + end.minute;

    // Handle case where end time is on the next day
    if (endMinutes < startMinutes) {
      endMinutes += 24 * 60; // Add a full day
    }

    return endMinutes - startMinutes;
  }

  /// Converts a TimeOfDay to a DateTime using a reference date
  static DateTime timeOfDayToDateTime(TimeOfDay time, DateTime referenceDate) {
    return DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
      time.hour,
      time.minute,
    );
  }
}
