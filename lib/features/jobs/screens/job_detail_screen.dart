import 'package:flutter/material.dart';
import 'package:arena/core/theme/app_theme.dart';
import 'package:arena/core/services/storage_service.dart';
import 'package:arena/features/jobs/models/job_posting.dart';
import 'package:arena/features/jobs/screens/test_interview_screen.dart';
import 'package:arena/features/jobs/screens/job_matches_screen.dart';

/// Détail d'une offre d'emploi.
/// - COMPANY : voit le détail + bouton "Matching IA"
/// - USER    : voit le détail + bouton "Test interview"
class JobDetailScreen extends StatefulWidget {
  final JobPosting job;

  const JobDetailScreen({super.key, required this.job});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  String? _userRole;

  static const _specialtyIcons = {
    'FRONTEND': Icons.web,
    'BACKEND': Icons.dns,
    'FULLSTACK': Icons.layers,
    'MOBILE': Icons.phone_android,
    'DATA': Icons.bar_chart,
    'BI': Icons.analytics,
    'CYBERSECURITY': Icons.shield,
    'DESIGN': Icons.palette,
    'DEVOPS': Icons.cloud,
  };

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final user = await StorageService().getUser();
    if (mounted) setState(() => _userRole = user?.role);
  }

  bool get _isCompany => _userRole == 'COMPANY';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final job = widget.job;
    final specialtyIcon =
        _specialtyIcons[job.targetSpecialty] ?? Icons.code;

    return Scaffold(
      appBar: AppBar(title: Text(job.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header ───
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E40AF), Color(0xFF7C3AED)],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(specialtyIcon,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              job.companyName,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                job.targetSpecialty,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (job.location != null && job.location!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 14, color: Colors.white60),
                        const SizedBox(width: 4),
                        Text(
                          job.location!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ─── Description ───
            const Text(
              'Description du poste',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF151B26)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withAlpha(13)
                      : Colors.grey.shade300,
                ),
              ),
              child: Text(
                job.description,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  color: isDark
                      ? Colors.grey.shade300
                      : Colors.grey.shade800,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ─── Date de publication ───
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Text(
                  'Publiée le ${job.createdAt.day}/${job.createdAt.month}/${job.createdAt.year}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ─── COMPANY: Matching IA button ───
            if (_isCompany) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => JobMatchesScreen(
                          jobId: job.id,
                          jobTitle: job.title,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Matching IA'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF7C3AED),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Lancez le matching IA pour trouver les candidats qui correspondent le mieux à cette offre.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  height: 1.4,
                ),
              ),
            ],

            // ─── USER: Test interview button ───
            if (!_isCompany && _userRole != null) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => TestInterviewScreen(job: job),
                      ),
                    );
                  },
                  icon: const Icon(Icons.record_voice_over_outlined),
                  label: const Text('Test interview'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Simulez un entretien avec un recruteur IA adapté à cette offre. '
                'Audio optionnel — tapez ou utilisez le micro.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
