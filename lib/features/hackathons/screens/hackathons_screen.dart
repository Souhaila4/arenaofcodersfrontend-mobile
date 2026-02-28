import 'package:flutter/material.dart';
import 'package:arena/core/models/competition_model.dart';
import 'package:arena/core/services/api_service.dart';
import 'package:arena/core/theme/app_theme.dart';
import 'package:arena/features/hackathons/screens/hackathon_detail_screen.dart';
import 'create_competition_screen.dart';
import 'package:arena/core/models/auth_models.dart';

String _formatDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[d.month - 1]} ${d.day}';
}

class HackathonsScreen extends StatefulWidget {
  const HackathonsScreen({super.key});

  @override
  State<HackathonsScreen> createState() => _HackathonsScreenState();
}

class _HackathonsScreenState extends State<HackathonsScreen> {
  final _api = ApiService();
  List<Competition> _forMe = [];
  List<Competition> _all = [];
  int _unreadNotifications = 0;
  bool _loading = true;
  String? _error;
  bool _showAll = false;
  AuthUser? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _load();
  }

  Future<void> _loadUser() async {
    try {
      final u = await _api.getMe();
      if (mounted) setState(() => _user = u);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final forMeRes = await _api.getCompetitionsForMe(limit: 20);
      final allRes = await _api.getCompetitions(limit: 20);
      final notifRes = await _api.getNotifications(limit: 1);
      if (mounted) {
        setState(() {
          _forMe = forMeRes.data;
          _all = allRes.data;
          _unreadNotifications = notifRes.unreadCount;
          _loading = false;
        });
      }
    } on ApiError catch (e) {
      if (e.statusCode == 401 && mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/signin', (route) => false);
        return;
      }
      if (mounted) setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = 'Connection error');
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
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0B1121), Color(0xFF0F141C), Color(0xFF0B0E14)],
                )
              : null,
          color: isDark ? null : AppColors.backgroundLight,
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      const Text(
                        'Hackathons',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pushNamed('/notifications').then((_) => _load()),
                        icon: Stack(
                          children: [
                            Icon(
                              Icons.notifications_outlined,
                              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                              size: 26,
                            ),
                            if (_unreadNotifications > 0)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.accentOrange,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                  child: Text(
                                    _unreadNotifications > 99 ? '99+' : '$_unreadNotifications',
                                    style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_user?.role == 'ADMIN')
                        IconButton(
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const CreateCompetitionScreen()),
                            );
                            _load();
                          },
                          icon: Icon(
                            Icons.add_circle_outline,
                            color: AppColors.primary,
                            size: 26,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (_error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withAlpha(80)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 22),
                          const SizedBox(width: 12),
                          Expanded(child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
                          TextButton(
                            onPressed: _load,
                            child: const Text('Retry', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_loading)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      children: [
                        Text(
                          _showAll ? 'All hackathons' : 'For you',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _showAll = !_showAll),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(35),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.primary.withAlpha(80)),
                            ),
                            child: Text(
                              _showAll ? 'Show for you' : 'Show all',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final list = _showAll ? _all : _forMe;
                      if (list.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey.shade600),
                                const SizedBox(height: 16),
                                Text(
                                  _showAll ? 'No hackathons yet' : 'No hackathons for your specialty yet',
                                  style: TextStyle(fontSize: 15, color: Colors.grey.shade400),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      if (index >= list.length) return const SizedBox.shrink();
                      final c = list[index];
                      return _CompetitionCard(
                        competition: c,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => HackathonDetailScreen(competitionId: c.id),
                            ),
                          );
                          _load();
                        },
                      );
                    },
                    childCount: (_showAll ? _all : _forMe).isEmpty ? 1 : (_showAll ? _all.length : _forMe.length),
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

class _CompetitionCard extends StatelessWidget {
  final Competition competition;
  final VoidCallback onTap;

  const _CompetitionCard({required this.competition, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final diffColor = competition.difficulty.toUpperCase() == 'HARD'
        ? AppColors.accentOrange
        : competition.difficulty.toUpperCase() == 'EASY'
            ? Colors.green
            : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.primary.withAlpha(50) : Colors.grey.shade200,
              ),
              boxShadow: [
                if (!isDark) BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 20, offset: const Offset(0, 6)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: diffColor.withAlpha(35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        competition.difficultyDisplay,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: diffColor),
                      ),
                    ),
                    if (competition.specialty != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          competition.specialty!,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      competition.statusDisplay,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  competition.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.textLightPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  competition.description,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade400, height: 1.35),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(
                      '${_formatDate(competition.startDate)} – ${_formatDate(competition.endDate)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                    const Spacer(),
                    if (competition.rewardPool > 0)
                      Text(
                        '\$${competition.rewardPool.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentOrange,
                        ),
                      ),
                    if (competition.participantsCount > 0) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.people_outline, size: 16, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        '${competition.participantsCount}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
