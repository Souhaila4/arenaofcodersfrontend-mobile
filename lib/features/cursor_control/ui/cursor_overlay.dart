import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../logic/cursor_controller.dart';
import '../logic/inactivity_detector.dart';

/// Overlay widget that displays the cursor and automatically shows/hides
/// based on user inactivity.
class CursorOverlay extends StatefulWidget {
  final CursorController controller;
  final InactivityDetector inactivityDetector;
  final Widget child;

  const CursorOverlay({
    super.key,
    required this.controller,
    required this.inactivityDetector,
    required this.child,
  });

  @override
  State<CursorOverlay> createState() => _CursorOverlayState();
}

class _CursorOverlayState extends State<CursorOverlay> {
  bool _showCursor = false;
  StreamSubscription<void>? _clickSubscription;
  bool _isSimulatingTap = false; // Prevent event loop
  Timer? _scrollTimer;
  double? _currentScrollDirection; // Track scroll direction to prevent spam

  @override
  void initState() {
    super.initState();
    widget.inactivityDetector.addListener(_onIdleStateChanged);
    widget.controller.addListener(_onCursorPositionChanged);
    // Note: Screen size is set in didChangeDependencies() below
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update screen size when dependencies change
    final size = MediaQuery.of(context).size;
    widget.controller.updateScreenSize(size);
  }

  @override
  void dispose() {
    widget.inactivityDetector.removeListener(_onIdleStateChanged);
    widget.controller.removeListener(_onCursorPositionChanged);
    _clickSubscription?.cancel();
    _scrollTimer?.cancel();
    super.dispose();
  }

  void _onIdleStateChanged() {
    // Don't hide cursor if we're simulating a tap
    if (_isSimulatingTap) return;
    
    // Only process inactivity logic if the feature is toggled ON in the profile
    if (!widget.controller.isRunningNotifier.value) return;

    final isIdle = widget.inactivityDetector.isIdle;
    
    if (isIdle && !_showCursor) {
      // User has been idle for 5 seconds -> Show cursor and start tracking
      widget.controller.start();
      setState(() => _showCursor = true);
      
      // Listen to click events
      _clickSubscription = widget.controller.clickStream.listen((_) {
        _simulateTapAtCursorPosition();
      });
    } else if (!isIdle && _showCursor) {
      // User touched the screen -> Hide cursor and stop tracking
      _clickSubscription?.cancel();
      _clickSubscription = null;
      widget.controller.stop();
      // Important to set it back to true so when they toggle it off and on, it remembers it's "enabled"
      widget.controller.isRunningNotifier.value = true;
      setState(() => _showCursor = false);
    }
  }

  void _simulateTapAtCursorPosition() async {
    final position = widget.controller.cursorPosition;
    
    debugPrint("🎯 SIMULATING TAP at position: $position");
    
    // Set flag to prevent hiding cursor during simulation
    _isSimulatingTap = true;
    
    // Create a unique pointer ID for this tap sequence
    final pointerId = DateTime.now().millisecondsSinceEpoch % 10000;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // 1. Add pointer (device detection)
    final pointerAddedEvent = PointerAddedEvent(
      pointer: pointerId,
      position: position,
      timeStamp: Duration(milliseconds: now),
    );
    GestureBinding.instance.handlePointerEvent(pointerAddedEvent);
    
    await Future.delayed(const Duration(milliseconds: 10));
    
    // 2. Pointer down event
    final pointerDownEvent = PointerDownEvent(
      pointer: pointerId,
      position: position,
      timeStamp: Duration(milliseconds: now + 10),
      pressure: 1.0,
      pressureMin: 0.0,
      pressureMax: 1.0,
    );
    
    GestureBinding.instance.handlePointerEvent(pointerDownEvent);
    debugPrint("✅ Dispatched PointerDown at $position");
    
    // 3. Wait a bit then dispatch pointer up
    await Future.delayed(const Duration(milliseconds: 100));
    
    final pointerUpEvent = PointerUpEvent(
      pointer: pointerId,
      position: position,
      timeStamp: Duration(milliseconds: now + 110),
    );
    
    GestureBinding.instance.handlePointerEvent(pointerUpEvent);
    debugPrint("✅ Dispatched PointerUp at $position");
    
    // 4. Remove pointer
    await Future.delayed(const Duration(milliseconds: 10));
    
    final pointerRemovedEvent = PointerRemovedEvent(
      pointer: pointerId,
      position: position,
      timeStamp: Duration(milliseconds: now + 120),
    );
    GestureBinding.instance.handlePointerEvent(pointerRemovedEvent);
    
    // Reset flag after a short delay
    await Future.delayed(const Duration(milliseconds: 200));
    _isSimulatingTap = false;
    
    debugPrint("✅ Tap sequence complete");
  }

  void _onCursorPositionChanged() {
    if (!_showCursor) return;
    
    final position = widget.controller.cursorPosition;
    final screenHeight = MediaQuery.of(context).size.height;
    
    const edgeZone = 100.0; // pixels from edge to trigger scroll
    const scrollSpeed = 10.0; // pixels per frame
    
    // Check if cursor is in top or bottom edge zone
    if (position.dy < edgeZone) {
      // Cursor near top - scroll up
      _startScrolling(-scrollSpeed);
    } else if (position.dy > screenHeight - edgeZone) {
      // Cursor near bottom - scroll down
      _startScrolling(scrollSpeed);
    } else {
      // Cursor in safe zone - stop scrolling
      _stopScrolling();
    }
  }

  void _startScrolling(double delta) {
    // Only restart timer if direction changed or not already scrolling
    if (_currentScrollDirection == delta && _scrollTimer != null && _scrollTimer!.isActive) {
      return; // Already scrolling in this direction
    }
    
    // Cancel existing timer
    _scrollTimer?.cancel();
    _currentScrollDirection = delta;
    
    // Start new scroll timer
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      _performScroll(delta);
    });
  }

  void _stopScrolling() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
    _currentScrollDirection = null;
  }

  void _performScroll(double delta) {
    // Instead of looking for a ScrollController, we simulate a Scroll Event (Mouse Wheel)
    // This works better because it finds the Scrollable underneath the cursor/center.
    
    final centerPos = Offset(
      MediaQuery.of(context).size.width / 2,
      MediaQuery.of(context).size.height / 2
    );
    
    // Create a pointer scroll event
    final scrollEvent = PointerScrollEvent(
      position: centerPos, // Send event to center of screen (usually safe for lists)
      scrollDelta: Offset(0, delta),
      kind: PointerDeviceKind.mouse,
    );
    
    // Dispatch the event
    GestureBinding.instance.handlePointerEvent(scrollEvent);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showCursor)
          AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) {
              final pos = widget.controller.cursorPosition;
              final isClicking = widget.controller.isClicking;
              
              return Positioned(
                left: pos.dx - 20,
                top: pos.dy - 20,
                child: IgnorePointer(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer ring for visibility over images
                      Container(
                        width: isClicking ? 35 : 40,
                        height: isClicking ? 35 : 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.8),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      // Inner gradient cursor
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        width: isClicking ? 25 : 30,
                        height: isClicking ? 25 : 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.blueAccent.withValues(alpha: 0.9),
                              Colors.purpleAccent.withValues(alpha: 0.7),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isClicking 
                                  ? Colors.greenAccent.withValues(alpha: 0.6)
                                  : Colors.blueAccent.withValues(alpha: 0.4),
                              blurRadius: isClicking ? 20 : 15,
                              spreadRadius: isClicking ? 5 : 3,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
