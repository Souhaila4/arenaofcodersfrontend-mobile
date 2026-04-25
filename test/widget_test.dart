import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arena/app/app.dart';
import 'package:arena/app/shell.dart';
import 'package:arena/features/cursor_control/logic/face_messenger.dart';
import 'package:arena/features/cursor_control/logic/cursor_controller.dart';
import 'package:arena/features/cursor_control/logic/inactivity_detector.dart';

void main() {
  testWidgets('ArenaApp smoke test', (WidgetTester tester) async {
    final faceMessenger = FaceMessenger();
    final cursorController = CursorController(faceMessenger);
    final inactivityDetector = InactivityDetector();
    final mainShellKey = GlobalKey<MainShellState>();

    await tester.pumpWidget(ArenaApp(
      cursorController: cursorController,
      inactivityDetector: inactivityDetector,
      mainShellKey: mainShellKey,
    ));
  });
}
