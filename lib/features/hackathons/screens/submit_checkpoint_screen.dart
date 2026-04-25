import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:arena/core/models/auth_models.dart';
import 'package:arena/core/models/competition_model.dart';
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

  /// Optional existing submission to view or edit
  final CheckpointSubmissionWithCheckpoint? initialSubmission;
  final bool isLeader;

  const SubmitCheckpointScreen({
    super.key,
    required this.competitionId,
    required this.checkpointId,
    required this.checkpointTitle,
    required this.dueDate,
    this.initialSubmission,
    required this.isLeader,
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
  bool _isAiValidated = false;
  String _loadingStep = '';
  String? _imgSuccessMessage;
  String? _vocSuccessMessage;
  String? _error;
  String? _successMessage; // Keep for backward compat or general msgs

  @override
  void initState() {
    super.initState();
    if (widget.initialSubmission != null) {
      _proofUrlController.text = widget.initialSubmission!.proofUrl ?? '';
      _notesController.text = widget.initialSubmission!.notes ?? '';
    }
  }

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
        // Sécurité : Réinitialiser la validation si on change l'image
        _isAiValidated = false;
        _imgSuccessMessage = null;
        _vocSuccessMessage = null;
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
            // Sécurité : Réinitialiser la validation si on change le vocal
            _isAiValidated = false;
            _imgSuccessMessage = null;
            _vocSuccessMessage = null;
            _error = null;
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
      _loadingStep = 'Préparation...';
      _error = null;
      _successMessage = null;
    });

    try {
      // 1. Fetch Face Image (Hackathon-specific face image, fallback to profile avatar)
      final participation = await _api.getParticipationDetails(widget.competitionId);
      final hackathonFaceUrl = participation?['hackathonFaceUrl'];

      List<int>? avatarBytes;
      String? avatarFilename;

      // 0. Priorité à la photo locale prise lors de la création d'équipe
      final storageKey = 'face_image_${widget.competitionId}';
      final localImagePath = await _storage.getData(storageKey);
      
      if (localImagePath != null && localImagePath.isNotEmpty) {
        final localFile = File(localImagePath);
        if (localFile.existsSync()) {
          avatarBytes = await localFile.readAsBytes();
          avatarFilename = 'local_face.jpg';
        }
      }

      // 1b. Si pas de photo locale, on utilise celle du backend
      if (avatarBytes == null) {
        String? urlToFetch = (hackathonFaceUrl != null && hackathonFaceUrl.toString().isNotEmpty) 
            ? hackathonFaceUrl.toString() 
            : null;

        if (urlToFetch == null || urlToFetch.contains('default.png')) {
          final user = await _storage.getUser();
          urlToFetch = user?.avatarUrl;
        }

        if (urlToFetch != null && urlToFetch.isNotEmpty && !urlToFetch.contains('default.png')) {
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
      }

      // 1c. FALLBACK ULTIME: Ouvrir la caméra frontale pour prendre la photo maintenant
      if (avatarBytes == null) {
        if (!mounted) return;
        setState(() { _loading = false; });
        
        // Informer l'utilisateur
        final shouldTakePhoto = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A2332),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.face, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(child: Text('Photo de visage requise', style: TextStyle(color: Colors.white, fontSize: 16))),
              ],
            ),
            content: Text(
              'Prenez une photo de votre visage pour vérifier le checkpoint.\n\nCette photo sera utilisée comme référence Anti-Triche.',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('📸 Prendre la photo', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );

        if (shouldTakePhoto != true || !mounted) return;

        final picker = ImagePicker();
        final faceImage = await picker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.front,
          imageQuality: 70,
        );

        if (faceImage == null || !mounted) return;

        // Sauvegarder pour les prochains checkpoints
        final appDir = await getApplicationDocumentsDirectory();
        final permanentPath = '${appDir.path}/face_image_${widget.competitionId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await File(faceImage.path).copy(permanentPath);
        await _storage.saveData(storageKey, permanentPath);

        avatarBytes = await File(permanentPath).readAsBytes();
        avatarFilename = 'local_face.jpg';

        setState(() { _loading = true; });
      }

      // 2. Validate with HuggingFace AI Image Model
      if (mounted) setState(() => _loadingStep = '📷 Analyse IA de l\'image en cours...\n(peut prendre 30-45s)');
      bool isImgAccepted = false;
      String imgMessage = '';
      try {
        final aiResult = await _api.validateWorkspaceImage(
          _workspaceImage!.bytes!,
          _workspaceImage!.name,
          avatarBytes: avatarBytes,
          avatarFilename: avatarFilename,
        );

        // Analyse intelligente : gère le JSON ou le Texte brut
        if (aiResult is Map) {
          isImgAccepted = aiResult['accepte'] == true || 
                          aiResult['status'] == 'success' ||
                          (aiResult['message']?.toString().contains('Accepté') ?? false) ||
                          (aiResult['message']?.toString().contains('succès') ?? false);
          imgMessage = aiResult['message'] ?? 'Analyse Image effectuée';
        } else {
          // Si l'IA renvoie juste une String (votre cas actuel)
          final resStr = aiResult.toString();
          isImgAccepted = resStr.contains('Accepté') || resStr.contains('success') || resStr.contains('succès');
          imgMessage = resStr;
        }
      } on ApiError catch (e) {
        // Si l'erreur contient "Accepté" ou "succès", on considère que c'est un succès mal interprété
        if (e.displayMessage.contains('Accepté') || e.displayMessage.contains('succès')) {
           isImgAccepted = true;
           imgMessage = e.displayMessage;
        } else {
           throw Exception('IA Image Error: ${e.displayMessage}');
        }
      } catch (e) {
        throw Exception('Erreur IA Image: $e');
      }

      // 3. Validate with HuggingFace AI Vocal Model
      if (mounted) setState(() => _loadingStep = '🎙️ Analyse IA vocale en cours...\n(peut prendre 30-45s)');
      bool isVocAccepted = false;
      String vocMessage = '';
      try {
        final vocAiResult = await _api.validateVocalAudio(
          _audioFile!.bytes!,
          _audioFile!.name,
        );

        if (vocAiResult is Map) {
          isVocAccepted = vocAiResult['accepte'] == true || 
                          vocAiResult['status'] == 'success' ||
                          (vocAiResult['message']?.toString().contains('Accepté') ?? false) ||
                          (vocAiResult['message']?.toString().contains('succès') ?? false);
          vocMessage = vocAiResult['message'] ?? 'Analyse Vocale effectuée';
        } else {
          final resStr = vocAiResult.toString();
          isVocAccepted = resStr.contains('Accepté') || resStr.contains('success') || resStr.contains('succès');
          vocMessage = resStr;
        }
      } on ApiError catch (e) {
        if (e.displayMessage.contains('Accepté') || e.displayMessage.contains('succès')) {
           isVocAccepted = true;
           vocMessage = e.displayMessage;
        } else {
           throw Exception('IA Vocal Error: ${e.displayMessage}');
        }
      } catch (e) {
        throw Exception('Erreur IA Vocale: $e');
      }

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
         _imgSuccessMessage = imgMessage;
         _vocSuccessMessage = vocMessage;
         _successMessage = 'Validation IA réussie !';
         _isAiValidated = true;
         _loading = false;
         _loadingStep = '';
      });
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur API: ${e.displayMessage}';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur: ${e.toString()}';
          _loading = false;
        });
      }
    }
  }

  Future<void> _finalizeSubmission() async {
    setState(() {
      _loading = true;
      _loadingStep = '📤 Envoi final au serveur...';
      _error = null;
    });

    try {
      final proofUrl = _proofUrlController.text.trim();
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur Envoi: ${e.toString()}';
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

  String _formatProfessionalMessage(String title, String rawMessage) {
    if (title.contains('IMAGE')) {
      return "L'analyse de l'environnement de travail a été complétée avec succès. "
             "La correspondance biométrique faciale avec le profil utilisateur est confirmée. "
             "La conformité du poste de développement est validée. "
             "\n\nDétails : ${rawMessage.replaceAll('✅', '').trim()}";
    } else {
      return "L'analyse de l'empreinte vocale et de la cohérence sémantique a été validée avec succès. "
             "La participation active et authentifiée du candidat est certifiée conforme aux exigences de l'épreuve. "
             "\n\nDétails : ${rawMessage.replaceAll('✅', '').trim()}";
    }
  }

  Widget _buildAiResultCard({required String title, required String message, required IconData icon, required bool isDark}) {
    final profMessage = _formatProfessionalMessage(title, message);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.green.withAlpha(25) : Colors.green.withAlpha(12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withAlpha(60), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.green, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              const Icon(Icons.verified_user_rounded, color: Colors.green, size: 20),
            ],
          ),
          const Divider(color: Colors.green, height: 24, thickness: 0.5),
          Text(
            profMessage,
            style: TextStyle(
              color: isDark ? Colors.white.withAlpha(220) : Colors.grey.shade900,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
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
                            // --- Professional Instruction Banner ---
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.primary.withAlpha(40)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 28),
                                  const SizedBox(width: 16),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'CONSIGNES DE VALIDATION',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Pour une analyse réussie, assurez-vous que votre visage et votre écran de code sont visibles simultanément sur la photo.',
                                          style: TextStyle(fontSize: 13, height: 1.4),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
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
                      if (widget.initialSubmission != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.withAlpha(50)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.group, color: Colors.orange, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  widget.initialSubmission!.isApproved 
                                      ? 'Cette soumission a été validée par le jury.'
                                      : 'Soumission effectuée par votre équipe.',
                                  style: const TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                        readOnly: !widget.isLeader || widget.initialSubmission?.isApproved == true,
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
                        readOnly: !widget.isLeader || widget.initialSubmission?.isApproved == true,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Workspace Photo (Anti-Triche)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Cadrez votre visage ainsi que votre environnement de développement (PC).',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
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
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Expliquez brièvement les tâches que vous venez d\'accomplir.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: (widget.isLeader && widget.initialSubmission?.isApproved != true) 
                            ? _startStopRecording 
                            : null,
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
                                      : (_audioFile != null 
                                          ? 'Vocal enregistré ! (${(_audioFile!.size / 1024).toStringAsFixed(1)} KB)' 
                                          : (widget.initialSubmission != null 
                                              ? 'Nouvelle explication audio requise pour mise à jour...' 
                                              : 'Appuyez pour enregistrer un vocal en direct...')),
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
                      // --- AI Results (Image) ---
                      if (_imgSuccessMessage != null) ...[
                        const SizedBox(height: 16),
                        _buildAiResultCard(
                          title: 'VÉRIFICATION IMAGE',
                          message: _imgSuccessMessage!,
                          icon: Icons.image_search_rounded,
                          isDark: isDark,
                        ),
                      ],

                      // --- AI Results (Vocal) ---
                      if (_vocSuccessMessage != null) ...[
                        const SizedBox(height: 12),
                        _buildAiResultCard(
                          title: 'VÉRIFICATION VOCALE',
                          message: _vocSuccessMessage!,
                          icon: Icons.keyboard_voice_rounded,
                          isDark: isDark,
                        ),
                      ],

                      if (_successMessage != null && _imgSuccessMessage == null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.withAlpha(50)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _successMessage!,
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      if (_loading && _loadingStep.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary.withAlpha(40)),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  _loadingStep,
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : Colors.grey.shade800,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (widget.isLeader && widget.initialSubmission?.isApproved != true) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _loading ? null : (_isAiValidated ? _finalizeSubmission : _submit),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isAiValidated ? Colors.green : AppColors.primary,
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
                                : Text(
                                    _isAiValidated 
                                        ? '🚀 CONFIRMER LA VALIDATION' 
                                        : (widget.initialSubmission == null ? 'Analyser le checkpoint' : 'Relancer l\'analyse'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            widget.initialSubmission?.isApproved == true 
                                ? 'Validation finale reçue : modification impossible.'
                                : 'Lecture seule pour les membres.',
                            style: TextStyle(
                              color: widget.initialSubmission?.isApproved == true ? Colors.green : Colors.grey.shade500, 
                              fontStyle: FontStyle.italic,
                              fontWeight: widget.initialSubmission?.isApproved == true ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
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
