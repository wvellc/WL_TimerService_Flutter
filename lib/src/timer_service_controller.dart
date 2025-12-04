import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:timer_service_flutter/timer_service.dart';

/// FixedDuration TimerController
/// - Private constructor ensures controlled creation only through `.init()`
/// - Safe lifecycle & disposable Workers
/// - No external Get.put() required
/// - Worker runs only when countdown is active (no resource waste)
class TimerServiceController extends GetxController {
  // PRIVATE CONSTRUCTOR
  TimerServiceController._({
    required this.duration,
    required this.stopAt,
    required this.precision,
  });

  // STATIC FACTORY METHOD
  /// Creates, registers & starts a timer instance
  /// Not permanent, removed automatically after completion
  /// Can be called anywhere without external controller allocation
  static TimerServiceController init({
    required Duration duration,
    Duration stopAt = const Duration(seconds: 1),
    TimerPrecision precision = TimerPrecision.second,
  }) {
    // Initialize TimerService dynamically if it isn't available
    if (!Get.isRegistered<TimerService>()) {
      TimerService.init(precision: precision);
    }
    // If TimerService exists but precision changed — update dynamically
    else if (precision != TimerService.currentPrecision) {
      TimerService.setPrecision(precision); // <-- new helper method required in service
    }
    return Get.put(
      TimerServiceController._(
        duration: duration,
        stopAt: stopAt,
        precision: precision,
      ),
      tag: duration.inSeconds.toString() + UniqueKey().toString(), // ensures unique controller per call
    );
  }

  // VARIABLES
  final Duration duration; // total countdown length
  final Duration stopAt; // stop threshold (if required)
  final _endTime = Rxn<DateTime>(); // when countdown finishes
  final TimerPrecision precision;

  Worker? _worker; // Worker reference for disposal control
  TimerTickCallback? _completion; // completion callback
  bool _fired = false; // prevents double-callback fire
  bool _stopped = false; // NEW: ensures timer stays at 00 after stop()

  // Global timer source from TimerService
  final TimerService timerService = Get.find<TimerService>();
  final _tickSeconds = 0.obs;
  // Optional per-second tick callback
  TimerTickCallback? _onTick;

  // GETX LIFECYCLE
  @override
  void onClose() {
    // ensure worker cleanup
    stop();
    super.onClose();
  }

  // COMPUTED REMAINING TIME
  /// Dynamically determines remaining time using `_endTime` and real clock
  Duration get remainingDuration {
    // Before timer starts, return full duration
    if (_endTime.value == null) return duration;

    // Calculate time difference
    final diff = _endTime.value!.difference(timerService.currentTime.value);

    // Clamp negative values to zero
    return diff > stopAt ? diff : Duration.zero;
  }

  // INTERNAL START LOGIC
  void start({
    TimerTickCallback? onCompleted,
    TimerTickCallback? onTick,
  }) {
    _completion = onCompleted;
    _onTick ??= onTick;

    _fired = false;
    _stopped = false;

    _tickSeconds.value = 0; // reset tick count on fresh start
    // Notify first tick instantly (so UI/outside variable sync correctly)
    _onTick?.call(Duration.zero);

    // Calculate end time
    _endTime.value = DateTime.now().toUtc().add(duration);

    // Dispose old Worker if existed
    _worker?.dispose();

    // Create worker watching global timer ticks
    _worker = ever(timerService.currentTime, (_) => _tick());

    // Immediate tick for first emission
    _tick();
  }

  // Pause timer (keep remaining time unchanged, but stop ticking)
  void pause() {
    _worker?.dispose();
    _worker = null;
    _stopped = true; // marks non-active state
  }

  // Resume countdown from remaining duration
  void resume() {
    if (remainingDuration <= Duration.zero) return;

    _stopped = false;
    _endTime.value = DateTime.now().toUtc().add(remainingDuration);

    _worker?.dispose();
    _worker = ever(timerService.currentTime, (_) => _tick());

    _tick(); // immediate update
  }

  // RESET TIMER
  /// Reset the timer and restart fresh
  void reset({TimerTickCallback? onCompleted}) {
    stop(stopWithCompletion: false);
    _tickSeconds.value = 0; // full reset on manual reset
    start(onCompleted: onCompleted);
  }

  // STOP TIMER
  /// Stop ticking and freeze display at 00
  void stop({bool stopWithCompletion = true}) {
    _worker?.dispose();
    _worker = null;
    _stopped = true;

    if (stopWithCompletion) {
      if (!_fired) {
        _fired = true;
        _completion?.call(Duration(seconds: _tickSeconds.value));
      }
      // Now delete the controller here (single responsibility)
      Future.microtask(
        () => Get.delete<TimerServiceController>(
          tag: hashCode.toString(),
          force: true,
        ),
      );
    }
  }

  // INTERNAL COMPLETION CHECK
  void _tick() {
    if (_endTime.value == null || _stopped) return;
    // Increment tickSeconds only while timer is running & not stopped
    // real second elapsed diff calculation
    final elapsedSeconds = duration.inSeconds - remainingDuration.inSeconds;

    if (elapsedSeconds != _tickSeconds.value) {
      _tickSeconds.value = elapsedSeconds;
      _onTick?.call(Duration(seconds: elapsedSeconds));
    }

    // Delegate finishing to stop()
    if (remainingDuration <= stopAt) {
      stop(stopWithCompletion: true); // cleanup, completion, delete handled here
    }
  }

  // STATE HELPERS
  /// True if actively running
  bool get isRunning => !_stopped && _endTime.value != null && remainingDuration > Duration.zero;

  /// True if completely finished counting
  bool get isFinished => remainingDuration == Duration.zero;
}

/// Callback triggered every second while timer is active.
/// `seconds` represents elapsed time since timer start.
typedef TimerTickCallback = void Function(Duration duration);
