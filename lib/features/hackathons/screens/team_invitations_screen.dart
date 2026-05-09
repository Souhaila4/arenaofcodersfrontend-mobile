import 'package:flutter/material.dart';
import 'package:arena/core/services/api_service.dart';
import 'package:arena/core/models/auth_models.dart';
import 'package:arena/core/theme/app_theme.dart';
import 'package:arena/features/hackathons/screens/hackathon_detail_screen.dart';

class TeamInvitationsScreen extends StatefulWidget {
  const TeamInvitationsScreen({super.key});

  @override
  State<TeamInvitationsScreen> createState() => _TeamInvitationsScreenState();
}

class _TeamInvitationsScreenState extends State<TeamInvitationsScreen> {
  final _api = ApiService();
  List<dynamic> _invitations = [];
  bool _loading = true;
  String? _error;

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
      final res = await _api.getMyInvitations();
      if (mounted) {
        setState(() {
          _invitations = (res['invitations'] as List<dynamic>?) ?? [];
          _loading = false;
        });
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
        _error = 'Erreur de connexion';
        _loading = false;
      });
    }
  }

  Future<void> _accept(String invitationId) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
      await _api.acceptInvitation(invitationId);
      if (mounted) Navigator.of(context).pop(); // dismiss loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Invitation acceptée ! Vous avez rejoint l\'équipe.'),
            backgroundColor: Colors.green,
          ),
        );
        _load();
      }
    } on ApiError catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        String msg = e.displayMessage;
        if (e.statusCode == 400 || e.statusCode == 409) {
          msg = "Désolé, mais le groupe est complet (6 membres maximum).";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'acceptation'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _decline(String invitationId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Refuser l\'invitation ?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Êtes-vous sûr de vouloir refuser cette invitation ?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Refuser', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _api.declineInvitation(invitationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation refusée'), backgroundColor: Colors.orange),
        );
        _load();
      }
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.displayMessage), backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur'), backgroundColor: Colors.red),
        );
      }
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
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
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
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.arrow_back, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.group_add, color: AppColors.primary, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Invitations d\'équipe',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                                const SizedBox(height: 16),
                                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                                const SizedBox(height: 8),
                                TextButton(onPressed: _load, child: const Text('Réessayer')),
                              ],
                            ),
                          )
                        : _invitations.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.mail_outline, size: 72, color: Colors.grey.shade600),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Aucune invitation en attente',
                                      style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Les invitations de vos équipes apparaîtront ici',
                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _load,
                                color: AppColors.primary,
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  itemCount: _invitations.length,
                                  itemBuilder: (context, index) {
                                    final inv = _invitations[index] as Map<String, dynamic>;
                                    return _InvitationCard(
                                      invitation: inv,
                                      isDark: isDark,
                                      onAccept: () => _accept(inv['id'] as String),
                                      onDecline: () => _decline(inv['id'] as String),
                                      onViewHackathon: () {
                                        final equipe = inv['equipe'] as Map<String, dynamic>?;
                                        final comp = equipe?['competition'] as Map<String, dynamic>?;
                                        final compId = comp?['id'] as String?;
                                        if (compId != null && mounted) {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => HackathonDetailScreen(competitionId: compId),
                                            ),
                                          );
                                        }
                                      },
                                    );
                                  },
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

class _InvitationCard extends StatelessWidget {
  final Map<String, dynamic> invitation;
  final bool isDark;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onViewHackathon;

  const _InvitationCard({
    required this.invitation,
    required this.isDark,
    required this.onAccept,
    required this.onDecline,
    required this.onViewHackathon,
  });

  @override
  Widget build(BuildContext context) {
    final equipe = invitation['equipe'] as Map<String, dynamic>? ?? {};
    final competition = equipe['competition'] as Map<String, dynamic>? ?? {};
    final inviter = invitation['inviter'] as Map<String, dynamic>? ?? {};
    final members = equipe['members'] as List<dynamic>? ?? [];
    final memberCount = equipe['_count']?['members'] as int? ?? members.length;

    final teamName = equipe['name'] as String? ?? 'Équipe';
    final compTitle = competition['title'] as String? ?? 'Hackathon';
    final inviterName = '${inviter['firstName'] ?? ''} ${inviter['lastName'] ?? ''}'.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2332) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withAlpha(80)),
          boxShadow: isDark
              ? [BoxShadow(color: AppColors.primary.withAlpha(15), blurRadius: 12, spreadRadius: 2)]
              : [BoxShadow(color: Colors.grey.withAlpha(30), blurRadius: 8)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Team name + competition
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, Color(0xFF2563EB)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.groups, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
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
                      const SizedBox(height: 2),
                      Text(
                        compTitle,
                        style: TextStyle(fontSize: 13, color: AppColors.primary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Inviter info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Text(
                    'Invité par ',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                  Expanded(
                    child: Text(
                      inviterName.isNotEmpty ? inviterName : 'Un membre',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textLightPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Members preview
            Row(
              children: [
                Icon(Icons.people_outline, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Text(
                  '$memberCount membre${memberCount > 1 ? 's' : ''} dans l\'équipe',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              ],
            ),

            // Member avatars
            if (members.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: members.take(6).map((m) {
                  final user = m['user'] as Map<String, dynamic>? ?? {};
                  final name = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
                  return Chip(
                    avatar: const CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child: Icon(Icons.person, size: 14, color: Colors.white),
                    ),
                    label: Text(name, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: isDark ? const Color(0xFF232D3E) : Colors.grey.shade100,
                    side: BorderSide.none,
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: onDecline,
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Refuser', style: TextStyle(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade400,
                        side: BorderSide(color: Colors.red.shade400),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: onAccept,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Accepter', style: TextStyle(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
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
