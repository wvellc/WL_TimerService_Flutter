import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

// Timer Service
/// This service will manage the lifecycle-aware timer.
class TimerService extends GetxService with WidgetsBindingObserver {
  TimerService._();
  // Static initialization method for the package
  static void init() {
    if (!Get.isRegistered<TimerService>()) {
      Get.put<TimerService>(TimerService._(), permanent: true);
    }
  }

  //VARIABLES
  final Rx<DateTime> currentTime = DateTime.now().obs;

  Ticker? _ticker;
  late final TickerProvider _tickerProvider;

  //LIFECYCLE
  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);

    // Initialize the custom TickerProvider.
    _tickerProvider = _ServiceTickerProvider();

    // Create Flutter's Ticker. The callback will be fired on each frame.
    _ticker = _tickerProvider.createTicker((elapsed) {
      // We update it only if a second has actually passed since the last known time
      // or if it's the very first tick. This prevents unnecessary updates
      // if frames are drawn more frequently than seconds change.
      final newTime = DateTime.now();
      if (newTime.second != currentTime.value.second || newTime.minute != currentTime.value.minute || newTime.hour != currentTime.value.hour) {
        currentTime.value = newTime;
      }
    });

    //Start ticker
    _ticker?.start();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    // Stop and dispose the ticker when the service is closed.
    _ticker?.dispose();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kDebugMode) {
      print('AppLifecycleState changed: $state');
    }
    if (state == AppLifecycleState.resumed) {
      // When the app comes back to the foreground, force an immediate update
      // to ensure the UI reflects the absolute latest real-world time.
      currentTime.value = DateTime.now();
      if (kDebugMode) {
        print('App resumed, currentTime updated immediately.');
      }
    }
    // Ticker automatically pauses/resumes with the rendering pipeline,
    // so explicit _ticker?.stop() or _ticker?.start() is not strictly needed here
    // for pause/resume, but it's good for immediate data refresh.
  }
}

// Custom TickerProvider
/// This allows the GetxService to create and manage a Flutter Ticker.
class _ServiceTickerProvider implements TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) {
    return Ticker(onTick);
  }
}

//Extension on Duration to easily get countdown units
extension RemainingDurationExt on Duration {
  /// Returns the number of full days in this duration.
  int get remainingDays => inDays;

  /// Returns the number of hours remaining after accounting for full days.
  int get remainingHours => inHours.remainder(24);

  /// Returns the number of minutes remaining after accounting for full hours.
  int get remainingMinutes => inMinutes.remainder(60);

  /// Returns the number of seconds remaining after accounting for full minutes.
  int get remainingSeconds => inSeconds.remainder(60);
}
