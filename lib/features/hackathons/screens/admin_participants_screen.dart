import 'package:flutter/material.dart';
import 'package:arena/core/services/api_service.dart';
import 'package:arena/core/theme/app_theme.dart';
import 'package:arena/core/models/auth_models.dart';
import 'package:arena/features/profile/screens/public_profile_screen.dart';
import 'package:arena/core/models/competition_model.dart';
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
  
  List<dynamic> _teams = [];
  List<dynamic> _topTeams = [];
  int _totalTeams = 0;
  int _topN = 5;
  String? _winnerId;
  String? _winnerId2;
  String? _winnerId3;

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
          _teams = allResult['teams'] as List<dynamic>? ?? [];
          _totalTeams = allResult['totalTeams'] as int? ?? _teams.length;
          
          _topTeams = topResult['preselected'] as List<dynamic>? ?? [];
          _topN = topResult['topN'] as int? ?? 5;
          _winnerId = topResult['winnerId'] as String?;
          _winnerId2 = topResult['winnerId2'] as String?;
          _winnerId3 = topResult['winnerId3'] as String?;
          
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
  Future<void> _selectWinner(String participantId, String teamName) async {
    final rank = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sélectionner le rang 🏆'),
        content: Text('Quel rang souhaitez-vous attribuer à l\'équipe "$teamName" ?\n\nNote: Si un gagnant existait déjà pour ce rang, il sera remplacé.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _rankButton(ctx, 1, '1er (Or)', Colors.amber),
              _rankButton(ctx, 2, '2ème (Argent)', Colors.grey.shade400),
              _rankButton(ctx, 3, '3ème (Bronze)', Colors.brown.shade400),
            ],
          ),
        ],
      ),
    );

    if (rank == null) return;

    setState(() => _loading = true);
    try {
      await _api.selectWinner(widget.competitionId, participantId, rank);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Équipe sélectionnée pour le Top $rank avec succès !'), backgroundColor: Colors.green),
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

  Widget _rankButton(BuildContext context, int rank, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        width: 180,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: rank == 1 ? Colors.black : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => Navigator.pop(context, rank),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
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
                              'Gestion des Équipes',
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
                    Tab(text: 'Équipes ($_totalTeams)'),
                    Tab(text: 'Classement (Top $_topN)'),
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
                        // Toutes les équipes tab
                        _teams.isEmpty
                            ? _buildEmptyState('Aucune équipe inscrite')
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _teams.length,
                                itemBuilder: (context, index) {
                                  return _TeamCard(
                                    team: _teams[index],
                                    isDark: isDark,
                                    isTopView: false,
                                  );
                                },
                              ),
                        // Classement tab
                        _topTeams.isEmpty
                            ? _buildEmptyState('Aucune soumission évaluée')
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _topTeams.length,
                                itemBuilder: (context, index) {
                                  return _TeamCard(
                                    team: _topTeams[index],
                                    isDark: isDark,
                                    isTopView: true,
                                    winnerId: _winnerId,
                                    winnerId2: _winnerId2,
                                    winnerId3: _winnerId3,
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
          Icon(Icons.groups_outlined, size: 64, color: Colors.grey.shade600),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  final Map<String, dynamic> team;
  final bool isDark;
  final bool isTopView;
  final String? winnerId;
  final String? winnerId2;
  final String? winnerId3;
  final Future<void> Function(String participantId, String teamName)? onSelectWinner;

  const _TeamCard({
    required this.team,
    required this.isDark,
    required this.isTopView,
    this.winnerId,
    this.winnerId2,
    this.winnerId3,
    this.onSelectWinner,
  });

  @override
  Widget build(BuildContext context) {
    final teamName = team['name'] ?? 'Équipe sans nom';
    final status = team['status'] as String? ?? 'FORMING';
    final members = (team['members'] as List<dynamic>?) ?? [];
    
    // For TopView, the backend might return the leader's participantId as the reference
    final participantId = team['participantId'] as String? ?? (members.isNotEmpty ? members.first['id'] : null);
    
    final githubUrl = team['githubUrl'] as String?;
    final antiCheatScore = team['antiCheatScore'];
    final score = team['score'];
    final scoringReport = team['scoringReport'] as Map<String, dynamic>?;
    final isWinner = team['isWinner'] == true;
    final winnerRank = team['winnerRank'] as int?;

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'READY':
      case 'PARTICIPATING':
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
                  : (isDark ? AppColors.primary.withAlpha(30) : Colors.grey.shade200),
          width: isWinner ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Winner Badge
          if (isWinner)
            _buildWinnerBadge(winnerRank),
            
          // Team Header
          GestureDetector(
            onTap: () {
              if (members.length > 1) {
                // Show member selection dialog
                _showMemberSelectionDialog(context, teamName, members);
              } else {
                // Solo user or just one member, open profile directly
                final leaderId = members.isNotEmpty ? members.first['userId'] : team['user']?['id'];
                if (leaderId != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: leaderId)),
                  );
                }
              }
            },
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(40),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.groups, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teamName,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.textLightPrimary,
                        ),
                      ),
                      Text(
                        '${members.length} membres • Cliquer pour voir les profils',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                if (isTopView && score != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${score.toStringAsFixed(1)} pts',
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
                    child: Text(
                      status,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          
          // Members avatars
          Wrap(
            spacing: -8,
            children: members.map((m) {
              final avatar = m['avatarUrl'] as String?;
              final userId = m['userId'] as String?;
              return GestureDetector(
                onTap: userId != null 
                  ? () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: userId)),
                    )
                  : null,
                child: Tooltip(
                  message: '${m['firstName']} ${m['lastName']}',
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    backgroundImage: (avatar != null && avatar.isNotEmpty) ? NetworkImage('${ApiService.baseUrl.replaceAll('/api', '')}$avatar') : null,
                    child: (avatar == null || avatar.isEmpty) ? const Icon(Icons.person, size: 14, color: Colors.grey) : null,
                  ),
                ),
              );
            }).toList(),
          ),

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
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        githubUrl,
                        style: const TextStyle(fontSize: 12, color: AppColors.primary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // AI Report
          if (isTopView && scoringReport != null) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.psychology, size: 16, color: Colors.purpleAccent),
                const SizedBox(width: 6),
                Text(
                  'Rapport de l\'IA (Anti-Triche: ${antiCheatScore ?? 0}%)',
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
            
            // Detailed Scoring Breakdown (Agent Note)
            _buildScoringDetails(isDark, scoringReport, antiCheatScore),
            
            // Winner Button
            if (isTopView && participantId != null && onSelectWinner != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.emoji_events, size: 18),
                  label: Text(
                    isWinner ? 'Modifier le Rang' : 'Sélectionner comme Gagnant',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isWinner ? Colors.grey : AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => onSelectWinner!(participantId, teamName),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildScoringDetails(bool isDark, Map<String, dynamic> report, dynamic antiCheatScore) {
    final codeJudge = report['codeJudge'] as Map<String, dynamic>?;
    final productJudge = report['productJudge'] as Map<String, dynamic>?;
    final generalReport = report['report'] as Map<String, dynamic>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        
        // Code Evaluation
        if (codeJudge != null) ...[
          _buildJudgeSection(
            isDark: isDark,
            title: 'Évaluation Code',
            icon: Icons.code,
            color: Colors.blueAccent,
            metrics: {
              'Complexité': (codeJudge['complexity'] as num?)?.toDouble() ?? 0,
              'Qualité du Code': (codeJudge['codeQuality'] as num?)?.toDouble() ?? 0,
              'Architecture': (codeJudge['architecture'] as num?)?.toDouble() ?? 0,
            },
            reasoning: codeJudge['reasoning'] as String?,
          ),
          const SizedBox(height: 12),
        ],

        // Product Evaluation
        if (productJudge != null) ...[
          _buildJudgeSection(
            isDark: isDark,
            title: 'Évaluation Produit',
            icon: Icons.lightbulb_outline,
            color: Colors.orangeAccent,
            metrics: {
              'Innovation': (productJudge['innovation'] as num?)?.toDouble() ?? 0,
              'Impact': (productJudge['impact'] as num?)?.toDouble() ?? 0,
              'Usabilité': (productJudge['usability'] as num?)?.toDouble() ?? 0,
            },
            reasoning: productJudge['reasoning'] as String?,
          ),
          const SizedBox(height: 12),
        ],

        // Highlights & Warnings
        if (generalReport != null) ...[
          if (generalReport['highlights'] != null && (generalReport['highlights'] as List).isNotEmpty) ...[
            _buildListSection(
              isDark: isDark,
              title: 'Points Forts',
              items: List<String>.from(generalReport['highlights']),
              icon: Icons.star_border,
              color: Colors.greenAccent,
            ),
            const SizedBox(height: 12),
          ],
          if (generalReport['warnings'] != null && (generalReport['warnings'] as List).isNotEmpty) ...[
            _buildListSection(
              isDark: isDark,
              title: 'Points d\'Attention',
              items: List<String>.from(generalReport['warnings']),
              icon: Icons.warning_amber_rounded,
              color: Colors.redAccent,
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildJudgeSection({
    required bool isDark,
    required String title,
    required IconData icon,
    required Color color,
    required Map<String, double> metrics,
    String? reasoning,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 12),
          ...metrics.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54)),
                    Text('${(e.value * 10).toInt()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: e.value / 10,
                    backgroundColor: color.withAlpha(20),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          )).toList(),
          if (reasoning != null && reasoning.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 16, color: Colors.white10),
            Text(
              reasoning,
              style: TextStyle(
                fontSize: 12, 
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700, 
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildListSection({
    required bool isDark,
    required String title,
    required List<String> items,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700, height: 1.4),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildWinnerBadge(int? rank) {
    String medal = '🏆';
    String label = 'GAGNANT';
    Color color = AppColors.primary;

    if (rank == 1) {
      medal = '🥇';
      label = 'TOP 1 (OR)';
      color = Colors.amber.shade700;
    } else if (rank == 2) {
      medal = '🥈';
      label = 'TOP 2 (ARGENT)';
      color = Colors.grey.shade600;
    } else if (rank == 3) {
      medal = '🥉';
      label = 'TOP 3 (BRONZE)';
      color = Colors.brown.shade600;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(medal, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  void _showMemberSelectionDialog(BuildContext context, String teamName, List<dynamic> members) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A2332) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        title: Column(
          children: [
            const Icon(Icons.groups, color: AppColors.primary, size: 40),
            const SizedBox(height: 12),
            Text(
              teamName,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textLightPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sélectionnez un membre pour voir son profil',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: members.length,
            itemBuilder: (context, index) {
              final m = members[index];
              final name = '${m['firstName']} ${m['lastName']}';
              final avatar = m['avatarUrl'] as String?;
              final role = m['role'] as String?;
              final userId = m['userId'] as String?;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withAlpha(30),
                  backgroundImage: (avatar != null && avatar.isNotEmpty) 
                      ? NetworkImage('${ApiService.baseUrl.replaceAll('/api', '')}$avatar') 
                      : null,
                  child: (avatar == null || avatar.isEmpty) 
                      ? const Icon(Icons.person, color: AppColors.primary) 
                      : null,
                ),
                title: Text(
                  name,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textLightPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  role == 'LEADER' ? '👑 Leader de l\'équipe' : 'Membre',
                  style: TextStyle(
                    color: role == 'LEADER' ? Colors.amber : Colors.grey,
                    fontSize: 12,
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                onTap: () {
                  Navigator.pop(ctx);
                  if (userId != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: userId)),
                    );
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}
