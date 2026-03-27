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
    await flutterTts.setSpeechRate(0.5); // 0.5 is normally 1x speed on Android
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
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
      );
      
      // We must explicitly listen for status changes to restart it when it stops
      speechToText.statusListener = (status) async {
        if (status == 'done' || status == 'notListening') {
          // Restart listening if the setting is still enabled
          if (provider.talkToAppEnabled && _isSttInitialized) {
            await Future.delayed(const Duration(milliseconds: 500));
            if (provider.talkToAppEnabled) {
              startListeningForCommands(context, provider);
            }
          }
        }
      };
    }
  }

  Future<void> stopListeningForCommands() async {
    speechToText.statusListener = null; // Remove the listener so it doesn't auto-restart
    if (speechToText.isListening) {
      await speechToText.stop();
    }
  }

  // --- Command Execution Logic --- 
  void _handleVoiceCommand(BuildContext context, String command) {
    // Make text cleaning
    final c = command.toLowerCase().trim();

    // 1. Home / Accueil
    if (RegExp(r'\b(home|homme|ome|rome|accueil|acceuil|acceuille|debut|début|aller a home)\b').hasMatch(c)) {
      _navigateToTab(context, 0);
    } 
    // 2. Hackathons / Competitions
    else if (RegExp(r'\b(hackathon|hackathons|hacaton|akat|competition|compétition|tournoi|match)\b').hasMatch(c)) {
      _navigateToTab(context, 1);
    } 
    // 3. Leaderboard / Ranking / Classement
    else if (RegExp(r'\b(leaderboard|ranking|rank|classement|classment|top|meilleur)\b').hasMatch(c)) {
      _navigateToTab(context, 3);
    } 
    // 4. Profile / Profil
    else if (RegExp(r'\b(profile|profil|pro|mon compte|compte)\b').hasMatch(c)) {
      _navigateToTab(context, 4);
    } 
    // 5. Back / Retour
    else if (RegExp(r'\b(back|retour|retourner|revenir|arriere|arrière)\b').hasMatch(c)) {
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
