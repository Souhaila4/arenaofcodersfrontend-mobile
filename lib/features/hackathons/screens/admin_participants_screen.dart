import 'package:flutter/material.dart';
import 'package:arena/core/services/api_service.dart';
import 'package:arena/core/theme/app_theme.dart';
import 'package:arena/core/models/auth_models.dart';
import 'package:arena/features/profile/screens/public_profile_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminParticipantsScreen extends StatefulWidget {
  final String competitionId;
  final String competitionTitle;

  const AdminParticipantsScreen({
    super.key,
    required this.competitionId,
    required this.competitionTitle,
  });

  @override
  State<AdminParticipantsScreen> createState() => _AdminParticipantsScreenState();
}

class _AdminParticipantsScreenState extends State<AdminParticipantsScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  
  List<dynamic> _allParticipants = [];
  List<dynamic> _topParticipants = [];
  int _total = 0;
  int _topN = 5;
  String? _winnerId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final allResult = await _api.getAllParticipantsAdmin(widget.competitionId);
      final topResult = await _api.getTopParticipantsAdmin(widget.competitionId);

      if (mounted) {
        setState(() {
          _allParticipants = allResult['participants'] as List<dynamic>? ?? [];
          _total = allResult['totalParticipants'] as int? ?? _allParticipants.length;
          
          _topParticipants = topResult['preselected'] as List<dynamic>? ?? [];
          _topN = topResult['topN'] as int? ?? 5;
          _winnerId = topResult['winnerId'] as String?;
          
          _loading = false;
        });
      }
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = 'Erreur de connexion');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _selectWinner(String participantId, String participantName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sélectionner le gagnant 🏆'),
        content: Text('Voulez-vous désigner $participantName comme gagnant de ce hackathon ? Cette action va lui envoyer une notification automatique avec les coordonnées de votre entreprise.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await _api.selectWinner(widget.competitionId, participantId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Gagnant sélectionné avec succès !'), backgroundColor: Colors.green),
        );
        _load(); // Reload data
      }
    } on ApiError catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.displayMessage}'), backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur inattendue.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.arrow_back, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            const Text(
                              'Participants',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              widget.competitionTitle,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh, color: AppColors.primary, size: 22),
                      ),
                    ],
                  ),
                ),
                
                // TabBar
                TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: AppColors.primary,
                  tabs: [
                    Tab(text: 'Tous ($_total)'),
                    Tab(text: 'Top $_topN'),
                  ],
                ),

                // Content
                if (_loading)
                  const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
                else if (_error != null)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                          const SizedBox(height: 12),
                          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                          TextButton(onPressed: _load, child: const Text('Réessayer')),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Tous les participants tab
                        _allParticipants.isEmpty
                            ? _buildEmptyState('Aucun participant')
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _allParticipants.length,
                                itemBuilder: (context, index) {
                                  return _ParticipantCard(
                                    participant: _allParticipants[index],
                                    isDark: isDark,
                                    isTopN: false,
                                  );
                                },
                              ),
                        // Top N participants tab
                        _topParticipants.isEmpty
                            ? _buildEmptyState('Aucune soumission évaluée pour le moment')
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _topParticipants.length,
                                itemBuilder: (context, index) {
                                  return _ParticipantCard(
                                    participant: _topParticipants[index],
                                    isDark: isDark,
                                    isTopN: true,
                                    winnerId: _winnerId,
                                    onSelectWinner: _selectWinner,
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade600),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}

class _ParticipantCard extends StatelessWidget {
  final Map<String, dynamic> participant;
  final bool isDark;
  final bool isTopN;
  final String? winnerId;
  final Future<void> Function(String participantId, String name)? onSelectWinner;

  const _ParticipantCard({
    required this.participant,
    required this.isDark,
    required this.isTopN,
    this.winnerId,
    this.onSelectWinner,
  });

  @override
  Widget build(BuildContext context) {
    final user = participant['user'] as Map<String, dynamic>? ?? {};
    final status = participant['status'] as String? ?? 'JOINED';
    final participantId = participant['participantId'] as String?;
    final githubUrl = participant['githubUrl'] as String?;
    final antiCheatScore = participant['antiCheatScore'];
    final score = participant['score'];
    final scoringReport = participant['scoringReport'] as Map<String, dynamic>?;
    final isWinner = participant['isWinner'] == true;
    
    final firstName = user['firstName'] ?? '';
    final lastName = user['lastName'] ?? '';
    final fullName = '$firstName $lastName';
    final email = user['email'] ?? '';
    final specialty = user['mainSpecialty'] as String?;

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'SUBMITTED':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'DISQUALIFIED':
        statusColor = Colors.red;
        statusIcon = Icons.block;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isWinner 
            ? AppColors.primary.withAlpha(isDark ? 30 : 20)
            : (isDark ? AppColors.surfaceDark : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWinner
              ? AppColors.primary
              : status == 'DISQUALIFIED'
                  ? Colors.red.withAlpha(60)
                  : status == 'SUBMITTED'
                      ? Colors.green.withAlpha(60)
                      : (isDark ? AppColors.primary.withAlpha(30) : Colors.grey.shade200),
          width: isWinner ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Winner Badge 🏆
          if (isWinner)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🏆', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 8),
                  Text('GAGNANT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
            
          // User info row
          InkWell(
            onTap: user['id'] != null ? () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => PublicProfileScreen(userId: user['id']),
              ));
            } : null,
            child: Row(
              children: [
                user['avatarUrl'] != null && user['avatarUrl'].toString().isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          '${ApiService.baseUrl.replaceAll('/api', '')}${user['avatarUrl']}',
                          fit: BoxFit.cover,
                          width: 44,
                          height: 44,
                          errorBuilder: (_, __, ___) => CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.primary.withAlpha(40),
                            child: Text(
                              '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}',
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      )
                    : CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.primary.withAlpha(40),
                        child: Text(
                          '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}',
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                        ),
                      ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.textLightPrimary,
                        ),
                      ),
                      Text(
                        email,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                // Status badge OR Score
                if (isTopN && score != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${score.toStringAsFixed(1)} / 100',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          status,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Specialty
          if (specialty != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                specialty,
                style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ],

          // GitHub URL
          if (githubUrl != null && githubUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final uri = Uri.tryParse(githubUrl);
                if (uri != null) {
                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (_) {}
                }
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? Colors.white.withAlpha(10) : Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        githubUrl,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.primary,
                          decoration: TextDecoration.underline,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.open_in_new, size: 16, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ],

          // Scores & AI Report (Top N View)
          if (isTopN && scoringReport != null) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.psychology, size: 16, color: Colors.purpleAccent),
                const SizedBox(width: 6),
                Text(
                  'Évaluation IA (Base: ${scoringReport['baseScore'] ?? '-'}, Anti-Triche: ${antiCheatScore ?? '-'}%)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purpleAccent),
                ),
              ],
            ),
            if (scoringReport['reasoning'] != null) ...[
              const SizedBox(height: 6),
              Text(
                scoringReport['reasoning'],
                style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade300 : Colors.grey.shade800, height: 1.4),
              ),
            ],
            
            // Choose Winner Button!
            if (winnerId == null && participantId != null && onSelectWinner != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Text('🏆', style: TextStyle(fontSize: 16)),
                  label: const Text('Choisir ce Gagnant', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => onSelectWinner!(participantId, fullName),
                ),
              ),
            ],
          ] else if (antiCheatScore != null) ...[
            // Just basic anti cheat score for "All" view
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.security, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  'Score Anti-Triche: ${antiCheatScore}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: status == 'DISQUALIFIED' ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
