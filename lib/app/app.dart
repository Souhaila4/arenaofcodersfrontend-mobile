import 'package:flutter/material.dart';
import 'package:arena/core/theme/app_theme.dart';
import 'package:arena/app/router.dart';
import 'package:arena/app/shell.dart';
import 'package:arena/features/cursor_control/logic/cursor_controller.dart';
import 'package:arena/features/cursor_control/logic/inactivity_detector.dart';
import 'package:arena/features/cursor_control/ui/cursor_overlay.dart';
import 'package:arena/accessibility/accessibility_provider.dart';
import 'package:arena/accessibility/accessibility_theme.dart';
import 'package:arena/accessibility/accessibility_voice.dart';
import 'package:provider/provider.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart' as stream;

bool _accessibilityVoiceInitialized = false;

/// Root application widget.
class ArenaApp extends StatelessWidget {
  final CursorController cursorController;
  final InactivityDetector inactivityDetector;
  final GlobalKey<MainShellState> mainShellKey;

  const ArenaApp({
    super.key,
    required this.cursorController,
    required this.inactivityDetector,
    required this.mainShellKey,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AccessibilityProvider(),
      child: Consumer<AccessibilityProvider>(
        builder: (context, accessibility, _) {
          if (!_accessibilityVoiceInitialized) {
            _accessibilityVoiceInitialized = true;
            WidgetsBinding.instance.addPostFrameCallback(
                (_) => AccessibilityVoice().init());
          }
          final themeData = accessibility.themeData;
          final fontScale = accessibility.fontScale;
          final colorFilter = accessibility.colorFilter;

          return MaterialApp(
            title: 'Arena of Coders',
            debugShowCheckedModeBanner: false,
            theme: themeData,
            darkTheme: themeData,
            themeMode: ThemeMode.dark,
            builder: (context, child) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              Widget result = stream.StreamChatTheme(
                data: isDark
                    ? stream.StreamChatThemeData.dark()
                    : stream.StreamChatThemeData.light(),
                child: Listener(
                  onPointerDown: (_) {
                    if (!cursorController.isClicking) {
                      inactivityDetector.onUserInteraction();
                    }
                  },
                  onPointerMove: (_) {
                    if (!cursorController.isClicking) {
                      inactivityDetector.onUserInteraction();
                    }
                  },
                  child: CursorOverlay(
                    controller: cursorController,
                    inactivityDetector: inactivityDetector,
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              );
              result = MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(fontScale),
                ),
                child: result,
              );
              if (colorFilter != null) {
                result = ColorFiltered(
                  colorFilter: colorFilter,
                  child: result,
                );
              }
              return result;
            },
            initialRoute: AppRouter.splash,
            routes: {
              ...AppRouter.routes,
              AppRouter.home: (_) => MainShell(key: mainShellKey),
            },
          );
        },
      ),
    );
  }
}
