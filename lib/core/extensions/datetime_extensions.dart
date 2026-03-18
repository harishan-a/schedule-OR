import 'package:intl/intl.dart';

extension DateTimeExtensions on DateTime {
  String get formattedDate => DateFormat('MMM d, y').format(this);
  String get formattedTime => DateFormat('h:mm a').format(this);
  String get formattedDateTime => DateFormat('MMM d, y h:mm a').format(this);
  String get formattedShortDate => DateFormat('MM/dd/yy').format(this);
  String get dayOfWeekShort => DateFormat('EEE').format(this);

  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }

  DateTime get startOfDay => DateTime(year, month, day);
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59);
}
