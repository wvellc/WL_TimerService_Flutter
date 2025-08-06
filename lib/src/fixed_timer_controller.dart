import 'dart:ui';
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
  final Rx<DateTime?> _endTime = Rx<DateTime?>(null);

  // Get the global TimerService instance.
  final TimerService timerService = Get.find<TimerService>();

  // Internal callback for the current timer run's completion.
  VoidCallback? _currentCompletionCallback;

  // Internal flag to ensure the completion callback is only fired once per timer cycle.
  final RxBool _firedCompletion = false.obs;

  // Computed property for remaining duration, reactive via Obx in UI
  Duration get remainingDuration {
    if (_endTime.value == null) {
      // Timer not started, show full duration
      return duration;
    }

    // Calculate difference using local DateTime objects.
    final Duration diff = _endTime.value!.difference(timerService.currentTime.value);
    return diff > stopAt ? diff : Duration.zero;
  }

  //LIFECYCLE
  @override
  void onInit() {
    super.onInit();
    // Listen to changes in the underlying reactive properties (_endTime and timerService.currentTime)
    // that affect the remainingDuration. When they change, check if the timer has completed.
    ever(_endTime, (_) => _checkCompletion());
    ever(timerService.currentTime, (_) => _checkCompletion());
  }

  @override
  void onClose() {
    _currentCompletionCallback = null;
    _endTime.value = null;
    _firedCompletion.value = false;
    super.onClose();
  }

  //METHODS
  /// Start the fixed timer
  /// Optionally accepts an [onCompleted] callback that will be invoked
  /// when the timer finishes counting down.
  void startTimer({VoidCallback? onCompleted}) {
    // Set end time using current local DateTime.
    _endTime.value = DateTime.now().add(duration);
    _currentCompletionCallback = onCompleted; // Store the callback for this run
    _firedCompletion.value = false; // Reset completion flag for a new start
  }

  /// Reset the fixed timer
  void resetTimer() {
    _endTime.value = null;
    _firedCompletion.value = false; // Reset completion flag
    startTimer(onCompleted: _currentCompletionCallback); // Restart the timer
  }

  /// Check if the timer is currently running
  bool get isRunning => _endTime.value != null && remainingDuration > Duration.zero;

  /// Check if the timer has finished
  bool get isFinished => _endTime.value != null && remainingDuration.isNegative;

  /// Internal method to check for timer completion and trigger the registered callbacks.
  void _checkCompletion() {
    // Only check for completion if the timer has actually been started
    // and a completion callback is set for the current run.
    if (_endTime.value != null && _currentCompletionCallback != null) {
      // If remainingDuration is zero or negative and the completion callback hasn't fired yet,
      // mark as completed and invoke the current callback.
      if (remainingDuration <= Duration.zero && !_firedCompletion.value) {
        _firedCompletion.value = true;
        _currentCompletionCallback?.call(); // Invoke the callback
      }
    }
  }
}
