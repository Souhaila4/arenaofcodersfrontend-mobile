import 'dart:async';
import 'package:flutter/foundation.dart';

/// Detects user inactivity and notifies listeners when the user has been idle
/// for a specified duration (default: 5 seconds).
class InactivityDetector extends ChangeNotifier {
  Timer? _timer;
  bool _isIdle = false;
  final Duration inactivityDuration;

  InactivityDetector({this.inactivityDuration = const Duration(seconds: 5)});

  /// Returns true if the user has been idle for the specified duration
  bool get isIdle => _isIdle;

  /// Call this method whenever the user interacts with the screen
  /// (touch, pointer down, pointer move, etc.)
  void onUserInteraction() {
    // If we were idle, we're now active
    if (_isIdle) {
      _isIdle = false;
      notifyListeners();
    }

    // Cancel any existing timer
    _timer?.cancel();

    // Start a new timer
    _timer = Timer(inactivityDuration, () {
      _isIdle = true;
      notifyListeners();
    });
  }

  /// Reset the detector to non-idle state and cancel the timer
  void reset() {
    _timer?.cancel();
    if (_isIdle) {
      _isIdle = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
