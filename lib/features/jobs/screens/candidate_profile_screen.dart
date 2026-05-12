import 'package:flutter/material.dart';
import 'package:arena/core/theme/app_theme.dart';
import 'package:arena/core/models/auth_models.dart';
import 'package:arena/core/services/api_service.dart';

/// Écran de profil détaillé d'un candidat.
/// Accessible via le bouton "Voir le profil" dans les résultats du matching IA.
class CandidateProfileScreen extends StatelessWidget {
  final AuthUser user;
  final int matchScore;
  final String matchReason;

  const CandidateProfileScreen({
    super.key,
    required this.user,
    required this.matchScore,
    required this.matchReason,
  });

  Color _scoreColor(int score) {
    if (score >= 80) return const Color(0xFF22C55E);
    if (score >= 60) return const Color(0xFF3B82F6);
    if (score >= 40) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scoreColor = _scoreColor(matchScore);

    return Scaffold(
      appBar: AppBar(title: const Text('PROFIL CANDIDAT')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header : Avatar + Nom + Score ───
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [Colors.white, Colors.grey.shade50],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: scoreColor.withAlpha(80),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: scoreColor.withAlpha(30),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: AppColors.primary.withAlpha(30),
                    backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                        ? NetworkImage(
                            user.avatarUrl!.startsWith('http')
                                ? user.avatarUrl!
                                : (user.avatarUrl!.startsWith('/')
                                    ? '${ApiService.baseUrl}${user.avatarUrl}'
                                    : '${ApiService.baseUrl}/${user.avatarUrl}'),
                          )
                        : null,
                    child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                        ? Text(
                            '${user.firstName.isNotEmpty ? user.firstName[0] : ''}${user.lastName.isNotEmpty ? user.lastName[0] : ''}',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${user.firstName} ${user.lastName}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  if (user.mainSpecialty != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        user.mainSpecialty!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Score de matching
                  if (matchScore > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: scoreColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: scoreColor.withAlpha(80)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 18, color: scoreColor),
                          const SizedBox(width: 8),
                          Text(
                            'Score IA : $matchScore / 100',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: scoreColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ─── Raison IA ───
            if (matchScore > 0) ...[
              _sectionTitle('Analyse IA', Icons.psychology),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? Colors.amber.withAlpha(40)
                        : Colors.amber.shade200,
                  ),
                ),
                child: Text(
                  matchReason,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ─── Compétences ───
            if (user.skillTags.isNotEmpty) ...[
              _sectionTitle('Compétences', Icons.code),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: user.skillTags
                    .map(
                      (tag) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.primary.withAlpha(60)),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
            ],

            // ─── Statistiques ───
            _sectionTitle('Statistiques', Icons.bar_chart),
            const SizedBox(height: 10),
            Row(
              children: [
                _statCard(
                  icon: Icons.emoji_events,
                  label: 'Victoires',
                  value: '${user.totalWins}',
                  color: const Color(0xFFFFD700),
                  isDark: isDark,
                ),
                const SizedBox(width: 10),
                _statCard(
                  icon: Icons.sports_esports,
                  label: 'Hackathons',
                  value: '${user.totalChallenges}',
                  color: AppColors.primary,
                  isDark: isDark,
                ),
                const SizedBox(width: 10),
                _statCard(
                  icon: Icons.account_balance_wallet,
                  label: 'Balance',
                  value: '${user.walletBalance.toStringAsFixed(0)} AC',
                  color: const Color(0xFF22C55E),
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ─── GitHub Repos ───
            if (user.githubRepos.isNotEmpty) ...[
              _sectionTitle('Repos GitHub', Icons.code_outlined),
              const SizedBox(height: 10),
              ...user.githubRepos.map(
                (repo) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withAlpha(40)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.folder_outlined,
                          size: 20, color: Colors.grey.shade500),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              repo.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            if (repo.language != null)
                              Text(
                                repo.language!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star,
                              size: 14, color: Colors.amber.shade600),
                          const SizedBox(width: 3),
                          Text(
                            '${repo.stars}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ─── Liens sociaux ───
            _sectionTitle('Liens', Icons.link),
            const SizedBox(height: 10),
            if (user.githubUrl != null && user.githubUrl!.isNotEmpty)
              _linkTile(Icons.code, 'GitHub', user.githubUrl!, isDark),
            if (user.linkedinUrl != null && user.linkedinUrl!.isNotEmpty)
              _linkTile(Icons.business, 'LinkedIn', user.linkedinUrl!, isDark),
            if ((user.githubUrl == null || user.githubUrl!.isEmpty) &&
                (user.linkedinUrl == null || user.linkedinUrl!.isEmpty))
              Text(
                'Aucun lien social renseigné',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linkTile(IconData icon, String label, String url, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withAlpha(40)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
