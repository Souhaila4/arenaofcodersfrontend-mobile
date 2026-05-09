import 'package:flutter/material.dart';
import '../logic/cursor_controller.dart';
import 'package:permission_handler/permission_handler.dart';

class FaceCalibrationScreen extends StatefulWidget {
  final CursorController controller;

  const FaceCalibrationScreen({super.key, required this.controller});

  @override
  State<FaceCalibrationScreen> createState() => _FaceCalibrationScreenState();
}

class _FaceCalibrationScreenState extends State<FaceCalibrationScreen> {
  @override
  void initState() {
    super.initState();
    _checkPermissionAndStart();
    
    // Listen for clicks
    widget.controller.clickStream.listen((_) {
      if (mounted) {
        _simulateTap(widget.controller.cursorPosition);
      }
    });
  }

  void _simulateTap(Offset position) {
    debugPrint("Simulating tap at $position");

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenCenter = Offset(screenWidth / 2, screenHeight / 2);

    // Hit Testing for New UI Layout
    
    // Top Test Button (approx relative to screen size)
    // Positioned at top: 100, left: 40
    if (position.dx >= 40 && position.dx <= 160 && position.dy >= 100 && position.dy <= 160) {
       debugPrint("Hit Top Button!");
       _showFeedback("Top Target Hit!", Colors.redAccent);
    }
    
    // Bottom Test Button
    // Positioned at bottom: 100, right: 40
    if (position.dx >= screenWidth - 160 && position.dx <= screenWidth - 40 &&
        position.dy >= screenHeight - 160 && position.dy <= screenHeight - 100) {
       debugPrint("Hit Bottom Button!");
       _showFeedback("Bottom Target Hit!", Colors.tealAccent);
    }
    
    // Center Calibrate Button (Circle radius ~60)
    if ((position - screenCenter).distance < 80) {
        debugPrint("Hit Calibrate!");
        widget.controller.calibrate();
        _showFeedback("Center Calibrated!", Colors.greenAccent);
    }
  }

  void _showFeedback(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: color),
            const SizedBox(width: 10),
            Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF303050),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  Future<void> _checkPermissionAndStart() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      widget.controller.start();
    } else {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Camera permission denied. Cannot control cursor.")),
        );
      }
    }
  }

  @override
  void dispose() {
    widget.controller.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Calibration & Test", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Update screen size on build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.controller.updateScreenSize(Size(constraints.maxWidth, constraints.maxHeight));
            });

            return Stack(
              children: [
                // ambient background elements
                Positioned(
                  top: -50,
                  right: -50,
                  child: _buildAmbientCircle(200, Colors.purple.withOpacity(0.1)),
                ),
                Positioned(
                  bottom: -50,
                  left: -50,
                  child: _buildAmbientCircle(200, Colors.blue.withOpacity(0.1)),
                ),

                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Status Indicator
                      _buildStatusIndicator(),
                      const SizedBox(height: 30),
                      
                      // Calibration Target
                      _buildCalibrationTarget(),
                      
                      const SizedBox(height: 30),
                      
                      // Settings Controls
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 40),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          children: [
                            const Text("Cursor Settings", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            // Sensitivity Slider
                            Row(
                              children: [
                                const Icon(Icons.speed, color: Colors.white70, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: AnimatedBuilder(
                                    animation: widget.controller,
                                    builder: (context, _) => Slider(
                                      value: widget.controller.sensitivity,
                                      min: 200.0,
                                      max: 3000.0,
                                      activeColor: Colors.blueAccent,
                                      inactiveColor: Colors.white24,
                                      onChanged: (val) => widget.controller.setSensitivity(val),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              "Sensitivity: ${widget.controller.sensitivity.toInt()}",
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            const SizedBox(height: 10),
                            // Inversion Toggles
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildToggle("Invert X", widget.controller.invertX, (v) => widget.controller.setInvertX(v)),
                                _buildToggle("Invert Y", widget.controller.invertY, (v) => widget.controller.setInvertY(v)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Swap XY Toggle
                            _buildToggle("Swap X/Y Axes (Fix Portrait)", widget.controller.swapXY, (v) => widget.controller.setSwapXY(v)),
                            
                            const SizedBox(height: 15),
                            // Debug Info
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                              child: AnimatedBuilder(
                                animation: widget.controller,
                                builder: (context, _) => Text(
                                  "Debug: YAW=${widget.controller.rawYaw.toStringAsFixed(2)}  PITCH=${widget.controller.rawPitch.toStringAsFixed(2)}",
                                  style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontFamily: 'monospace'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),


                      // Instructions
                      const Text(
                        "1. Turn on 'Swap X/Y' if Face Right -> Cursor Down\n2. Use 'Invert' to fix direction",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // Test Targets
                Positioned(
                  top: 80,
                  left: 20,
                  child: _buildTestButton("Tap Top", Colors.redAccent),
                ),
                Positioned(
                  bottom: 80,
                  right: 20,
                  child: _buildTestButton("Tap Bottom", Colors.tealAccent),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildToggle(String label, bool value, Function(bool) onChanged) {
    return Row(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Switch(
          value: value, 
          onChanged: onChanged,
          activeColor: Colors.greenAccent,
          activeTrackColor: Colors.green.withOpacity(0.4),
          inactiveThumbColor: Colors.white54,
          inactiveTrackColor: Colors.white10,
        ),
      ],
    );
  }

  Widget _buildAmbientCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color, blurRadius: 60, spreadRadius: 10),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.controller.isFaceDetectedNotifier, 
      builder: (context, isFaceDetected, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: isFaceDetected ? Colors.greenAccent : Colors.redAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: isFaceDetected ? Colors.greenAccent.withOpacity(0.5) : Colors.transparent, blurRadius: 6)
                  ]
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isFaceDetected ? "Face Tracking Active" : "Searching for Face...",
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCalibrationTarget() {
    return GestureDetector(
      onTap: () {
        widget.controller.calibrate();
        _showFeedback("Center Calibrated!", Colors.greenAccent);
      },
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
          // gradient: LinearGradient(colors: [Colors.blue.withOpacity(0.2), Colors.purple.withOpacity(0.2)]),
           color: Colors.white.withOpacity(0.05),
        ),
        child: Center(
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.white.withOpacity(0.5), blurRadius: 10, spreadRadius: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTestButton(String label, Color color) {
    return Container(
      width: 120,
      height: 60,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(color: color.withOpacity(0.9), fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }
}
