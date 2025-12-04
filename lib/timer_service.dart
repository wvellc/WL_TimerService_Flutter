import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

/// Precision levels for how frequently the TimerService updates `currentTime`.
/// - millisecond → every frame, checks millisecond change
/// - second → every frame, checks second change
/// - minute → every frame, checks minute change
/// - hour → every frame, checks hour change
enum TimerPrecision { millisecond, second, minute, hour }

// Timer Service
/// A lifecycle-aware, ticker-driven time source that provides accurate time
/// updates even when the app is minimized or in background.
/// No Timer.periodic() is used so the service never freezes.
class TimerService extends GetxService with WidgetsBindingObserver {
  TimerService._();

  // Static initialization method
  static void init({TimerPrecision precision = TimerPrecision.second}) {
    _precision = precision;
    if (!Get.isRegistered<TimerService>()) {
      Get.put<TimerService>(TimerService._(), permanent: true);
    }
  }

  // VARIABLES
  final Rx<DateTime> currentTime = DateTime.now().toUtc().obs;

  Ticker? _ticker;
  late final TickerProvider _tickerProvider;

  // Selected precision
  static TimerPrecision _precision = TimerPrecision.second;
  static TimerPrecision get currentPrecision => _precision;
  // Last emitted time used for drift correction
  DateTime _lastEmitted = DateTime.now().toUtc();

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);

    _tickerProvider = _ServiceTickerProvider();

    /// Use flutter’s internal frame callbacks.
    /// Runs even if app is minimized or sleeping → NO freeze.
    _ticker = _tickerProvider.createTicker((elapsed) {
      final now = DateTime.now().toUtc();

      // === DRIFT CORRECTION ===
      // It ensures that if device sleeps/wakes, time does not "jump backwards".
      if (now.isBefore(_lastEmitted)) {
        // Device time changed backwards → force sync
        _lastEmitted = now;
        currentTime.value = now;
        return;
      }

      // === PRECISION BASED UPDATE ===
      bool shouldUpdate = false;

      switch (_precision) {
        case TimerPrecision.millisecond:
          // Update if any part of time changed (ms, sec, min, hr)
          shouldUpdate = now.millisecond != _lastEmitted.millisecond || now.second != _lastEmitted.second || now.minute != _lastEmitted.minute || now.hour != _lastEmitted.hour;
          break;

        case TimerPrecision.second:
          // Update if second, minute, or hour changed
          shouldUpdate = now.second != _lastEmitted.second || now.minute != _lastEmitted.minute || now.hour != _lastEmitted.hour;
          break;

        case TimerPrecision.minute:
          // Update if minute or hour changed
          shouldUpdate = now.minute != _lastEmitted.minute || now.hour != _lastEmitted.hour;
          break;

        case TimerPrecision.hour:
          // Update only if hour changed
          shouldUpdate = now.hour != _lastEmitted.hour;
          break;
      }

      // Emit update if needed
      if (shouldUpdate) {
        _lastEmitted = now;
        currentTime.value = now;
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
    if (kDebugMode) print('AppLifecycleState changed: $state');

    if (state == AppLifecycleState.resumed) {
      // Force sync on resume for fresh real time
      final now = DateTime.now().toUtc();
      _lastEmitted = now;
      currentTime.value = now;
      if (kDebugMode) print("Time synced immediately on resume");
    }
  }

  static void setPrecision(TimerPrecision newPrecision) {
    _precision = newPrecision;
  }
}

// Custom TickerProvider — unchanged name
class _ServiceTickerProvider implements TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}
