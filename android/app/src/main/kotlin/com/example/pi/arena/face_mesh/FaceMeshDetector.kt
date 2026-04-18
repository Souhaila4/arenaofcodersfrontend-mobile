package com.example.pi.arena.face_mesh

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
import kotlin.math.sqrt

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
            .setModelAssetPath("face_landmarker.task")
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
                    val nose = landmarks[1]
                    
                    // Invert both axes for front camera mirror effect
                    val yaw = (0.5 - nose.x()) * 2
                    val pitch = (0.5 - nose.y()) * 2
                    
                    // FIX 2: Real Eye Aspect Ratio (EAR) for blink detection
                    // Left eye landmarks
                    val leftEAR = computeEAR(
                        landmarks[159].x(), landmarks[159].y(),  // top
                        landmarks[145].x(), landmarks[145].y(),  // bottom
                        landmarks[33].x(),  landmarks[33].y(),   // left corner
                        landmarks[133].x(), landmarks[133].y()   // right corner
                    )
                    
                    // Right eye landmarks
                    val rightEAR = computeEAR(
                        landmarks[386].x(), landmarks[386].y(),  // top
                        landmarks[374].x(), landmarks[374].y(),  // bottom
                        landmarks[362].x(), landmarks[362].y(),  // left corner
                        landmarks[263].x(), landmarks[263].y()   // right corner
                    )
                    
                    // Debug: log EAR values to check blink detection
                    Log.d("FaceMesh", "EAR L=$leftEAR R=$rightEAR")
                    
                    val data = mapOf(
                        "yaw" to yaw,
                        "pitch" to pitch,
                        "leftEyeOpen" to leftEAR,
                        "rightEyeOpen" to rightEAR
                    )
                    
                    runOnMain { eventSink?.success(data) }
                }
            }
            .setErrorListener { e -> Log.e("FaceMesh", "Error: ${e.message}") }
            .build()

        faceLandmarker = FaceLandmarker.createFromOptions(context, options)
    }
    
    // Compute Eye Aspect Ratio (EAR)
    // EAR ~0.25-0.35 when open, ~0.05-0.15 when closed
    private fun computeEAR(
        topX: Float, topY: Float,
        bottomX: Float, bottomY: Float,
        leftX: Float, leftY: Float,
        rightX: Float, rightY: Float
    ): Double {
        // Vertical distance (top to bottom eyelid)
        val vertical = sqrt(
            ((topX - bottomX) * (topX - bottomX) + (topY - bottomY) * (topY - bottomY)).toDouble()
        )
        // Horizontal distance (eye corner to corner)
        val horizontal = sqrt(
            ((leftX - rightX) * (leftX - rightX) + (leftY - rightY) * (leftY - rightY)).toDouble()
        )
        
        if (horizontal < 0.001) return 1.0  // Avoid division by zero
        
        return vertical / horizontal  // Returns ~0.3 open, ~0.1 closed
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
