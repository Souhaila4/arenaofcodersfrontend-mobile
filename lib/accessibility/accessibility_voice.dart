import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'accessibility_provider.dart';
import '../main.dart'; // To access mainShellKey

class AccessibilityVoice {
  static final AccessibilityVoice _instance = AccessibilityVoice._internal();
  factory AccessibilityVoice() => _instance;
  AccessibilityVoice._internal();

  final FlutterTts flutterTts = FlutterTts();
  final stt.SpeechToText speechToText = stt.SpeechToText();

  bool _isSttInitialized = false;

  Completer<void>? _speechCompleter;

  Future<void> init() async {
    // Configure TTS
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(1.0);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);

    // Provide a completion handler for TTS
    flutterTts.setCompletionHandler(() {
      if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
        _speechCompleter!.complete();
      }
    });

    flutterTts.setErrorHandler((msg) {
      if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
        _speechCompleter!.completeError(msg);
      }
    });

    flutterTts.setCancelHandler(() {
      if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
        _speechCompleter!.complete();
      }
    });

    // Initialize STT
    _isSttInitialized = await speechToText.initialize(
      onError: (val) => log('STT Error: $val'),
      onStatus: (val) => log('STT Status: $val'),
    );
  }

  /// Speaks the given text if voice guide is enabled globally.
  Future<void> speak(String text, AccessibilityProvider provider) async {
    if (!provider.voiceGuideEnabled) return;
    await flutterTts.speak(text);
  }

  /// Forces speech regardless of settings.
  Future<void> speakForced(String text) async {
    _speechCompleter = Completer<void>();
    await flutterTts.speak(text);
    await _speechCompleter?.future;
  }

  /// Stops any ongoing TTS speech.
  Future<void> stopSpeaking() async {
    await flutterTts.stop();
  }

  /// Starts listening for basic voice commands.
  Future<void> startListeningForCommands(
    BuildContext context, 
    AccessibilityProvider provider,
  ) async {
    if (!provider.talkToAppEnabled || !_isSttInitialized) return;

    if (!speechToText.isListening) {
      await speechToText.listen(
        onResult: (result) {
          final words = result.recognizedWords.toLowerCase();
          log('Recognized: $words');

          if (result.finalResult) {
            _handleVoiceCommand(context, words);
          }
        },
        listenFor: const Duration(seconds: 5),
        pauseFor: const Duration(seconds: 3),
      );
    }
  }

  Future<void> stopListeningForCommands() async {
    if (speechToText.isListening) {
      await speechToText.stop();
    }
  }

  // --- Command Execution Logic --- 
  void _handleVoiceCommand(BuildContext context, String command) {
    if (command.contains('go to leaderboard') || command.contains('go to ranking')) {
      _navigateToTab(context, 3);
    } else if (command.contains('open hackathons') || command.contains('open competitions')) {
      _navigateToTab(context, 1);
    } else if (command.contains('go to profile')) {
      _navigateToTab(context, 4);
    } else if (command.contains('go home')) {
      _navigateToTab(context, 0);
    } else if (command.contains('go back') || command.contains('back')) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  void _navigateToTab(BuildContext context, int index) {
      // Very basic hook: Pop anything on top
      Navigator.of(context).popUntil((route) => route.isFirst || route.settings.name == '/home');
      
      // Access the MainShellState to switch tab
      mainShellKey.currentState?.switchTab(index);
  }

  // --- Automated Guided Tour ---
  bool _isTourRunning = false;

  /// Automates a voice tour across the app.
  Future<void> orchestrateTour(AccessibilityProvider provider) async {
    if (_isTourRunning) return; 
    _isTourRunning = true;
    provider.setTourRunning(true);

    try {
      final safeContext = mainShellKey.currentContext;
      if (safeContext != null) {
        Navigator.of(safeContext).popUntil((route) => route.isFirst || route.settings.name == '/home');
      }
      
      // Step 1: Dashboard (Index 0)
      mainShellKey.currentState?.switchTab(0);
      await speakForced("Welcome to Arena of Coders. This is your Dashboard. Here you can see your upcoming events, recent activity, and quick stats. We will now move to Hackathons.");
      if (!_isTourRunning) return;
      await Future.delayed(const Duration(milliseconds: 500));

      // Step 2: Hackathons (Index 1)
      mainShellKey.currentState?.switchTab(1);
      await speakForced("This is the Hackathons page. Here you can browse ongoing, upcoming, and past coding competitions to join teams and build amazing projects. Next up, the Ranking.");
      if (!_isTourRunning) return;
      await Future.delayed(const Duration(milliseconds: 500));

      // Step 3: Ranking/Leaderboard (Index 3)
      mainShellKey.currentState?.switchTab(3);
      await speakForced("Welcome to the Global Ranking. Here you can see how you rank against other elite coders in the arena. Finally, let's head to your Profile.");
      if (!_isTourRunning) return;
      await Future.delayed(const Duration(milliseconds: 500));

      // Step 4: Profile (Index 4)
      mainShellKey.currentState?.switchTab(4);
      await speakForced("Last stop, your Profile. You can customize your experience here. The tour is now complete. Feel free to explore!");

    } catch (e) {
      log("Tour interrupted or error: $e");
    } finally {
      _isTourRunning = false;
      provider.setTourRunning(false);
    }
  }

  /// Cancels the ongoing guided tour.
  Future<void> cancelTour(AccessibilityProvider provider) async {
    _isTourRunning = false;
    provider.setTourRunning(false);
    await flutterTts.stop();
    if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
      _speechCompleter!.complete();
    }
  }
}
