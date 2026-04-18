import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:arena/app/app.dart';
import 'package:arena/app/shell.dart';
import 'package:arena/features/cursor_control/logic/face_messenger.dart';
import 'package:arena/features/cursor_control/logic/cursor_controller.dart';
import 'package:arena/features/cursor_control/logic/inactivity_detector.dart';
import 'package:arena/core/services/push_notification_service.dart';

// Global accessors for cursor control (used by CursorOverlay + ProfileScreen toggle)
late CursorController globalCursorController;
late InactivityDetector globalInactivityDetector;

/// Global key for [MainShell] so accessibility voice tour can switch tabs.
final GlobalKey<MainShellState> mainShellKey = GlobalKey<MainShellState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase is not supported on web without FirebaseOptions (web config from Firebase Console).
  // Service account JSON is for server-side only. Skip init on web so the app runs on Chrome.
  if (!kIsWeb) {
    await Firebase.initializeApp();
  }

  await Permission.camera.request();

  final faceMessenger = FaceMessenger();
  final cursorController = CursorController(faceMessenger);
  final inactivityDetector = InactivityDetector();

  globalCursorController = cursorController;
  globalInactivityDetector = inactivityDetector;

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize push notifications (mobile only; requires Firebase)
  if (!kIsWeb) {
    PushNotificationService().init();
  }

  runApp(ArenaApp(
    cursorController: cursorController,
    inactivityDetector: inactivityDetector,
    mainShellKey: mainShellKey,
  ));
}
