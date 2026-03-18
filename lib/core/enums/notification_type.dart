enum NotificationType {
  surgeryScheduled('Surgery Scheduled'),
  surgeryUpdated('Surgery Updated'),
  surgeryStatusChanged('Status Changed'),
  surgeryApproaching('Surgery Approaching'),
  surgeryReminder('Surgery Reminder'),
  general('General');

  const NotificationType(this.displayName);
  final String displayName;

  static NotificationType fromString(String type) {
    for (final value in NotificationType.values) {
      if (value.name == type || value.displayName == type) {
        return value;
      }
    }
    return NotificationType.general;
  }
}
