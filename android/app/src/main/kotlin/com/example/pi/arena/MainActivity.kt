package com.example.pi.arena

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.example.pi.arena.face_mesh.FaceMeshDetector

class MainActivity : FlutterActivity() {
    // Must match Dart FaceMessenger channel names exactly
    private val METHOD_CHANNEL = "face_mesh/control"
    private val EVENT_CHANNEL = "face_mesh/data"
    
    private var faceMeshDetector: FaceMeshDetector? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Face Mesh Logic
        faceMeshDetector = FaceMeshDetector(context, this)
        
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(faceMeshDetector)
            
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startCamera" -> {
                    faceMeshDetector?.startCamera()
                    result.success(null)
                }
                "stopCamera" -> {
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}

