import 'package:flutter/material.dart';
import 'package:arena/core/theme/app_theme.dart';
import 'package:arena/features/jobs/models/job_posting.dart';

/// Détail d'une offre d'emploi (vue USER).
class JobDetailScreen extends StatelessWidget {
  final JobPosting job;

  const JobDetailScreen({super.key, required this.job});

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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          ],
        ),
      ),
    );
  }
}
