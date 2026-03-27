import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:arena/core/models/competition_model.dart';
import 'package:arena/core/models/auth_models.dart';
import 'package:arena/core/services/api_service.dart';
import 'package:arena/core/theme/app_theme.dart';
import 'package:arena/features/hackathons/screens/submit_checkpoint_screen.dart';
import 'package:arena/features/profile/screens/public_profile_screen.dart';
import 'admin_participants_screen.dart';

class HackathonDetailScreen extends StatefulWidget {
  final String competitionId;

  const HackathonDetailScreen({super.key, required this.competitionId});

  @override
  State<HackathonDetailScreen> createState() => _HackathonDetailScreenState();
}

class _HackathonDetailScreenState extends State<HackathonDetailScreen> {
  final _api = ApiService();
  Competition? _competition;
  bool _loading = true;
  String? _error;
  bool _joining = false;
  bool _joined = false;
  AuthUser? _user;

  // --- Anti-cheat vars ---
  final _githubController = TextEditingController();
  bool _isSubmittingGithub = false;
  String? _antiCheatScore;
  String? _antiCheatMessage;
  String _participantStatus = 'JOINED'; // JOINED, SUBMITTED, DISQUALIFIED
  String? _antiCheatError;

  /// Pipeline score (0–100) for submitted work; null if not yet computed or not submitted.
  double? _submissionScore;
  /// Whether the user is in the top 5 (preselected) for this hackathon.
  bool _isPreselected = false;
  /// Rank 1–5 when preselected; null otherwise.
  int? _preselectedRank;
  
  /// The AI scoring report containing reasoning, breakdown, and warnings
  Map<String, dynamic>? _scoringReport;
  bool _isWinner = false;

  List<CheckpointSubmissionWithCheckpoint> _checkpointSubmissions = [];
  bool _loadingCheckpoints = false;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _load();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _githubController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    try {
      final u = await _api.getMe();
      if (mounted) setState(() => _user = u);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final c = await _api.getCompetitionById(widget.competitionId);

      // Also check if the user is already a participant
      bool alreadyJoined = false;
      try {
        alreadyJoined = await _api.checkMyParticipation(widget.competitionId);
        // If participation returned, extract status info
        if (alreadyJoined) {
          // Fetch participation details to get status, score, preselection
          try {
            final details = await _api.getParticipationDetails(widget.competitionId);
            if (details != null) {
              _participantStatus = details['status'] as String? ?? 'JOINED';
              if (details['githubUrl'] != null) {
                _githubController.text = details['githubUrl'] as String;
              }
              if (details['antiCheatScore'] != null) {
                _antiCheatScore = '${details['antiCheatScore']}%';
              }
              if (details['score'] != null) {
                _submissionScore = (details['score'] as num).toDouble();
              }
              _isPreselected = details['isPreselected'] as bool? ?? false;
              _preselectedRank = details['preselectedRank'] as int?;
              _isWinner = details['isWinner'] as bool? ?? false;
              if (details['scoringReport'] != null) {
                _scoringReport = details['scoringReport'] as Map<String, dynamic>;
              }
            }
          } catch (_) {}
        }
      } catch (_) {
        // Ignore error when checking participation
      }

      if (mounted) setState(() {
        _competition = c;
        _joined = alreadyJoined;
        _loading = false;
      });

      if (alreadyJoined) {
        _loadCheckpointSubmissions();
      }
    } on ApiError catch (e) {
      if (e.statusCode == 401 && mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/signin', (route) => false);
        return;
      }
      if (mounted) setState(() {
        _error = e.displayMessage;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _error = 'Connection error';
        _loading = false;
      });
    }
  }

  Future<void> _loadCheckpointSubmissions() async {
    if (!mounted) return;
    setState(() => _loadingCheckpoints = true);
    try {
      final list = await _api.getMyCheckpointSubmissions(widget.competitionId);
      if (mounted) setState(() {
        _checkpointSubmissions = list;
        _loadingCheckpoints = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingCheckpoints = false);
    }
  }

  /// Refreshes score and preselection from the API (e.g. after submit or when pipeline has run).
  Future<void> _refreshParticipationDetails() async {
    try {
      final details = await _api.getParticipationDetails(widget.competitionId);
      if (mounted && details != null) {
        setState(() {
          if (details['score'] != null) {
            _submissionScore = (details['score'] as num).toDouble();
          }
          _isPreselected = details['isPreselected'] as bool? ?? false;
          _preselectedRank = details['preselectedRank'] as int?;
          _isWinner = details['isWinner'] as bool? ?? false;
          if (details['scoringReport'] != null) {
            _scoringReport = details['scoringReport'] as Map<String, dynamic>;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _join() async {
    if (_competition == null || !_competition!.canJoin) return;
    
    // Pick an image from the camera
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 70, // Compress to reduce size
    );

    if (image == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Une photo personnelle est obligatoire pour rejoindre ce hackathon (Anti-Triche).'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _joining = true);
    try {
      await _api.joinCompetition(widget.competitionId, File(image.path));
      if (mounted) setState(() {
        _joined = true;
        _joining = false;
      });
      _loadCheckpointSubmissions();
    } on ApiError catch (e) {
      if (mounted) setState(() => _joining = false);
      if (e.statusCode == 409) {
        setState(() => _joined = true);
        return;
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.displayMessage), backgroundColor: Colors.red),
      );
    } catch (_) {
      if (mounted) setState(() => _joining = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to join'), backgroundColor: Colors.red),
      );
    }
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
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 56, color: Colors.grey.shade500),
                            const SizedBox(height: 16),
                            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400)),
                            const SizedBox(height: 24),
                            TextButton.icon(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh, size: 20),
                              label: const Text('Retry'),
                              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _competition == null
                      ? const SizedBox.shrink()
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: AppColors.primary,
                          child: CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                                child: Row(
                                  children: [
                                    IconButton(
                                      onPressed: () => Navigator.of(context).pop(),
                                      icon: Icon(Icons.arrow_back, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                                    ),
                                    const Expanded(
                                      child: Text(
                                        'Hackathon',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    const SizedBox(width: 48),
                                  ],
                                ),
                              ),
                            ),
                            if (_isWinner)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade400,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(color: Colors.amber.withAlpha(50), blurRadius: 10, spreadRadius: 2),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Row(
                                          children: [
                                            Text('🏆', style: TextStyle(fontSize: 28)),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                'Félicitations, vous avez gagné !',
                                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          "Vous avez été sélectionné comme le gagnant de ce hackathon. L'organisateur vous a envoyé une notification avec ses coordonnées pour vous contacter.",
                                          style: TextStyle(fontSize: 14, color: Colors.black.withAlpha(180)),
                                        ),
                                        if (_competition?.creator?.id != null) ...[
                                          const SizedBox(height: 12),
                                          SizedBox(
                                            height: 38,
                                            child: OutlinedButton.icon(
                                              onPressed: () {
                                                Navigator.push(context, MaterialPageRoute(
                                                  builder: (_) => PublicProfileScreen(userId: _competition!.creator!.id),
                                                ));
                                              },
                                              icon: const Icon(Icons.person, size: 16),
                                              label: const Text("Voir le profil de l'organisateur"),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.black87,
                                                side: BorderSide(color: Colors.amber.shade700),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        _chip(_competition!.difficultyDisplay, _diffColor()),
                                        if (_competition!.specialty != null) ...[
                                          const SizedBox(width: 8),
                                          _chip(_competition!.specialty!, AppColors.primary),
                                        ],
                                        const Spacer(),
                                        Text(
                                          _competition!.statusDisplay,
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _competition!.title,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : AppColors.textLightPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _competition!.description,
                                      style: TextStyle(
                                        fontSize: 15,
                                        height: 1.5,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    _infoRow(Icons.calendar_today, '${_formatDate(_competition!.startDate)} – ${_formatDate(_competition!.endDate)}'),
                                    if (_competition!.rewardPool > 0)
                                      _infoRow(Icons.emoji_events, 'Prize pool: \$${_competition!.rewardPool.toStringAsFixed(0)}'),
                                    if (_competition!.maxParticipants != null)
                                      _infoRow(Icons.people_outline, 'Max ${_competition!.maxParticipants} participants'),
                                    if (_competition!.participantsCount > 0)
                                      _infoRow(Icons.people, '${_competition!.participantsCount} joined'),
                                    const SizedBox(height: 32),
                                    // Hide join/submit for the creator (admin who made this hackathon)
                                    if (_competition!.creator?.id != _user?.id) ...[
                                      _buildJoinOrStatusButton(),
                                      if (_joined) ...[
                                        const SizedBox(height: 24),
                                        _buildCheckpointsSection(isDark),
                                        const SizedBox(height: 32),
                                        _buildFinalSubmissionSection(isDark),
                                      ],
                                    ],
                                    // Admin/Company: view participants button
                                    if (_user?.role == 'ADMIN' || _user?.role == 'COMPANY') ...[
                                      const SizedBox(height: 24),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 48,
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => AdminParticipantsScreen(
                                                  competitionId: widget.competitionId,
                                                  competitionTitle: _competition!.title,
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.people, color: AppColors.primary),
                                          label: const Text(
                                            'Voir les participants',
                                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: AppColors.primary),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
        ),
    );
  }

  Widget _buildJoinOrStatusButton() {
    // If the user has already joined, show the "Joined" button regardless of the current status
    if (_joined || _competition!.canJoin) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: _joined ? null : (_joining ? null : _join),
          icon: _joining
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                )
              : Icon(_joined ? Icons.check_circle : Icons.add_circle_outline, size: 22),
          label: Text(_joined ? 'Joined' : (_joining ? 'Joining…' : 'Join competition')),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          _competition!.statusDisplay,
          style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildCheckpointsSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Checkpoints',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textLightPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Each checkpoint opens every 2 hours and stays open for 15 minutes. Submit during that window to stay in the competition.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
          if (_loadingCheckpoints) ...[
            const SizedBox(height: 16),
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
              ),
            ),
          ] else if (_checkpointSubmissions.isEmpty) ...[
            const SizedBox(height: 16),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No checkpoints yet',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            ..._checkpointSubmissions.map((sub) => _buildCheckpointSubmissionTile(isDark, sub)),
          ],
        ],
      ),
    );
  }

  Widget _buildCheckpointSubmissionTile(bool isDark, CheckpointSubmissionWithCheckpoint sub) {
    final statusColor = sub.isApproved
        ? Colors.green
        : sub.isRejected || sub.isMissed
            ? Colors.red
            : sub.isSubmitted
                ? Colors.orange
                : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.black26 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withAlpha(40)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    sub.checkpoint.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.textLightPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(35),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withAlpha(80)),
                  ),
                  child: Text(
                    sub.statusDisplay,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  'Due ${_formatDate(sub.checkpoint.dueDate)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
            Row(
              children: [
                Icon(Icons.lock_open, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  'Opens ${_formatDateTime(sub.checkpoint.opensAt)} · Closes ${_formatDateTime(sub.checkpoint.dueDate)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
            if (sub.proofUrl != null && sub.proofUrl!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.link, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      sub.proofUrl!,
                      style: TextStyle(fontSize: 12, color: AppColors.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (sub.canSubmit) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer, size: 16, color: Colors.green.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Temps restant : ${_formatDuration(sub.checkpoint.dueDate.difference(DateTime.now()))}',
                        style: TextStyle(fontSize: 12, color: Colors.green.shade600, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: OutlinedButton(
                  onPressed: () async {
                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => SubmitCheckpointScreen(
                          competitionId: widget.competitionId,
                          checkpointId: sub.checkpointId,
                          checkpointTitle: sub.checkpoint.title,
                          dueDate: sub.checkpoint.dueDate,
                          opensAt: sub.checkpoint.opensAt,
                          onSubmitted: _loadCheckpointSubmissions,
                        ),
                      ),
                    );
                    if (result == true && mounted) _loadCheckpointSubmissions();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ] else if (sub.notYetOpen) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'S\'ouvre dans : ${_formatDuration(sub.checkpoint.opensAt.difference(DateTime.now()))}',
                        style: TextStyle(fontSize: 12, color: Colors.orange.shade700, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (sub.windowClosed) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock, size: 16, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Submission window closed',
                      style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  /// Wraps the anti-cheat/submit section so it only appears in the
  /// final 15-minute window before the hackathon ends.
  Widget _buildFinalSubmissionSection(bool isDark) {
    final isSubmitted = _participantStatus == 'SUBMITTED';
    final isDisqualified = _participantStatus == 'DISQUALIFIED';

    // Always show if already submitted or disqualified (status feedback)
    if (isSubmitted || isDisqualified) {
      return _buildAntiCheatSection(isDark);
    }

    final endDate = _competition!.endDate;
    final now = DateTime.now();
    final submissionOpensAt = endDate.subtract(const Duration(hours: 1));

    // If the hackathon has ended, show the section (closed state)
    if (now.isAfter(endDate)) {
      return _buildAntiCheatSection(isDark);
    }

    // If we are within the 1-hour window → show the real form
    if (now.isAfter(submissionOpensAt) || now.isAtSameMomentAs(submissionOpensAt)) {
      return _buildAntiCheatSection(isDark);
    }

    // Otherwise → show a locked countdown card
    final remaining = submissionOpensAt.difference(now);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_clock, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Soumission Finale',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.textLightPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'La soumission de votre travail final (lien GitHub) sera disponible 1 heure avant la fin du hackathon.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withAlpha(60)),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule, size: 18, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  'S\'ouvre dans : ${_formatDuration(remaining)}',
                  style: TextStyle(fontSize: 13, color: Colors.orange.shade700, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAntiCheatSection(bool isDark) {
    final isSubmitted = _participantStatus == 'SUBMITTED';
    final isDisqualified = _participantStatus == 'DISQUALIFIED';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDisqualified
              ? Colors.red.withAlpha(80)
              : isSubmitted
                  ? Colors.green.withAlpha(80)
                  : AppColors.primary.withAlpha(50),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isDisqualified ? Icons.gpp_bad : Icons.security,
                color: isDisqualified ? Colors.red : AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _competition!.antiCheatEnabled
                      ? 'Soumission & Anti-Triche'
                      : 'Soumettre votre travail',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.textLightPrimary,
                  ),
                ),
              ),
            ],
          ),

          // ── DISQUALIFIED STATE ──
          if (isDisqualified) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withAlpha(50)),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.block, color: Colors.red, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Disqualifié',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  if (_antiCheatScore != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Score IA : $_antiCheatScore (seuil : ${_competition!.antiCheatThreshold ?? 70}%)',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red.shade300),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Votre code a été détecté comme généré par IA au-delà du seuil autorisé. Vous ne pouvez plus soumettre.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red.shade300, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],

          // ── SUBMITTED STATE ──
          if (isSubmitted) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withAlpha(50)),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Work submitted',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  if (_antiCheatScore != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Anti-cheat score: $_antiCheatScore',
                      style: TextStyle(color: Colors.green.shade300, fontSize: 13),
                    ),
                  ],
                  if (_submissionScore != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Your score: ${_submissionScore!.toStringAsFixed(1)}/100',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_scoringReport != null && _scoringReport!['codeJudge'] != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(40),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withAlpha(30)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.psychology, size: 16, color: Colors.greenAccent),
                                SizedBox(width: 6),
                                Text('AI Reasoning', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _scoringReport!['codeJudge']['reasoning'] ?? 'No reasoning provided.',
                              style: TextStyle(color: Colors.grey.shade300, fontSize: 13, height: 1.4),
                            ),
                            if (_scoringReport!['codeJudge']['warnings'] != null && (_scoringReport!['codeJudge']['warnings'] as List).isNotEmpty) ...[
                              const SizedBox(height: 10),
                              ...(_scoringReport!['codeJudge']['warnings'] as List).map((w) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('• ', style: TextStyle(color: Colors.orange.shade300, fontSize: 13)),
                                    Expanded(child: Text(w.toString(), style: TextStyle(color: Colors.orange.shade300, fontSize: 13))),
                                  ],
                                ),
                              )),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ] else ...[
                    const SizedBox(height: 8),
                    Text(
                      'Score pending…',
                      style: TextStyle(color: Colors.green.shade300, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (_isPreselected && _preselectedRank != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.accentCyan.withAlpha(40),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.accentCyan.withAlpha(120)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.emoji_events, color: AppColors.accentCyan, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Preselected · Rank #$_preselectedRank',
                            style: const TextStyle(
                              color: AppColors.accentCyan,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_submissionScore != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Not in top 5',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Your work has been submitted successfully. Good luck!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.green.shade300, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],

          // ── JOINED STATE (can submit) ──
          if (!isSubmitted && !isDisqualified) ...[
            const SizedBox(height: 8),
            Text(
              _competition!.antiCheatEnabled
                  ? 'Ce hackathon utilise la vérification Anti-Triche IA. Fournissez votre lien GitHub pour soumettre votre travail.'
                  : 'Fournissez le lien GitHub de votre repository pour soumettre votre travail.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _githubController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: 'https://github.com/votre-compte/votre-repo',
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmittingGithub ? null : _submitGithubLink,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmittingGithub
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Soumettre le repository', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
            if (_antiCheatError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_antiCheatError!, style: const TextStyle(color: Colors.red))),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _submitGithubLink() async {
    final url = _githubController.text.trim();
    if (url.isEmpty) {
      setState(() => _antiCheatError = 'Veuillez entrer une URL GitHub valide.');
      return;
    }

    setState(() {
      _isSubmittingGithub = true;
      _antiCheatError = null;
    });

    try {
      final result = await _api.submitGithubLink(widget.competitionId, url);
      final status = result['status'] as String? ?? 'SUBMITTED';
      final message = result['message'] as String? ?? '';
      final score = result['antiCheatScore'];

      if (mounted) {
        setState(() {
          _participantStatus = status;
          _antiCheatMessage = message;
          if (score != null) _antiCheatScore = '${score}%';
          _isSubmittingGithub = false;
        });
        if (status == 'SUBMITTED') {
          _refreshParticipationDetails();
        }
      }
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _antiCheatError = e.displayMessage;
          _isSubmittingGithub = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _antiCheatError = 'Erreur lors de la soumission.';
          _isSubmittingGithub = false;
        });
      }
    }
  }

  Color _diffColor() {
    if (_competition == null) return AppColors.primary;
    return _competition!.difficulty.toUpperCase() == 'HARD'
        ? AppColors.accentOrange
        : _competition!.difficulty.toUpperCase() == 'EASY'
            ? Colors.green
            : AppColors.primary;
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade300, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
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

  String _formatDuration(Duration d) {
    if (d.isNegative) return '00:00:00';
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}
