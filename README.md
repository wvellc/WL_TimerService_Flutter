# Timer Service Flutter (using GetX)

A robust and efficient Flutter package for managing real-time, lifecycle-aware timers and countdowns using GetX. This package ensures accurate time updates, minimal UI re-rendering, and proper handling of app background/foreground transitions.

---

## Getting Started

Add this to your `pubspec.yaml` file:

```yaml
dependencies:
  flutter:
    sdk: flutter
  get: ^4.6.5 # Replace with the latest version
  timer_service_flutter:
    git:
      url: https://github.com/wvellc/WL_TimerService_Flutter.git
      ref: <latest-version>
```

Then, run:

```bash
flutter pub get
```
Import it:

```dart
import 'package:timer_service_flutter/timer_service_flutter.dart';
```
---

### 1. Initialize `TimerService`

The `TimerService` must be initialized once at app startup in `main.dart`.  
You can optionally specify the update precision (default is `second`).

```dart
// main.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timer_service_flutter/timer_service_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize the service with optional precision
  TimerService.init(precision: TimerPrecision.millisecond); 
}

```
### Available TimerPrecision Values

The `TimerPrecision` enum defines the level of granularity for timer updates in `TimerService`:

| Enum Value                  | Description                                      |
|------------------------------|--------------------------------------------------|
| `TimerPrecision.millisecond` | Updates every millisecond (high precision)      |
| `TimerPrecision.second`      | Updates every second (default, lower CPU usage)|
| `TimerPrecision.minute`      | Updates every minute                             |
| `TimerPrecision.hour`        | Updates every hour    

---

### 2. Countdown to a Future Date/Time

Observe `TimerService.currentTime` to calculate and display remaining time to any future `DateTime`.

```dart
// service_example.dart
import 'package:timer_service_flutter/timer_service_flutter.dart';

class FutureCountdownWidget extends StatelessWidget {
  final DateTime targetDateTime;
  FutureCountdownWidget({required this.targetDateTime});
  // Timer service
  final TimerService timerService = Get.find<TimerService>();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Calculate remaining duration using currentTime from timer service
      final Duration remaining = targetDateTime.difference(timerService.currentTime.value);
      if (remaining.isNegative) return Text("Event Passed!");

      // Extracting individual time units from the Duration
      final int days = remaining.inDaysOnly;
      final int hours = remaining.inHoursRemainder;
      final int minutes = remaining.inMinutesRemainder;
      final int seconds = remaining.inSecondsRemainder;

      return Text('$days D, $hours H, $minutes M, $seconds S');
    });
  }
}
```

---

### 3. Fixed Duration Countdown (e.g., OTP Resend Timer)

Create an instance of `FixedTimerController` for each fixed timer. Use `startTimer()` and `resetTimer()` to control it.

```dart
// fixed_timer_example.dart
import 'package:timer_service_flutter/timer_service_flutter.dart';

class FixedTimerWidget extends StatelessWidget {
  // Fixed time controller
  final FixedTimerController controller = FixedTimerController(duration: const Duration(seconds: 60));

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Obx(() {
          // Get remaining duration from controller
          final Duration remaining = controller.remainingDuration;
          if (controller.isFinished) return Text("OTP Ready!");

          return Text('Resend in ${remaining.inMinutesRemainder}:${remaining.inSecondsRemainder}');
        }),
        /// Disable button click while timer is running & restart using `resetTimer()`
        Obx(() {
            return ElevatedButton(
                onPressed: controller.isFinished ? controller.resetTimer : null,
                child: Text('Resend OTP'),
            );
        }),
      ],
    );
  }
}
```
