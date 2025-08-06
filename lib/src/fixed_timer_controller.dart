import 'package:get/get.dart';
import 'package:timer_service_flutter/timer_service.dart';

//Fixed Timer Controller
/// This controller manages the state for a single fixed-duration timer.
class FixedTimerController extends GetxController {
  //CONSTRUCTOR
  FixedTimerController({required this.duration, this.stopAt = const Duration(seconds: 1)});

  //VARIABLES
  final Duration duration;
  final Duration stopAt;
  // The end time of the fixed timer. Null if not started/reset.
  final _endTime = Rxn<DateTime>(null);

  // Get the global TimerService instance.
  final TimerService timerService = Get.find<TimerService>();

  // Computed property for remaining duration, reactive via Obx in UI
  Duration get remainingDuration {
    if (_endTime.value == null) {
      // Timer not started, show full duration
      return duration;
    }

    final Duration diff = _endTime.value!.difference(timerService.currentTime.value);
    return diff > stopAt ? diff : Duration.zero;
  }

  //METHODS
  /// Start the fixed timer
  void startTimer() {
    _endTime.value = DateTime.now().toUtc().add(duration);
  }

  /// Reset the fixed timer
  void resetTimer() {
    _endTime.value = null;
    startTimer();
  }

  /// Check if the timer is currently running
  bool get isRunning => _endTime.value != null && remainingDuration > Duration.zero;

  /// Check if the timer has finished
  bool get isFinished => _endTime.value != null && remainingDuration.isNegative;
}
