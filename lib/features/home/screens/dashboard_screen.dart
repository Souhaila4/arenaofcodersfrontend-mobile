import 'package:flutter/material.dart';
import 'package:arena/core/theme/app_theme.dart';
import 'package:arena/core/services/storage_service.dart';
import 'package:arena/core/services/api_service.dart';
import 'package:arena/core/models/competition_model.dart';
import 'package:arena/core/models/notification_model.dart';
import 'package:arena/features/hackathons/screens/hackathon_detail_screen.dart';

import 'package:arena/features/profile/screens/my_wins_screen.dart';
import 'package:arena/core/models/auth_models.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _storage = StorageService();
  final _api = ApiService();
  AuthUser? _currentUser;
  String _userName = '';
  String _initials = '';
  List<Competition> _forMeHackathons = [];
  List<AuthUser> _topCoders = [];
  List<dynamic> _invitations = [];
  int _currentUserRank = 0;
  int _unreadNotifications = 0;
  bool _loadingHackathons = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadHackathonsAndNotifications();
  }

  Future<void> _loadUser() async {
    try {
      final user = await _api.getMe();
      if (user != null && mounted) {
        setState(() {
          _currentUser = user;
          _userName = '${user.firstName} ${user.lastName}'.trim();
          _initials =
              '${user.firstName.isNotEmpty ? user.firstName[0] : ''}${user
                  .lastName.isNotEmpty ? user.lastName[0] : ''}'.toUpperCase();
        });
      }
    } catch (_) {
      final user = await _storage.getUser();
      if (user != null && mounted) {
        setState(() {
          _currentUser = user;
          _userName = '${user.firstName} ${user.lastName}'.trim();
          _initials =
              '${user.firstName.isNotEmpty ? user.firstName[0] : ''}${user
                  .lastName.isNotEmpty ? user.lastName[0] : ''}'.toUpperCase();
        });
      }
    }
  }

  Future<void> _loadHackathonsAndNotifications() async {
    setState(() => _loadingHackathons = true);
    try {
      // Parallel API calls — ~3x faster than sequential
      final results = await Future.wait([
        _api.getCompetitionsForMe(limit: 5),
        _api.getNotifications(limit: 1),
        _api.getGlobalLeaderboard(limit: 100),
        _api.getMyInvitations(),
      ]);
      final forMeRes = results[0] as CompetitionsResponse;
      final notifRes = results[1] as NotificationsResponse;
      final leaderResult = results[2] as Map<String, dynamic>;
      final invRes = results[3] as Map<String, dynamic>;

      List<dynamic> invitations = (invRes['invitations'] as List<dynamic>?) ?? [];

      // Filter: Only show invitations for non-full teams (max 6)
      // and ensure hackathon exists
      invitations = invitations.where((inv) {
        final equipe = inv['equipe'] as Map<String, dynamic>? ?? {};
        final competition = equipe['competition'] as Map<String, dynamic>? ?? {};
        final membersCount = equipe['_count']?['members'] as int? ?? 
                             (equipe['members'] as List<dynamic>?)?.length ?? 0;
        
        // Hide if team is already full or competition info is missing
        return membersCount < 6 && competition['id'] != null;
      }).toList();

      List<dynamic> leaderList = (leaderResult['leaderboard'] as List<dynamic>? ?? []);
      // Filter out non-users
      leaderList = leaderList.where((e) => e['role'] == 'USER').toList();
      
      final topCoders = leaderList.take(3).map((e) =>
          AuthUser.fromJson(e as Map<String, dynamic>)).toList();
          
      int myRank = 0;
      if (_currentUser != null && _currentUser!.role == 'USER') {
        if (_currentUser!.mainSpecialty != null && _currentUser!.mainSpecialty!.isNotEmpty) {
           final specialtyList = leaderList.where((e) => e['mainSpecialty'] == _currentUser!.mainSpecialty).toList();
           final idx = specialtyList.indexWhere((e) => e['id'] == _currentUser!.id);
           if (idx != -1) myRank = idx + 1;
        } else {
           final idx = leaderList.indexWhere((e) => e['id'] == _currentUser!.id);
           if (idx != -1) myRank = idx + 1;
        }
      }
      if (mounted) {
        setState(() {
          _invitations = invitations;
          _forMeHackathons = forMeRes.data;
          _unreadNotifications = notifRes.unreadCount;
          _topCoders = topCoders;
          _currentUserRank = myRank;
          _loadingHackathons = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingHackathons = false);
    }
  }

  Future<void> _handleLogout() async {
    await _api.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
          '/signin', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme
        .of(context)
        .brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient blobs (dark mode only)
          if (isDark) ...[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: MediaQuery
                    .of(context)
                    .size
                    .height * 0.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF1E3A5F).withAlpha(50),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -50,
              right: -80,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withAlpha(25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
          // Main scrollable content
          CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        // Avatar
                        _currentUser?.avatarUrl != null && _currentUser!.avatarUrl!.isNotEmpty
                            ? Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withAlpha(25), width: 2),
                                ),
                                child: ClipOval(
                                  child: Image.network(
                                    '${ApiService.baseUrl.replaceAll('/api', '')}${_currentUser!.avatarUrl}',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(colors: [Color(0xFF374151), Color(0xFF111827)]),
                                      ),
                                      child: Center(
                                        child: Text(
                                          _initials.isNotEmpty ? _initials : '?',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF374151), Color(0xFF111827)],
                                  ),
                                  border: Border.all(color: Colors.white.withAlpha(25), width: 2),
                                ),
                                child: Center(
                                  child: Text(
                                    _initials.isNotEmpty ? _initials : '?',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                                  ),
                                ),
                              ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back,',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _userName.isNotEmpty ? _userName : 'Coder',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Stack(
                          children: [
                            IconButton(
                              onPressed: () =>
                                  Navigator.of(context).pushNamed(
                                      '/notifications').then((_) =>
                                      _loadHackathonsAndNotifications()),
                              icon: Icon(
                                Icons.notifications_outlined,
                                color: isDark ? Colors.grey.shade300 : Colors
                                    .grey.shade600,
                              ),
                            ),
                            if (_unreadNotifications > 0)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentOrange,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark
                                          ? AppColors.backgroundDark
                                          : Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  constraints: const BoxConstraints(
                                      minWidth: 18, minHeight: 18),
                                  child: Text(
                                    _unreadNotifications > 99
                                        ? '99+'
                                        : '$_unreadNotifications',
                                    style: const TextStyle(fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        IconButton(
                          onPressed: _handleLogout,
                          tooltip: 'Sign Out',
                          icon: Icon(
                            Icons.logout,
                            color: isDark ? Colors.grey.shade300 : Colors.grey
                                .shade600,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Stats grid
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      // Global Rank
                      Expanded(child: _buildStatCard(
                        context,
                        icon: Icons.emoji_events_outlined,
                        iconColor: AppColors.primary,
                        value: _currentUserRank > 0
                            ? '#$_currentUserRank'
                            : '--',
                        label: (_currentUser?.mainSpecialty != null && _currentUser!.mainSpecialty!.isNotEmpty) ? '${_currentUser!.mainSpecialty} Rank' : 'Global Rank',
                        trend: _currentUserRank > 0
                            ? 'Top ${((_currentUserRank / 50) * 100).round()}%'
                            : null,
                        trendPositive: true,
                      )),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (_currentUser?.role == 'USER') {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const MyWinsScreen()),
                              );
                            }
                          },
                          child: _buildStatCard(
                            context,
                            icon: Icons.military_tech_outlined,
                            iconColor: AppColors.accentOrange,
                            value: '${_currentUser?.totalWins ?? 0}',
                            valueSuffix: ' wins',
                            label: 'Total Wins',
                            trend: '${_currentUser?.totalChallenges ?? 0} challenges',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // CTA Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _buildCtaCard(context, isDark),
                ),
              ),
              // Invitations Section
              if (_invitations.isNotEmpty)
                _buildInvitationsSection(context, isDark),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Hackathons for you',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator
                                .of(context)
                                .pushNamed('/hackathons')
                                .then((_) => _loadHackathonsAndNotifications()),
                        child: const Text(
                          'View All',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _loadingHackathons
                    ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator(
                      color: AppColors.primary)),
                )
                    : SizedBox(
                  height: 190,
                  child: _forMeHackathons.isEmpty
                      ? Center(
                    child: TextButton.icon(
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/hackathons'),
                      icon: const Icon(Icons.emoji_events_outlined,
                          color: AppColors.primary),
                      label: const Text('Browse all hackathons',
                          style: TextStyle(color: AppColors.primary,
                              fontWeight: FontWeight.w600)),
                    ),
                  )
                      : ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      for (final c in _forMeHackathons) ...[
                        _buildHackathonCard(context, c),
                        const SizedBox(width: 16),
                      ],
                    ],
                  ),
                ),
              ),
              // Top Coders
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Top Coders',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      _buildToggle(context, isDark),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  child: _topCoders.isEmpty
                      ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(
                          color: AppColors.primary),
                    ),
                  )
                      : Column(children: [
                    for (int i = 0; i < _topCoders.length; i++) ...[
                      _buildCoderItem(
                        context,
                        rank: i + 1,
                        name: '${_topCoders[i].firstName} ${_topCoders[i]
                            .lastName}'.trim(),
                        specialty: _topCoders[i].mainSpecialty ?? 'Coder',
                        totalWins: _topCoders[i].totalWins,
                        avatarUrl: _topCoders[i].avatarUrl,
                        rankColor: i == 0
                            ? AppColors.accentOrange
                            : i == 1
                            ? Colors.grey.shade400
                            : const Color(0xFFB45309),
                      ),
                      if (i < _topCoders.length - 1) const SizedBox(height: 10),
                    ],
                  ]),
                ),
              ),
              // Add a bit of bottom padding to scroll past the Floating Chat Fab
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvitationsSection(BuildContext context, bool isDark) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 28, 20, 12),
            child: Text(
              'Team Invitations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _invitations.length,
              itemBuilder: (context, index) {
                return _buildInvitationCard(context, _invitations[index], isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvitationCard(BuildContext context, dynamic invitation, bool isDark) {
    final equipe = invitation['equipe'] as Map<String, dynamic>? ?? {};
    final competition = equipe['competition'] as Map<String, dynamic>? ?? {};
    final inviter = invitation['inviter'] as Map<String, dynamic>? ?? {};
    final teamName = equipe['name'] as String? ?? 'Team';
    final compTitle = competition['title'] as String? ?? 'Hackathon';
    final inviterName = '${inviter['firstName'] ?? ''} ${inviter['lastName'] ?? ''}'.trim();

    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(80)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.groups, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teamName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      compTitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Invited by $inviterName',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => _declineInvitation(invitation['id'] as String),
                  style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
                  child: const Text('Decline', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _acceptInvitation(invitation['id'] as String),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text('Accept', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _acceptInvitation(String invitationId) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
      await _api.acceptInvitation(invitationId);
      if (mounted) Navigator.of(context).pop(); // dismiss loading
      
      // Update local state to remove the card immediately
      if (mounted) {
        setState(() {
          _invitations.removeWhere((inv) => inv['id'] == invitationId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Invitation accepted!'), backgroundColor: Colors.green),
        );
        _loadHackathonsAndNotifications(); // Refresh data
      }
    } on ApiError catch (e) {
      if (mounted) Navigator.of(context).pop();
      String msg = e.displayMessage;
      if (e.statusCode == 400 || e.statusCode == 409) {
        msg = "Désolé, mais le groupe est complet (6 membres maximum).";
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
        // Refresh to hide full team invitation
        _loadHackathonsAndNotifications();
      }
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _declineInvitation(String invitationId) async {
    try {
      await _api.declineInvitation(invitationId);
      if (mounted) {
        setState(() {
          _invitations.removeWhere((inv) => inv['id'] == invitationId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation declined'), backgroundColor: Colors.orange),
        );
      }
    } catch (_) {}
  }

  Widget _buildStatCard(BuildContext context, {

    required IconData icon,
    required Color iconColor,
    required String value,
    String? valueSuffix,
    required String label,
    String? trend,
    bool trendPositive = false,
  }) {
    final isDark = Theme
        .of(context)
        .brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withAlpha(25) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: iconColor, size: 28),
              if (trend != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      trend,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: trendPositive ? Colors.green : Colors.grey
                            .shade400,
                      ),
                    ),
                    if (trendPositive)
                      Icon(Icons.arrow_upward, size: 10, color: Colors.green),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.textLightPrimary,
                    fontFamily: 'Inter',
                  ),
                ),
                if (valueSuffix != null)
                  TextSpan(
                    text: valueSuffix,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey.shade500,
                      fontFamily: 'Inter',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCtaCard(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? null
            : const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
        ),
        color: isDark ? AppColors.surfaceDark : null,
        borderRadius: BorderRadius.circular(20),
        border: isDark
            ? Border.all(color: AppColors.primary.withAlpha(75))
            : null,
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: const Color(0xFF2563EB).withAlpha(60),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          if (isDark)
            BoxShadow(
              color: AppColors.primary.withAlpha(50),
              blurRadius: 20,
            ),
        ],
      ),
      child: Stack(
        children: [
          // Glow blob
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withAlpha(50),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ready to compete?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Join the latest Hackathon and prove your algorithmic mastery.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade300 : const Color(
                        0xFFBFDBFE),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/hackathons'),
                    icon: const Icon(Icons.code, size: 20),
                    label: const Text(
                      'Browse Hackathons',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.primary : Colors
                          .white,
                      foregroundColor: isDark ? Colors.white : const Color(
                          0xFF1E3A8A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHackathonCard(BuildContext context, Competition c) {
    final isDark = Theme
        .of(context)
        .brightness == Brightness.dark;
    final diffColor = c.difficulty.toUpperCase() == 'HARD'
        ? AppColors.accentOrange
        : c.difficulty.toUpperCase() == 'EASY'
        ? Colors.green
        : AppColors.primary;
    return GestureDetector(
      onTap: () =>
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => HackathonDetailScreen(competitionId: c.id),
            ),
          ).then((_) => _loadHackathonsAndNotifications()),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withAlpha(13) : Colors.grey.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: diffColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    c.difficultyDisplay,
                    style: TextStyle(fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: diffColor),
                  ),
                ),
                if (c.specialty != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      c.specialty!,
                      style: const TextStyle(fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              c.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textLightPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              c.statusDisplay,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const Spacer(),
            if (c.rewardPool > 0)
              Text(
                '\$${c.rewardPool.toStringAsFixed(0)} prize',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentOrange,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(13) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withAlpha(25) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 4,
                ),
              ],
            ),
            child: const Text(
              'Global',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoderItem(BuildContext context, {
    required int rank,
    required String name,
    required String specialty,
    required int totalWins,
    String? avatarUrl,
    required Color rankColor,
  }) {
    final isDark = Theme
        .of(context)
        .brightness == Brightness.dark;
    bool isFirst = rank == 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark.withAlpha(153) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isFirst && isDark ? [
          BoxShadow(
            color: AppColors.accentOrange.withAlpha(25),
            blurRadius: 15,
            spreadRadius: 1,
          )
        ] : null,
        border: Border.all(
          color: isFirst
              ? AppColors.accentOrange.withAlpha(128)
              : (isDark ? Colors.white.withAlpha(15) : Colors.grey.shade200),
          width: isFirst ? 1.5 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Rank Number with Mono styling
              Container(
                width: 50,
                decoration: BoxDecoration(
                  color: isFirst
                      ? AppColors.accentOrange.withAlpha(25)
                      : Colors.transparent,
                ),
                child: Center(
                  child: Text(
                    rank.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: rankColor,
                      fontSize: 16,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ),

              VerticalDivider(
                color: isDark ? Colors.white.withAlpha(10) : Colors.grey
                    .shade100,
                width: 1,
                thickness: 1,
                indent: 12,
                endIndent: 12,
              ),

              const SizedBox(width: 12),

              // Avatar with Crown for #1
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isFirst ? const LinearGradient(
                          colors: [AppColors.accentOrange, Colors.yellow],
                        ) : null,
                        color: !isFirst ? (isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade300) : null,
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: isDark
                            ? AppColors.backgroundDark
                            : Colors.white,
                        backgroundImage: avatarUrl != null &&
                            avatarUrl.isNotEmpty
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl == null || avatarUrl.isEmpty
                            ? Icon(Icons.person_outline,
                            color: isDark ? Colors.grey.shade600 : Colors.grey
                                .shade400, size: 20)
                            : null,
                      ),
                    ),
                    if (isFirst)
                      const Positioned(
                        top: -8,
                        left: 0,
                        right: 0,
                        child: Center(child: Icon(
                            Icons.workspace_premium, color: AppColors
                            .accentOrange, size: 16)),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Name and Tech Specialty
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      specialty.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary.withAlpha(204),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Wins display
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      totalWins.toString(),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      'WINS',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}