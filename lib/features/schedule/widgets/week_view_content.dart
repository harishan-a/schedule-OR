// =============================================================================
// Week View Content Widget
// =============================================================================
// A widget that displays surgeries in a weekly calendar format with:
// - Interactive day selection
// - Today highlighting
// - Surgery filtering by day
// - Chronological ordering
//
// Features:
// - Week day header with date indicators
// - Current day highlighting
// - Selected day state management
// - Surgery card display
//
// Note: This widget provides a week-based view of surgeries with
// easy navigation between days and clear visual indicators for
// the current day and selection state.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_orscheduler/features/schedule/models/surgery.dart';
import 'package:intl/intl.dart';

/// Displays surgeries in a weekly calendar format
class WeekViewContent extends StatefulWidget {
  /// List of surgeries to display in the weekly view
  final List<Surgery> surgeries;

  const WeekViewContent({
    super.key,
    required this.surgeries,
  });

  @override
  State<WeekViewContent> createState() => _WeekViewContentState();
}

class _WeekViewContentState extends State<WeekViewContent> {
  /// Currently selected date for viewing surgeries
  late DateTime _selectedDate;

  /// List of dates representing the current week
  late List<DateTime> _weekDays;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _updateWeekDays();
  }

  /// Updates the list of dates for the current week
  ///
  /// Calculates dates starting from Monday of the current week
  /// through Sunday, ensuring a complete week view
  void _updateWeekDays() {
    // Get the start of the week (Monday)
    final monday = _selectedDate.subtract(
      Duration(days: _selectedDate.weekday - 1),
    );
    _weekDays = List.generate(
      7,
      (index) => monday.add(Duration(days: index)),
    );
  }

  /// Filters surgeries for a specific day
  ///
  /// Parameters:
  /// - day: The date to filter surgeries for
  ///
  /// Returns a sorted list of surgeries for the specified day
  List<Surgery> _getSurgeriesForDay(DateTime day) {
    return widget.surgeries.where((surgery) {
      return surgery.dateTime.year == day.year &&
          surgery.dateTime.month == day.month &&
          surgery.dateTime.day == day.day;
    }).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildWeekHeader(),
        Expanded(
          child: _buildDayView(),
        ),
      ],
    );
  }

  /// Builds the week header with interactive day selection
  ///
  /// Features:
  /// - Day name display
  /// - Date number display
  /// - Current day indicator
  /// - Selected day highlighting
  Widget _buildWeekHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
      ),
      child: Row(
        children: _weekDays.map((day) {
          final isSelected = day.day == _selectedDate.day;
          final isToday = day.day == DateTime.now().day &&
              day.month == DateTime.now().month &&
              day.year == DateTime.now().year;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDate = day;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    // Day name (e.g., Mon, Tue)
                    Text(
                      DateFormat('E').format(day),
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : Theme.of(context).textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Date number with today indicator
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isToday ? Theme.of(context).primaryColor : null,
                      ),
                      child: Center(
                        child: Text(
                          day.day.toString(),
                          style: TextStyle(
                            color: isSelected || isToday
                                ? Colors.white
                                : Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Builds the view of surgeries for the selected day
  ///
  /// Features:
  /// - Empty state handling
  /// - Scrollable surgery list
  /// - Surgery card display
  Widget _buildDayView() {
    final surgeries = _getSurgeriesForDay(_selectedDate);
    if (surgeries.isEmpty) {
      return const Center(
        child: Text('No surgeries scheduled for this day'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: surgeries.length,
      itemBuilder: (context, index) {
        final surgery = surgeries[index];
        return Card(
          child: ListTile(
            title: Text(surgery.patientName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DateFormat('h:mm a').format(surgery.dateTime)),
                Text(
                    'Room: ${surgery.roomId} • Duration: ${surgery.duration} min'),
              ],
            ),
            trailing: Text(surgery.status),
          ),
        );
      },
    );
  }
}
