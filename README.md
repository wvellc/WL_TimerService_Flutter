# Timer Service Flutter (using GetX)

A robust and efficient Flutter package for managing real-time, lifecycle-aware timers and countdowns using GetX. This package ensures accurate time updates, minimal UI re-rendering, and proper handling of app background/foreground transitions.

---

## 🚀 Installation

Add this to your `pubspec.yaml` file:

```yaml
dependencies:
  flutter:
    sdk: flutter
  get: ^4.6.5 # Replace with the latest version
  timer_service_flutter: ^1.0.0 # Replace with the latest version
```

Then, run:

```bash
flutter pub get
```

---

## 📚 Core Concepts

This package provides three main components:

- **TimerService**: A `GetxService` that provides a global, reactive `DateTime.now()` updated every second. It's lifecycle-aware, ensuring accuracy after app goes into background.
- **FixedTimerController**: A `GetxController` to manage individual fixed-duration timers (e.g., a 60-second OTP countdown).
- **DurationCountdown Extension**: An extension on `Duration` to easily extract days, hours, minutes, and seconds components.

---

## 💡 Usage

### 1. Initialize `TimerService`

The `TimerService` must be initialized once at app startup in `main.dart`.

```dart
// main.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timer_service_flutter/timer_service_flutter.dart'; // Import your package

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize the service 
  TimerService.init(); 
}
```

---

### 2. Countdown to a Future Date/Time

Observe `TimerService.currentTime` to calculate and display remaining time to any future `DateTime`.

```dart
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:timer_service_flutter/timer_service_flutter.dart';

class FutureCountdownWidget extends StatelessWidget {
  final DateTime targetDateTime;
  FutureCountdownWidget({required this.targetDateTime});

  final TimerService timerService = Get.find<TimerService>();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final Duration remaining = targetDateTime.difference(timerService.currentTime.value);
      if (remaining.isNegative) return Text("Event Passed!");

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
import 'package:flutter/material.dart';
import 'package:timer_service_flutter/timer_service_flutter.dart';

class OtpResendTimerWidget extends StatelessWidget {
  final FixedTimerController controller = FixedTimerController(duration: const Duration(seconds: 60));

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Obx(() {
          final Duration remaining = controller.remainingDuration;
          if (controller.isFinished) return Text("OTP Ready!");

          return Text('Resend in ${remaining.inMinutesRemainder}:${remaining.inSecondsRemainder}');
        }),
        Obx(() => ElevatedButton(
              onPressed: controller.isFinished ? controller.resetTimer : null,
              child: Text('Resend OTP'),
            )),
      ],
    );
  }
}
```
