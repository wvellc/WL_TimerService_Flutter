//Extension on Duration to easily get countdown units
extension RemainingDuration on Duration {
  /// Returns the number of full days in this duration.
  int get remainingDays => inDays;

  /// Returns the number of hours remaining after accounting for full days.
  int get remainingHours => inHours.remainder(24);

  /// Returns the number of minutes remaining after accounting for full hours.
  int get remainingMinutes => inMinutes.remainder(60);

  /// Returns the number of seconds remaining after accounting for full minutes.
  int get remainingSeconds => inSeconds.remainder(60);
}

