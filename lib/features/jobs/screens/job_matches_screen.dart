import 'package:flutter/material.dart';
import 'package:arena/core/theme/app_theme.dart';
import 'package:arena/core/services/api_service.dart';
import 'package:arena/features/jobs/models/job_match.dart';
import 'package:arena/features/jobs/screens/candidate_profile_screen.dart';

/// Écran affichant les résultats du matching IA pour une offre d'emploi.
/// Chaque candidat a un score, une justification IA, et un bouton "Voir le profil".
class JobMatchesScreen extends StatefulWidget {
  final String jobId;
  final String jobTitle;

  const JobMatchesScreen({
    super.key,
    required this.jobId,
    required this.jobTitle,
  });

  @override
  State<JobMatchesScreen> createState() => _JobMatchesScreenState();
}

class _JobMatchesScreenState extends State<JobMatchesScreen> {
  bool _loading = false;
  bool _matching = false;
  JobMatchesResponse? _results;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExistingMatches();
  }

  Future<void> _loadExistingMatches() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService().getJobMatches(widget.jobId);
      if (mounted) {
        setState(() {
          _results = JobMatchesResponse.fromJson(data);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          // Pas grave si aucun résultat encore
        });
      }
    }
  }

  Future<void> _launchMatching() async {
    setState(() {
      _matching = true;
      _error = null;
    });
    try {
      final data = await ApiService().matchJobCandidates(widget.jobId);
      if (mounted) {
        setState(() {
          _results = JobMatchesResponse.fromJson(data);
          _matching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _matching = false;
        });
      }
    }
  }

  Color _scoreColor(int score) {
    if (score >= 80) return const Color(0xFF22C55E);
    if (score >= 60) return const Color(0xFF3B82F6);
    if (score >= 40) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(widget.jobTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // ─── Header + Bouton Matching ───
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Column(
                      children: [
                        // Bouton Lancer le Matching IA
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C3AED).withAlpha(80),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: _matching ? null : _launchMatching,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 18),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_matching)
                                      const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    else
                                      const Icon(Icons.auto_awesome,
                                          color: Colors.white, size: 22),
                                    const SizedBox(width: 12),
                                    Text(
                                      _matching
                                          ? 'Analyse IA en cours...'
                                          : _results != null &&
                                                  _results!.matches.isNotEmpty
                                              ? 'Relancer le Matching IA'
                                              : 'Lancer le Matching IA',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_matching)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              'L\'IA analyse les profils des candidats...\nCela peut prendre jusqu\'à 30 secondes.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                                height: 1.5,
                              ),
                            ),
                          ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withAlpha(20),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.red.withAlpha(60)),
                              ),
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        if (_results != null && _results!.matches.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.leaderboard,
                                  size: 18, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                '${_results!.totalMatches} candidat(s) classé(s)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white
                                      : Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),

                // ─── Liste des candidats ───
                if (_results != null && _results!.matches.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final match = _results!.matches[index];
                          final user = match.user;
                          final scoreColor = _scoreColor(match.score);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color:
                                  isDark ? AppColors.surfaceDark : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: index == 0
                                    ? const Color(0xFFFFD700).withAlpha(120)
                                    : Colors.grey.withAlpha(30),
                                width: index == 0 ? 1.5 : 1,
                              ),
                              boxShadow: index == 0
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFFFD700)
                                            .withAlpha(25),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Rang + Score + Nom
                                  Row(
                                    children: [
                                      // Rang
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: index == 0
                                              ? const Color(0xFFFFD700)
                                              : index == 1
                                                  ? const Color(0xFFC0C0C0)
                                                  : index == 2
                                                      ? const Color(0xFFCD7F32)
                                                      : isDark
                                                          ? Colors.grey.shade800
                                                          : Colors
                                                              .grey.shade200,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '#${match.rank}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: index < 3
                                                  ? Colors.white
                                                  : Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Nom + Spécialité
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              user != null
                                                  ? '${user.firstName} ${user.lastName}'
                                                  : 'Utilisateur inconnu',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black87,
                                              ),
                                            ),
                                            if (user?.mainSpecialty != null)
                                              Text(
                                                user!.mainSpecialty!,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      // Score
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: scoreColor.withAlpha(25),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color:
                                                  scoreColor.withAlpha(100)),
                                        ),
                                        child: Text(
                                          '${match.score}/100',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: scoreColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Skills
                                  if (user != null &&
                                      user.skillTags.isNotEmpty)
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: user.skillTags
                                          .take(5)
                                          .map(
                                            (tag) => Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary
                                                    .withAlpha(20),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                tag,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  if (user != null &&
                                      user.skillTags.isNotEmpty)
                                    const SizedBox(height: 10),

                                  // Raison IA
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.grey.shade900
                                          : Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.auto_awesome,
                                            size: 14,
                                            color: Colors.amber.shade600),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            match.reason,
                                            style: TextStyle(
                                              fontSize: 12,
                                              height: 1.4,
                                              color: isDark
                                                  ? Colors.grey.shade400
                                                  : Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Bouton Voir le profil
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: user != null
                                          ? () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute<void>(
                                                  builder: (_) =>
                                                      CandidateProfileScreen(
                                                    user: user,
                                                    matchScore: match.score,
                                                    matchReason: match.reason,
                                                  ),
                                                ),
                                              );
                                            }
                                          : null,
                                      icon: const Icon(Icons.person_search,
                                          size: 18),
                                      label: const Text('Voir le profil'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                        side: BorderSide(
                                            color: AppColors.primary
                                                .withAlpha(120)),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        childCount: _results!.matches.length,
                      ),
                    ),
                  )
                else if (!_matching && _results != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(Icons.search_off,
                              size: 56, color: Colors.grey.shade500),
                          const SizedBox(height: 12),
                          Text(
                            'Aucun candidat trouvé',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Aucun utilisateur ne correspond à cette spécialité.\nEssayez de modifier l\'offre.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
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
