class FaceData {
  final double yaw;
  final double pitch;
  final double roll;
  final double leftEyeOpen;
  final double rightEyeOpen;

  FaceData({
    required this.yaw,
    required this.pitch,
    required this.roll,
    required this.leftEyeOpen,
    required this.rightEyeOpen,
  });

  factory FaceData.fromMap(Map<dynamic, dynamic> map) {
    return FaceData(
      yaw: (map['yaw'] as num?)?.toDouble() ?? 0.0,
      pitch: (map['pitch'] as num?)?.toDouble() ?? 0.0,
      roll: (map['roll'] as num?)?.toDouble() ?? 0.0,
      leftEyeOpen: (map['leftEyeOpen'] as num?)?.toDouble() ?? 0.0,
      rightEyeOpen: (map['rightEyeOpen'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  String toString() {
    return 'FaceData(yaw: $yaw, pitch: $pitch, roll: $roll, leftEyeOpen: $leftEyeOpen, rightEyeOpen: $rightEyeOpen)';
  }
}
