# 🖱️ Hands-Free Cursor System - Master Integration Guide

This guide allows an AI agent or developer to integrate the **Hands-Free Cursor Control** system into **ANY** Flutter project.

## 📦 1. File Structure Setup

First, copy the entire `features/cursor_control` folder from the source project to the target project:
`lib/features/cursor_control/` -> `TARGET_PROJECT/lib/features/cursor_control/`

This folder should contain:
- `logic/cursor_controller.dart`
- `logic/face_messenger.dart`
- `logic/inactivity_detector.dart`
- `logic/one_euro_filter.dart`
- `ui/cursor_overlay.dart`
- `ui/face_calibration_screen.dart`
- `data/face_data.dart`

---

## 🤖 2. Android Integration

### A. Add Dependencies
Open `android/app/build.gradle` and add to `dependencies {}`:
```gradle
dependencies {
    // MediaPipe & CameraX
    implementation 'com.google.mediapipe:tasks-vision:0.10.14'
    implementation "androidx.camera:camera-core:1.3.0"
    implementation "androidx.camera:camera-camera2:1.3.0"
    implementation "androidx.camera:camera-lifecycle:1.3.0"
    implementation "androidx.camera:camera-view:1.3.0"
}
```

### B. Add Permissions
Open `android/app/src/main/AndroidManifest.xml` and add:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" />
```

### C. Create Native Bridge (Kotlin)
Create file: `android/app/src/main/kotlin/com/example/YOUR_APP_NAME/face_mesh/FaceMeshDetector.kt`
*(Note: Adjust package name to match your app)*

```kotlin
package com.example.YOUR_APP_NAME.face_mesh // ADJUST THIS!

import android.content.Context
import android.util.Log
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker.FaceLandmarkerOptions
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class FaceMeshDetector(private val context: Context, private val lifecycleOwner: LifecycleOwner) : EventChannel.StreamHandler {
    private var faceLandmarker: FaceLandmarker? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private var cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var eventSink: EventChannel.EventSink? = null
    private var isTracking = false

    init {
        setupFaceLandmarker()
    }

    private fun setupFaceLandmarker() {
        val baseOptions = BaseOptions.builder()
            .setModelAssetPath("face_landmarker.task") // MUST BE IN ASSETS
            .build()

        val options = FaceLandmarkerOptions.builder()
            .setBaseOptions(baseOptions)
            .setMinFaceDetectionConfidence(0.5f)
            .setMinFacePresenceConfidence(0.5f)
            .setMinTrackingConfidence(0.5f)
            .setRunningMode(RunningMode.LIVE_STREAM)
            .setResultListener { result, _ ->
                if (result.faceLandmarks().isNotEmpty()) {
                    val landmarks = result.faceLandmarks()[0]
                    // Basic Head Pose Estimation (simplified)
                    // Note: Real implementation needs strict math for Yaw/Pitch
                    // Sending raw normalized coordinates of nose tip (idx 1) and eyes
                    val nose = landmarks[1]
                    val leftEye = landmarks[33]
                    val rightEye = landmarks[263]
                    
                    val data = mapOf(
                        "yaw" to (nose.x() - 0.5) * 2, // Approx Yaw
                        "pitch" to (nose.y() - 0.5) * 2, // Approx Pitch
                        "leftEyeOpen" to 1.0, // Placeholder, implement EAR if needed
                        "rightEyeOpen" to 1.0
                    )
                    
                    runOnMain { eventSink?.success(data) }
                }
            }
            .setErrorListener { e -> Log.e("FaceMesh", "Error: ${e.message}") }
            .build()

        faceLandmarker = FaceLandmarker.createFromOptions(context, options)
    }

    fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        cameraProviderFuture.addListener({
            cameraProvider = cameraProviderFuture.get()
            val cameraSelector = CameraSelector.DEFAULT_FRONT_CAMERA
            val analysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()

            analysis.setAnalyzer(cameraExecutor) { imageProxy ->
                processImage(imageProxy)
            }

            try {
                cameraProvider?.unbindAll()
                cameraProvider?.bindToLifecycle(lifecycleOwner, cameraSelector, analysis)
                isTracking = true
            } catch (e: Exception) {
                Log.e("FaceMesh", "Camera bind failed", e)
            }
        }, ContextCompat.getMainExecutor(context))
    }

    private fun processImage(imageProxy: ImageProxy) {
        if (faceLandmarker != null) {
            val bitmap = imageProxy.toBitmap()
            val mpImage = BitmapImageBuilder(bitmap).build()
            faceLandmarker?.detectAsync(mpImage, System.currentTimeMillis())
        }
        imageProxy.close()
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        startCamera()
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        isTracking = false
        cameraProvider?.unbindAll()
    }
    
    private fun runOnMain(runnable: Runnable) {
        ContextCompat.getMainExecutor(context).execute(runnable)
    }
}
```

### D. Integrate in MainActivity
Open `android/app/src/main/kotlin/.../MainActivity.kt`:

```kotlin
class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.app/face_mesh" // Logic channel
    private val EVENT_CHANNEL = "com.example.app/face_mesh_stream" // Stream channel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Face Mesh Logic
        val faceMeshDetector = FaceMeshDetector(context, this)
        
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(faceMeshDetector)
            
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "stopCamera" -> {
                    // Implement stop logic if needed explicitly
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
```

### E. Add Model Asset
1. Download `face_landmarker.task` from Google MediaPipe.
2. Place in `android/app/src/main/assets/face_landmarker.task`.

---

## 🍎 3. iOS Integration

### A. Info.plist
Add to `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to track head movements for cursor control.</string>
```

### B. Podfile
Add to `ios/Podfile`:
```ruby
pod 'MediaPipeTasksVision'
```
Run `pod install` in `ios/` folder.

### C. Swift Plugin
Create `ios/Runner/FaceMeshDetector.swift` (Similar logic to Kotlin, using AVFoundation).

*(Note: For brevity, ensure the Swift implementation strictly follows the FaceMessenger channel names: `com.example.app/face_mesh_stream`)*

---

## 🎯 4. Flutter Integration (Main Entry)

Modify `lib/main.dart` to initialize the system globally.

```dart
import 'package:flutter/material.dart';
import 'features/cursor_control/logic/face_messenger.dart';
import 'features/cursor_control/logic/cursor_controller.dart';
import 'features/cursor_control/logic/inactivity_detector.dart';
import 'features/cursor_control/ui/cursor_overlay.dart';

// 1. Global Accessors
late CursorController globalCursorController;
late InactivityDetector globalInactivityDetector;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize Logic
  final faceMessenger = FaceMessenger();
  final cursorController = CursorController(faceMessenger);
  final inactivityDetector = InactivityDetector();
  
  globalCursorController = cursorController;
  globalInactivityDetector = inactivityDetector;

  runApp(MyApp(
    cursorController: cursorController,
    inactivityDetector: inactivityDetector,
  ));
}

class MyApp extends StatelessWidget {
  final CursorController cursorController;
  final InactivityDetector inactivityDetector;

  const MyApp({
    super.key,
    required this.cursorController,
    required this.inactivityDetector,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Your App',
      // 3. Wrap Overlay in Builder
      builder: (context, child) {
        return Listener(
          // 4. Connect Global Touch Listener
          onPointerDown: (_) => inactivityDetector.onUserInteraction(),
          onPointerMove: (_) => inactivityDetector.onUserInteraction(),
          child: CursorOverlay(
            controller: cursorController,
            inactivityDetector: inactivityDetector,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const YourHomePage(),
    );
  }
}
```

## ✅ 5. Verification
1. Run `flutter pub get`.
2. Run on physical device (Camera required).
3. Wait 5 seconds -> Cursor should appear.
4. Move head -> Cursor moves.
