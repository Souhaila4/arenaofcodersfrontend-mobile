import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../data/face_data.dart';

class FaceMessenger {
  static const MethodChannel _methodChannel = MethodChannel('face_mesh/control');
  static const EventChannel _eventChannel = EventChannel('face_mesh/data');

  Stream<FaceData>? _faceDataStream;

  Stream<FaceData> get faceDataStream {
    _faceDataStream ??= _eventChannel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return FaceData.fromMap(event);
      } else {
        // Fallback or empty
        return FaceData(yaw: 0, pitch: 0, roll: 0, leftEyeOpen: 0, rightEyeOpen: 0);
      }
    });
    return _faceDataStream!;
  }

  Future<void> startCamera() async {
    try {
      await _methodChannel.invokeMethod('startCamera');
    } on PlatformException catch (e) {
      debugPrint("Failed to start camera: '${e.message}'.");
    }
  }

  Future<void> stopCamera() async {
    try {
      await _methodChannel.invokeMethod('stopCamera');
    } on PlatformException catch (e) {
      debugPrint("Failed to stop camera: '${e.message}'.");
    }
  }
}
