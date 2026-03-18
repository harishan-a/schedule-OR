import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:firebase_orscheduler/features/schedule/models/surgery.dart';
import 'package:firebase_orscheduler/core/theme/app_colors.dart';

/// Shared calendar data source for surgery appointments.
/// Used by both month and week views to avoid code duplication.
/// Previously duplicated in schedule_view_month.dart and schedule_view_week.dart.
class SurgeryDataSource extends CalendarDataSource {
  /// Creates a new data source from a list of surgeries.
  SurgeryDataSource(List<Surgery> source) {
    appointments = source;
  }

  @override
  DateTime getStartTime(int index) {
    return (appointments![index] as Surgery).startTime;
  }

  @override
  DateTime getEndTime(int index) {
    return (appointments![index] as Surgery).endTime;
  }

  @override
  String getSubject(int index) {
    return (appointments![index] as Surgery).surgeryType;
  }

  /// Maps surgery status to display color.
  /// Uses centralized AppColors to avoid duplication.
  @override
  Color getColor(int index) {
    final status = (appointments![index] as Surgery).status;
    return AppColors.getStatusColor(status);
  }

  @override
  String getNotes(int index) {
    return (appointments![index] as Surgery).notes;
  }

  @override
  String getLocation(int index) {
    final surgery = appointments![index] as Surgery;
    return surgery.room.isNotEmpty ? surgery.room.first : surgery.roomId;
  }
}
