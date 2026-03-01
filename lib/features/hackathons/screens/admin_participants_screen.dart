import 'package:flutter/material.dart';
import 'package:arena/core/services/api_service.dart';
import 'package:arena/core/theme/app_theme.dart';
import 'package:arena/core/models/auth_models.dart';
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
  List<dynamic> _participants = [];
  int _total = 0;

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
      final result = await _api.getCompetitionParticipants(widget.competitionId);
      if (mounted) {
        setState(() {
          _participants = result['participants'] as List<dynamic>? ?? [];
          _total = result['totalParticipants'] as int? ?? _participants.length;
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
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Total count
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text(
                      '$_total participant${_total == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh, color: AppColors.primary, size: 22),
                    ),
                  ],
                ),
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
              else if (_participants.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey.shade600),
                        const SizedBox(height: 16),
                        Text('Aucun participant pour le moment',
                            style: TextStyle(color: Colors.grey.shade400)),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _participants.length,
                    itemBuilder: (context, index) {
                      final p = _participants[index] as Map<String, dynamic>;
                      return _ParticipantCard(participant: p, isDark: isDark);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParticipantCard extends StatelessWidget {
  final Map<String, dynamic> participant;
  final bool isDark;

  const _ParticipantCard({required this.participant, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final user = participant['user'] as Map<String, dynamic>? ?? {};
    final status = participant['status'] as String? ?? 'JOINED';
    final githubUrl = participant['githubUrl'] as String?;
    final antiCheatScore = participant['antiCheatScore'];
    final firstName = user['firstName'] ?? '';
    final lastName = user['lastName'] ?? '';
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
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == 'DISQUALIFIED'
              ? Colors.red.withAlpha(60)
              : status == 'SUBMITTED'
                  ? Colors.green.withAlpha(60)
                  : (isDark ? AppColors.primary.withAlpha(30) : Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info row
          Row(
            children: [
              CircleAvatar(
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
                      '$firstName $lastName',
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
              // Status badge
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

          // Anti-cheat score
          if (antiCheatScore != null) ...[
            const SizedBox(height: 8),
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
