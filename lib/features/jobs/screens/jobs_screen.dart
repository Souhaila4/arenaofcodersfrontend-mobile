import 'package:flutter/material.dart';
import 'package:arena/core/theme/app_theme.dart';
import 'package:arena/core/services/api_service.dart';
import 'package:arena/core/services/storage_service.dart';
import 'package:arena/features/jobs/models/job_posting.dart';
import 'package:arena/features/jobs/screens/create_job_screen.dart';
import 'package:arena/features/jobs/screens/job_detail_screen.dart';
import 'package:arena/features/jobs/screens/job_matches_screen.dart';

/// Écran principal des offres d'emploi.
/// - COMPANY : voit ses offres + bouton publier + bouton lancer le matching IA
/// - USER : voit les offres publiées par les entreprises
class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  List<JobPosting> _jobs = [];
  bool _loading = true;
  String? _error;
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
    _init();
  }

  Future<void> _init() async {
    final user = await StorageService().getUser();
    _userRole = user?.role;
    await _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService().getJobs();
      if (mounted) {
        setState(() {
          _jobs = data.map((j) => JobPosting.fromJson(j)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  bool get _isCompany => _userRole == 'COMPANY';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('OFFRES D\'EMPLOI'),
        actions: [
          if (_isCompany)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Publier une offre',
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(
                    builder: (_) => const CreateJobScreen(),
                  ),
                );
                if (created == true) _loadJobs();
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off,
                          size: 48, color: Colors.grey.shade500),
                      const SizedBox(height: 12),
                      Text(
                        'Impossible de charger les offres',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _loadJobs,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Réessayer'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                )
              : _jobs.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadJobs,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                        itemCount: _jobs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final job = _jobs[index];
                          return _buildJobCard(job, isDark);
                        },
                      ),
                    ),
      // FAB pour les entreprises
      floatingActionButton: _isCompany
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(
                    builder: (_) => const CreateJobScreen(),
                  ),
                );
                if (created == true) _loadJobs();
              },
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Nouvelle offre',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.work_off_outlined,
                size: 64, color: Colors.grey.shade500),
            const SizedBox(height: 16),
            Text(
              'Aucune offre pour l\'instant',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isCompany
                  ? 'Publiez votre première offre pour trouver les meilleurs talents avec l\'IA !'
                  : 'Les entreprises n\'ont pas encore publié d\'offres.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
            if (_isCompany) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () async {
                  final created = await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(
                      builder: (_) => const CreateJobScreen(),
                    ),
                  );
                  if (created == true) _loadJobs();
                },
                icon: const Icon(Icons.add),
                label: const Text('Publier une offre'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(JobPosting job, bool isDark) {
    final specialtyIcon =
        _specialtyIcons[job.targetSpecialty] ?? Icons.code;

    return Material(
      color: isDark ? AppColors.surfaceDark : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (_isCompany) {
            // Les entreprises vont directement voir les résultats de matching
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => JobMatchesScreen(
                  jobId: job.id,
                  jobTitle: job.title,
                ),
              ),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => JobDetailScreen(job: job),
              ),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withAlpha(10) : Colors.grey.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Icône spécialité
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(specialtyIcon,
                        size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          job.companyName,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Badge spécialité
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      job.targetSpecialty,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              if (job.location != null && job.location!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      job.location!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Text(
                job.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              if (_isCompany) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
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
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('Matching IA'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7C3AED),
                      side: BorderSide(
                          color: const Color(0xFF7C3AED).withAlpha(100)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
