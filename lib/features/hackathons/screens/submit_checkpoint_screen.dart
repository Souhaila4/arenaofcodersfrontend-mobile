import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:arena/core/models/auth_models.dart';
import 'package:arena/core/services/api_service.dart';
import 'package:arena/core/services/storage_service.dart';
import 'package:arena/core/theme/app_theme.dart';

class SubmitCheckpointScreen extends StatefulWidget {
  final String competitionId;
  final String checkpointId;
  final String checkpointTitle;
  final DateTime dueDate;
  final VoidCallback? onSubmitted;

  /// When the submission window opens. If null, computed as [dueDate] minus 15 minutes.
  final DateTime? opensAt;

  const SubmitCheckpointScreen({
    super.key,
    required this.competitionId,
    required this.checkpointId,
    required this.checkpointTitle,
    required this.dueDate,
    this.onSubmitted,
    this.opensAt,
  });

  /// Submission window length in minutes (must match backend).
  static const int submissionWindowMinutes = 15;

  DateTime get windowOpensAt =>
      opensAt ?? dueDate.subtract(const Duration(minutes: submissionWindowMinutes));

  @override
  State<SubmitCheckpointScreen> createState() => _SubmitCheckpointScreenState();
}

class _SubmitCheckpointScreenState extends State<SubmitCheckpointScreen> {
  final _api = ApiService();
  final _storage = StorageService();
  final _proofUrlController = TextEditingController();
  final _notesController = TextEditingController();
  PlatformFile? _workspaceImage;
  PlatformFile? _audioFile;
  
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  bool _loading = false;
  String? _error;
  String? _successMessage;

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 70,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _workspaceImage = PlatformFile(
          name: image.name,
          size: bytes.length,
          bytes: bytes,
        );
        _successMessage = null;
        _error = null;
      });
    }
  }

  Future<void> _startStopRecording() async {
    try {
      if (_isRecording) {
        final path = await _audioRecorder.stop();
        if (path != null) {
          final file = File(path);
          final bytes = await file.readAsBytes();
          setState(() {
            _audioFile = PlatformFile(
              name: 'enregistrement_vocal.m4a',
              size: bytes.length,
              bytes: bytes,
              path: path,
            );
            _isRecording = false;
          });
        }
      } else {
        if (await _audioRecorder.hasPermission()) {
          final dir = await getTemporaryDirectory();
          final path = '${dir.path}/enregistrement_${DateTime.now().millisecondsSinceEpoch}.m4a';
          await _audioRecorder.start(
            const RecordConfig(encoder: AudioEncoder.aacLc),
            path: path,
          );
          setState(() {
            _isRecording = true;
            _audioFile = null;
            _successMessage = null;
            _error = null;
          });
        } else {
          setState(() => _error = 'Permission microphone refusée.');
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Erreur audio: $e';
        _isRecording = false;
      });
    }
  }

  @override
  void dispose() {
    _proofUrlController.dispose();
    _notesController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final proofUrl = _proofUrlController.text.trim();
    if (proofUrl.isEmpty) {
      setState(() => _error = 'Please enter a proof URL (repo, demo, or document link).');
      return;
    }
    if (_workspaceImage == null) {
      setState(() => _error = 'Veuillez uploader une photo de votre environnement de travail (Anti-Cheat).');
      return;
    }
    if (_audioFile == null) {
      setState(() => _error = 'Veuillez uploader un fichier audio d\'explication (Anti-Cheat Vocal).');
      return;
    }

    final now = DateTime.now();
    if (now.isBefore(widget.windowOpensAt)) {
      setState(() => _error = 'Submission window has not opened yet. Opens at ${_formatDateTime(widget.windowOpensAt)}.');
      return;
    }
    if (!now.isBefore(widget.dueDate)) {
      setState(() => _error = 'Submission window has closed.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      // 1. Fetch Face Image (Hackathon-specific face image, fallback to profile avatar)
      final participation = await _api.getParticipationDetails(widget.competitionId);
      final hackathonFaceUrl = participation?['hackathonFaceUrl'];

      List<int>? avatarBytes;
      String? avatarFilename;

      String? urlToFetch = (hackathonFaceUrl != null && hackathonFaceUrl.toString().isNotEmpty) 
          ? hackathonFaceUrl.toString() 
          : null;

      if (urlToFetch == null) {
        final user = await _storage.getUser();
        urlToFetch = user?.avatarUrl;
      }

      if (urlToFetch != null && urlToFetch.isNotEmpty) {
        String fullUrl = urlToFetch;
        if (!fullUrl.startsWith('http')) {
          fullUrl = '${ApiService.baseUrl}${fullUrl.startsWith('/') ? '' : '/'}$fullUrl';
        }
        final avatarUri = Uri.parse(fullUrl);
        final avatarRes = await http.get(avatarUri);
        if (avatarRes.statusCode == 200) {
          avatarBytes = avatarRes.bodyBytes;
          avatarFilename = 'face_anti_cheat.jpg';
        }
      }

      if (avatarBytes == null) {
        setState(() {
          _error = 'Impossible de récupérer votre image personnelle pour la validation Anti-Triche.';
          _loading = false;
        });
        return;
      }

      // 2. Validate with HuggingFace AI Image Model
      final aiResult = await _api.validateWorkspaceImage(
        _workspaceImage!.bytes!,
        _workspaceImage!.name,
        avatarBytes: avatarBytes,
        avatarFilename: avatarFilename,
      );

      final isImgAccepted = aiResult['accepte'] ?? false;
      final imgMessage = aiResult['message'] ?? 'Validation Image failed';

      // 3. Validate with HuggingFace AI Vocal Model
      final vocAiResult = await _api.validateVocalAudio(
        _audioFile!.bytes!,
        _audioFile!.name,
      );

      final isVocAccepted = vocAiResult['accepte'] ?? false;
      final vocMessage = vocAiResult['message'] ?? 'Validation Vocale failed';

      if (!isImgAccepted || !isVocAccepted) {
        if (mounted) {
          setState(() {
            _error = [
              if (!isImgAccepted) '🖼️ Image: $imgMessage',
              if (!isVocAccepted) '🎙️ Vocal: $vocMessage',
            ].join('\n\n');
            _loading = false;
          });
        }
        return;
      }
      
      setState(() {
         _successMessage = '$imgMessage\n\n$vocMessage';
      });

      // 4. Backend Submission
      await _api.submitCheckpoint(
        competitionId: widget.competitionId,
        checkpointId: widget.checkpointId,
        proofUrl: proofUrl,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      if (!mounted) return;
      widget.onSubmitted?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checkpoint submitted successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _error = e.displayMessage;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Something went wrong. Please try again.';
          _loading = false;
        });
      }
    }
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _formatDateTime(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${months[d.month - 1]} ${d.day} at $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0B1121), Color(0xFF0F141C), Color(0xFF0B0E14)],
                )
              : null,
          color: isDark ? null : AppColors.backgroundLight,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.arrow_back,
                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Submit checkpoint',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF161B22) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primary.withAlpha(50),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.checkpointTitle,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : AppColors.textLightPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.schedule, size: 16, color: Colors.grey.shade500),
                                const SizedBox(width: 8),
                                Text(
                                  'Due ${_formatDate(widget.dueDate)}',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                            Text(
                              'Window: ${_formatDateTime(widget.windowOpensAt)} – ${_formatDateTime(widget.dueDate)}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Proof URL (required)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _proofUrlController,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          hintText: 'https://github.com/... or demo link',
                          hintStyle: TextStyle(color: Colors.grey.shade600),
                          prefixIcon: const Icon(Icons.link, color: Colors.grey),
                          filled: true,
                          fillColor: isDark ? Colors.black26 : Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Notes (optional)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notesController,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black),
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Any additional notes for reviewers',
                          hintStyle: TextStyle(color: Colors.grey.shade600),
                          filled: true,
                          fillColor: isDark ? Colors.black26 : Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Workspace Photo (Anti-Triche)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickImage,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black26 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.camera_alt, color: isDark ? Colors.white : Colors.black, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _workspaceImage != null ? 'Photo prise : ${_workspaceImage!.name}' : 'Prendre une photo de l\'environnement...',
                                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Explication Audio en Direct (Anti-Triche Vocal)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _startStopRecording,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: _isRecording ? Colors.red.withAlpha(25) : (isDark ? Colors.black26 : Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(12),
                            border: _isRecording ? Border.all(color: Colors.red.withAlpha(80)) : null,
                          ),
                          child: Row(
                            children: [
                              Icon(_isRecording ? Icons.stop_circle : Icons.mic, color: _isRecording ? Colors.red : (isDark ? Colors.white : Colors.black), size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _isRecording 
                                      ? 'Enregistrement en cours... Cliquez pour arrêter' 
                                      : (_audioFile != null ? 'Vocal enregistré ! (${(_audioFile!.size / 1024).toStringAsFixed(1)} KB)' : 'Appuyez pour enregistrer un vocal en direct...'),
                                  style: TextStyle(
                                    color: _isRecording ? Colors.red : (isDark ? Colors.white : Colors.black),
                                    fontWeight: _isRecording ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_workspaceImage != null && _workspaceImage!.bytes != null) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            _workspaceImage!.bytes!,
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(color: Colors.red, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_successMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.withAlpha(60)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _successMessage!,
                                  style: const TextStyle(color: Colors.green, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Submit checkpoint',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
