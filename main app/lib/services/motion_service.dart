import 'dart:async';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shake/shake.dart';

class MotionService {
  StreamSubscription<AccelerometerEvent>? _accelSub;
  ShakeDetector? _shakeDetector;

  // Sensitivity: higher => easier to trigger
  double sensitivity; // 0.5 (low) to 3.0 (high)
  final void Function()? onShakePanic;
  final void Function()? onImpactDetected;

  MotionService({
    this.sensitivity = 1.5,
    this.onShakePanic,
    this.onImpactDetected,
  });

  void start() {
    // Shake panic (3 shakes)
    _shakeDetector = ShakeDetector.autoStart(
      shakeSlopTimeMS: 500,
      shakeCountResetTime: 1500,
      minimumShakeCount: 3,
      shakeThresholdGravity: (12 / sensitivity),
      onPhoneShake: (_) => onShakePanic?.call(),
    );

    // Impact/fall detection (very simple heuristic)
    _accelSub = accelerometerEventStream().listen((e) {
      final g2 = e.x * e.x + e.y * e.y + e.z * e.z;
      final gForce = math.sqrt(g2);
      if (gForce > (35 / sensitivity)) {
        onImpactDetected?.call();
      }
    });
  }

  void stop() {
    _shakeDetector?.stopListening();
    _accelSub?.cancel();
  }
}
