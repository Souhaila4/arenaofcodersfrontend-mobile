import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:arena/core/models/auth_models.dart';
import 'package:arena/core/services/api_service.dart';
import 'package:arena/core/theme/app_theme.dart';
import 'package:arena/features/jobs/models/job_posting.dart';

class _ChatLine {
  final bool fromRecruiter;
  final String text;

  _ChatLine({required this.fromRecruiter, required this.text});
}

/// Voice + text mock interview against the job context (Groq via backend).
class TestInterviewScreen extends StatefulWidget {
  final JobPosting job;

  const TestInterviewScreen({super.key, required this.job});

  @override
  State<TestInterviewScreen> createState() => _TestInterviewScreenState();
}

class _TestInterviewScreenState extends State<TestInterviewScreen> {
  final _api = ApiService();
  final _scroll = ScrollController();
  final _input = TextEditingController();

  final List<_ChatLine> _lines = [];
  bool _loading = true;
  bool _readAloud = true;
  String? _error;

  late final FlutterTts _tts;
  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _listening = false;
  bool _sttReady = false;

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _configureTts();
    _bootstrap();
    _initStt();
  }

  Future<void> _configureTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
  }

  Future<void> _initStt() async {
    _sttReady = await _stt.initialize(
      onStatus: (_) {},
      onError: (_) {},
    );
    if (mounted) setState(() {});
  }

  Future<void> _bootstrap() async {
    await _requestRecruiterLine();
  }

  List<Map<String, String>> _historyPayload() {
    return _lines
        .map((l) => {
              'role': l.fromRecruiter ? 'assistant' : 'user',
              'content': l.text,
            })
        .toList();
  }

  Future<void> _requestRecruiterLine() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reply = await _api.postInterviewTurn(
        jobTitle: widget.job.title,
        jobDescription: widget.job.description,
        companyName: widget.job.companyName,
        messages: _historyPayload(),
      );
      if (!mounted) return;
      setState(() {
        _lines.add(_ChatLine(fromRecruiter: true, text: reply));
        _loading = false;
      });
      _scrollToEnd();
      if (_readAloud) await _tts.speak(reply);
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _loading) return;

    _input.clear();
    setState(() {
      _lines.add(_ChatLine(fromRecruiter: false, text: text));
      _loading = true;
      _error = null;
    });
    _scrollToEnd();

    try {
      final reply = await _api.postInterviewTurn(
        jobTitle: widget.job.title,
        jobDescription: widget.job.description,
        companyName: widget.job.companyName,
        messages: _historyPayload(),
      );
      if (!mounted) return;
      setState(() {
        _lines.add(_ChatLine(fromRecruiter: true, text: reply));
        _loading = false;
      });
      _scrollToEnd();
      if (_readAloud) await _tts.speak(reply);
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _toggleMic() async {
    if (!_sttReady || _loading) return;
    if (_listening) {
      await _stt.stop();
      setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    await _stt.listen(
      onResult: (res) {
        if (!mounted) return;
        if (res.finalResult) {
          final combined = res.recognizedWords.trim();
          if (combined.isNotEmpty) {
            setState(() {
              _input.text = combined;
              _input.selection = TextSelection.fromPosition(
                TextPosition(offset: _input.text.length),
              );
            });
          }
        }
      },
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 3),
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
      ),
    );
    if (mounted) setState(() => _listening = false);
  }

  @override
  void dispose() {
    _tts.stop();
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test interview'),
        actions: [
          IconButton(
            tooltip: _readAloud ? 'Mute recruiter voice' : 'Read replies aloud',
            onPressed: () => setState(() => _readAloud = !_readAloud),
            icon: Icon(_readAloud ? Icons.volume_up : Icons.volume_off),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.job.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Material(
                color: Colors.red.withAlpha(35),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: _lines.length + (_loading ? 1 : 0),
              itemBuilder: (context, i) {
                if (_loading && i == _lines.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  );
                }
                final line = _lines[i];
                final bubbleColor = line.fromRecruiter
                    ? (isDark
                        ? const Color(0xFF1E293B)
                        : Colors.grey.shade200)
                    : AppColors.primary.withAlpha(isDark ? 45 : 35);
                final align = line.fromRecruiter
                    ? Alignment.centerLeft
                    : Alignment.centerRight;
                return Align(
                  alignment: align,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.85,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: line.fromRecruiter
                            ? Colors.white.withAlpha(12)
                            : AppColors.primary.withAlpha(60),
                      ),
                    ),
                    child: Text(
                      line.text,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: isDark ? Colors.grey.shade100 : Colors.grey.shade900,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton.filledTonal(
                    onPressed: _loading ? null : _toggleMic,
                    icon: Icon(_listening ? Icons.mic : Icons.mic_none),
                    tooltip: _sttReady
                        ? (_listening ? 'Stop dictation' : 'Speak your answer')
                        : 'Voice input unavailable',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Your answer…',
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _loading ? null : _send,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                    ),
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
