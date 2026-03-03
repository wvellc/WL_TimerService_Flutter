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
    required String tag,
    required this.duration,
    required this.stopAt,
    required this.precision,
  }) : _originalDuration = duration, // Save baseline for resets
       _tag = tag; // Unique tag for GetX registration

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
    final uniqueTag = duration.inSeconds.toString() + UniqueKey().toString();
    return Get.put(
      TimerServiceController._(
        tag: uniqueTag,
        duration: duration,
        stopAt: stopAt,
        precision: precision,
      ),
      tag: uniqueTag, // ensures unique controller per call
    );
  }

  // VARIABLES
  Duration duration; // The ACTIVE session length (can be extended temporarily)
  Duration _originalDuration; // The MASTER CONFIG (always starts from here)
  final String _tag; // Unique tag for GetX registration (ensures multiple timers can coexist)
  final Duration stopAt; // stop threshold (if required)
  final _endTime = Rxn<DateTime>(); // when countdown finishes
  final TimerPrecision precision;

  Worker? _worker; // Worker reference for disposal control
  TimerTickCallback? _completion; // completion callback
  bool _fired = false; // prevents double-callback fire
  bool _stopped = false; // NEW: ensures timer stays at 00 after stop()
  bool _isDisposing = false; // Flag to indicate if the controller is in the process of being disposed (used to prevent completion callback on stop when deleting)

  // Global timer source from TimerService
  final TimerService timerService = Get.find<TimerService>();
  final _tickSeconds = 0.obs;
  // Optional per-second tick callback
  TimerTickCallback? _onTick;
  Duration _lastRemaining = Duration.zero;

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
    // When stopped, return last frozen remaining time
    if (_stopped) return _lastRemaining;
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

    // --- ALWAYS START FRESH FROM ORIGINAL ---
    // Start cleans the slate. Extensions from previous runs are discarded.
    duration = _originalDuration;

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
    // Capture final remaining duration before freezing
    _lastRemaining = remainingDuration;
    _worker?.dispose();
    _worker = null;
    _stopped = true; // marks non-active state
  }

  // Resume countdown from remaining duration
  void resume() {
    if (remainingDuration <= Duration.zero) return;

    _endTime.value = DateTime.now().toUtc().add(remainingDuration);
    _stopped = false;

    _worker?.dispose();
    _worker = ever(timerService.currentTime, (_) => _tick());

    _tick(); // immediate update
  }

  // EXTEND TIMER
  /// Adds extra time to the CURRENT running session only.
  /// Does not change the _originalDuration.
  void extendDuration(Duration extraTime) {
    // 1. Update the active session duration
    duration += extraTime;

    // 2. Adjust end time logic
    if (isRunning) {
      _endTime.value = _endTime.value?.add(extraTime);
      _tick(); // force UI update
    } else {
      // If paused/stopped, just add to the frozen duration
      // Note: If you call start() after this, this extension is wiped.
      // If you call resume(), this extension is kept.
      _lastRemaining += extraTime;
    }
  }

  // RESET TIMER
  /// Stops the timer and restarts it.
  /// - If [newDuration] is provided: Updates the MASTER config (_originalDuration).
  /// - If [newDuration] is null: Restarts using the existing MASTER config.
  void reset({
    TimerTickCallback? onCompleted,
    Duration? newDuration,
  }) {
    // keep controller alive for restart
    stop(stopWithCompletion: false, deleteAfterStop: false);

    // Update Master Config if needed
    if (newDuration != null) {
      _originalDuration = newDuration;
      // Note: We don't set 'duration' here because start() does it automatically.
    }

    // Start (which will load from _originalDuration)
    _tickSeconds.value = 0;
    start(onCompleted: onCompleted);
  }

  // STOP TIMER
  /// Stop ticking and freeze display at 00
  void stop({bool stopWithCompletion = true, bool deleteAfterStop = true}) {
    // Capture final remaining duration before freezing
    if (deleteAfterStop) _isDisposing = true;
    _lastRemaining = remainingDuration;

    _worker?.dispose();
    _worker = null;
    _stopped = true;

    if (stopWithCompletion && !_isDisposing && !_fired) {
      _fired = true;

      // Wrap in microtask to ensure it fires even if the worker was just disposed
      Future.microtask(() {
        _completion?.call(Duration(seconds: _tickSeconds.value));
      });
    }

    //Delete controller after stopping to free resources (optional, based on use case)
    if (deleteAfterStop) {
      Future.microtask(() => Get.delete<TimerServiceController>(tag: _tag, force: true));
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
      stop(stopWithCompletion: true, deleteAfterStop: false); // cleanup, completion, delete handled here
    }
  }

  // STATE HELPERS
  /// True if actively running
  bool get isRunning => !_stopped && !_isDisposing && _endTime.value != null && remainingDuration > Duration.zero;

  /// True if completely finished counting
  bool get isFinished => remainingDuration == Duration.zero;
}

/// Callback triggered every second while timer is active.
/// `seconds` represents elapsed time since timer start.
typedef TimerTickCallback = void Function(Duration duration);
