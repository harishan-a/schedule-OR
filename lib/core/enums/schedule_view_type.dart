enum ScheduleViewType {
  day('Day'),
  week('Week'),
  month('Month'),
  tv('TV');

  const ScheduleViewType(this.displayName);
  final String displayName;
}
