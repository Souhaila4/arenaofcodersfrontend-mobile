
import 'dart:async';
import 'dart:math';
import 'package:flutter/widgets.dart';
import '../data/face_data.dart';
import 'face_messenger.dart';

class CursorController extends ChangeNotifier {
  final FaceMessenger _messenger;
  
  Offset _cursorPosition = Offset.zero;
  Offset get cursorPosition => _cursorPosition;
  
  bool _isClicking = false;
  bool get isClicking => _isClicking;

  final StreamController<void> _clickStreamController = StreamController<void>.broadcast();
  Stream<void> get clickStream => _clickStreamController.stream;

  // Calibration & Debug
  double _zeroYaw = 0.0;
  double _zeroPitch = 0.0;
  
  double _currentYaw = 0.0;
  double _currentPitch = 0.0;
  
  double get rawYaw => _currentYaw;
  double get rawPitch => _currentPitch;
  
  // Settings
  bool invertX = false; // Default to Direct (Face Right -> Cursor Right)
  bool invertY = false;
  bool swapXY = true; // Default to Portrait Mode (Fixes "Right -> Down")
  double sensitivity = 800.0;
  
  // Public Notifier for UI status updates
  final ValueNotifier<bool> isClickingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isFaceDetectedNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isRunningNotifier = ValueNotifier(false); // Default to off
  Timer? _lossTimer;

  // Screen Size (must be updated from UI)
  Size _screenSize = Size.zero;
  
  final OneEuroFilter _filterX = OneEuroFilter(minCutoff: 1.0, beta: 0.08);
  final OneEuroFilter _filterY = OneEuroFilter(minCutoff: 1.0, beta: 0.08);

  StreamSubscription? _subscription;

  bool _stopped = false;

  CursorController(this._messenger);

  void start() {
    _stopped = false;
    isRunningNotifier.value = true;
    _isClicking = false;
    _filterX.reset();
    _filterY.reset();
    // EventChannel.listen triggers onListen in Kotlin which calls startCamera()
    // Do NOT call _messenger.startCamera() separately — it causes double-start
    _subscription = _messenger.faceDataStream.listen(_onFaceData);
  }

  void stop() {
    _stopped = true;
    isRunningNotifier.value = false;
    // Cancelling the subscription triggers onCancel in Kotlin which stops camera
    // Do NOT call _messenger.stopCamera() separately
    _subscription?.cancel();
    _subscription = null;
    _lossTimer?.cancel();
    // Do NOT dispose notifiers here - they may be restarted
    // Only dispose in dispose()
  }
  
  void setInvertX(bool value) {
    invertX = value;
    notifyListeners();
  }
  
  void setInvertY(bool value) {
    invertY = value;
    notifyListeners();
  }
  
  void setSwapXY(bool value) {
    swapXY = value;
    notifyListeners();
  }
  
  void setSensitivity(double value) {
    sensitivity = value;
    notifyListeners();
  }

  void updateScreenSize(Size size) {
    _screenSize = size;
    // Reset cursor to center if it's the first time
    if (_cursorPosition == Offset.zero) {
      _cursorPosition = Offset(size.width / 2, size.height / 2);
    }
  }

  void calibrate() {
    _pendingCalibration = true;
  }
  
  bool _pendingCalibration = false;

  void _onFaceData(FaceData data) {
    // Guard: ignore data after stop/dispose
    if (_stopped) return;

    // Face Detected logic
    if (!isFaceDetectedNotifier.value) {
      isFaceDetectedNotifier.value = true;
    }
    _lossTimer?.cancel();
    _lossTimer = Timer(const Duration(milliseconds: 500), () {
      isFaceDetectedNotifier.value = false;
    });

    // Update debug values
    _currentYaw = data.yaw;
    _currentPitch = data.pitch;

    if (_pendingCalibration) {
      _zeroYaw = data.yaw;
      _zeroPitch = data.pitch;
      _pendingCalibration = false;
    }

    // click detection (both eyes closed)
    // EAR < 0.15 = eyes definitely closed
    debugPrint("EAR: L=${data.leftEyeOpen.toStringAsFixed(3)} R=${data.rightEyeOpen.toStringAsFixed(3)}");
    bool clicking = data.leftEyeOpen < 0.15 && data.rightEyeOpen < 0.15;
    if (clicking != _isClicking) {
      _isClicking = clicking;
      isClickingNotifier.value = clicking;
      notifyListeners();
      if (_isClicking) {
        debugPrint("CLICK REGISTERED!");
        _clickStreamController.add(null);
      }
    }

    // Movement logic
    double deltaYaw = data.yaw - _zeroYaw;
    double deltaPitch = data.pitch - _zeroPitch;

    // Deadzone to reduce jitter
    if (deltaYaw.abs() < 0.005) deltaYaw = 0.0;
    if (deltaPitch.abs() < 0.005) deltaPitch = 0.0;
    
    // Apply Settings
    // IF SWAPPED (Portrait Mode fix):
    
    double inputX, inputY;
    
    if (swapXY) {
       // Swap the inputs: Pitch drives X, Yaw drives Y
       inputX = deltaPitch;
       inputY = deltaYaw;
    } else {
       inputX = deltaYaw;
       inputY = deltaPitch;
    }
    
    // Apply sensitivity & Inversion
    double moveX = inputX * sensitivity;
    if (invertX) moveX = -moveX;
    
    double moveY = inputY * sensitivity;
    if (invertY) moveY = -moveY;

    double rawX = _screenSize.width / 2 + moveX;
    double rawY = _screenSize.height / 2 + moveY;

    // Filter
    double timestamp = DateTime.now().millisecondsSinceEpoch / 1000.0;
    double x = _filterX.filter(rawX, timestamp);
    double y = _filterY.filter(rawY, timestamp);

    // Clamp to screen
    if (_screenSize != Size.zero) {
      x = x.clamp(0.0, _screenSize.width);
      y = y.clamp(0.0, _screenSize.height);
    }

    _cursorPosition = Offset(x, y);
    
    // Debug: Log position updates (comment out in production)
    // debugPrint("📍 Cursor: ($x, $y)");
    
    notifyListeners();
  }
  
  @override
  void dispose() {
    _clickStreamController.close();
    stop();
    isClickingNotifier.dispose();
    isFaceDetectedNotifier.dispose();
    super.dispose();
  }
}

// Simple OneEuroFilter implementation for Dart
class OneEuroFilter {
  double _minCutoff = 1.0;
  double _beta = 0.0;
  double _dCutoff = 1.0;
  
  double? _prevValue;
  double? _prevDerivative;
  double? _prevTimestamp;

  OneEuroFilter({double minCutoff = 1.0, double beta = 0.007, double dCutoff = 1.0}) {
    _minCutoff = minCutoff;
    _beta = beta;
    _dCutoff = dCutoff;
  }

  void reset() {
    _prevValue = null;
    _prevDerivative = null;
    _prevTimestamp = null;
  }

  double filter(double value, double timestamp) {
    if (_prevTimestamp == null || _prevValue == null || _prevDerivative == null) {
      _prevValue = value;
      _prevDerivative = 0.0;
      _prevTimestamp = timestamp;
      return value;
    }

    double dt = timestamp - _prevTimestamp!;
    
    // Compute alpha for the derivative filter
    double alphaD = _smoothingFactor(dt, _dCutoff);
    
    // Compute derivative
    double derivative = (value - _prevValue!) / dt;
    double dxHat = _exponentialSmoothing(alphaD, derivative, _prevDerivative!);
    
    // Compute alpha for the value filter
    double cutoff = _minCutoff + _beta * dxHat.abs();
    double alpha = _smoothingFactor(dt, cutoff);
    
    // Filter value
    double xHat = _exponentialSmoothing(alpha, value, _prevValue!);
    
    _prevValue = xHat;
    _prevDerivative = dxHat;
    _prevTimestamp = timestamp;
    
    return xHat;
  }

  double _smoothingFactor(double dt, double cutoff) {
    double r = 2 * pi * cutoff * dt;
    return r / (r + 1);
  }

  double _exponentialSmoothing(double alpha, double x, double xPrev) {
    return alpha * x + (1 - alpha) * xPrev;
  }
}
