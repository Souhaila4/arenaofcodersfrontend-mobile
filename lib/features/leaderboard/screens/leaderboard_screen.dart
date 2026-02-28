import 'package:flutter/material.dart';
// Replace these with your actual project imports
import 'package:arena/core/models/auth_models.dart';
import 'package:arena/core/services/api_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String _selectedFilter = 'All';
  // Map display label -> Prisma enum value returned by backend
  final Map<String, String?> _filterMap = {
    'All': null,
    'Frontend': 'FRONTEND',
    'Backend': 'BACKEND',
    'Fullstack': 'FULLSTACK',
    'Mobile': 'MOBILE',
    'Data': 'DATA',
    'BI': 'BI',
    'Cybersecurity': 'CYBERSECURITY',
    'Design': 'DESIGN',
    'DevOps': 'DEVOPS',
  };

  late Future<List<AuthUser>> _leaderboardFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _leaderboardFuture = _fetchLeaderboard();
  }

  Future<List<AuthUser>> _fetchLeaderboard() async {
    try {
      final res = await _apiService.getGlobalLeaderboard(limit: 100);
      final List<dynamic> list = res['leaderboard'] ?? [];
      var parsed = list.map((e) => AuthUser.fromJson(e as Map<String, dynamic>)).toList();

      final enumValue = _filterMap[_selectedFilter];
      if (enumValue != null) {
        parsed = parsed.where((u) => u.mainSpecialty == enumValue).toList();
      }
      return parsed;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F141C) : Colors.grey.shade50,
      body: Stack(
        children: [
          if (isDark)
            Positioned(
              top: -100,
              left: -50,
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height * 0.4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [const Color(0xFF00C2FF).withOpacity(0.1), Colors.transparent],
                  ),
                ),
              ),
            ),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Column(
                      children: [
                        Text(
                          'GLOBAL RANKING',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Leaderboard',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 44,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filterMap.keys.length,
                      itemBuilder: (context, index) {
                        final label = _filterMap.keys.elementAt(index);
                        final isSelected = _selectedFilter == label;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _selectedFilter = label;
                              _loadData();
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              decoration: BoxDecoration(
                                color: isSelected ? primaryColor : (isDark ? const Color(0xFF1E293B) : Colors.white),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: isSelected ? primaryColor : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: isSelected ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: FutureBuilder<List<AuthUser>>(
                    future: _leaderboardFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: Padding(padding: EdgeInsets.only(top: 100), child: CircularProgressIndicator()));
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 80),
                            child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)),
                          ),
                        );
                      }

                      final users = snapshot.data ?? [];
                      if (users.isEmpty) return Center(child: Padding(padding: const EdgeInsets.only(top: 100), child: Text(_selectedFilter == 'All' ? 'No Players Found' : 'No players for $_selectedFilter')));

                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 50, bottom: 20, left: 10, right: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Rank 2 - Silver
                                if (users.length > 1)
                                  _buildPodiumSpot(context, users[1], 2, 105, isDark,
                                      const Color(0xFFC0C0C0), [const Color(0xFF71797E), const Color(0xFFE5E4E2)]),
                                const SizedBox(width: 8),

                                // Rank 1 - Gold
                                if (users.isNotEmpty)
                                  _buildPodiumSpot(context, users[0], 1, 150, isDark,
                                      const Color(0xFFFFD700), [const Color(0xFF996515), const Color(0xFFFFD700), const Color(0xFFFEE101)]),
                                const SizedBox(width: 8),

                                // Rank 3 - Bronze
                                if (users.length > 2)
                                  _buildPodiumSpot(context, users[2], 3, 80, isDark,
                                      const Color(0xFFCD7F32), [const Color(0xFF804A00), const Color(0xFFCD7F32)]),
                              ],
                            ),
                          ),

                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: users.length > 3 ? users.length - 3 : 0,
                            itemBuilder: (context, index) {
                              final rank = index + 4;
                              return _buildRankListItem(rank, users[rank - 1], isDark, primaryColor);
                            },
                          ),
                          const SizedBox(height: 100),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumSpot(BuildContext context, AuthUser user, int rank, double blockHeight, bool isDark, Color metalColor, List<Color> gradient) {
    final double blockWidth = (MediaQuery.of(context).size.width - 70) / 3;
    final bool isFirst = rank == 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: metalColor.withOpacity(0.5), width: 2),
              ),
              child: CircleAvatar(
                radius: isFirst ? 42 : 34,
                backgroundImage: NetworkImage(user.avatarUrl ?? "https://ui-avatars.com/api/?name=${user.firstName}"),
              ),
            ),
            // THE CROWN (Floating above head)
            Positioned(
              top: isFirst ? -28 : -20,
              child: Icon(
                Icons.workspace_premium, // Modern Crown-like icon
                color: metalColor,
                size: isFirst ? 34 : 24,
                shadows: [Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)],
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: metalColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: isDark ? const Color(0xFF0F141C) : Colors.white, width: 2),
                ),
                child: Text('$rank', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          user.firstName.toLowerCase(),
          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87, fontSize: isFirst ? 16 : 14),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isFirst ? const Color(0xFFB4F03B) : (isDark ? Colors.white10 : Colors.black12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${user.totalWins} Wins',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isFirst ? Colors.black : (isDark ? Colors.white : Colors.black)),
          ),
        ),
        const SizedBox(height: 12),
        // REDESIGNED 3D BLOCK
        Container(
          width: blockWidth,
          height: blockHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: gradient),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(color: metalColor.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 4)),
              // Top shine for 3D look
              BoxShadow(color: Colors.white.withOpacity(0.2), blurRadius: 0, offset: const Offset(0, 2)),
            ],
          ),
          child: Center(
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: Colors.white.withOpacity(0.4), // Modern translucent white
                letterSpacing: -2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRankListItem(int rank, AuthUser user, bool isDark, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          SizedBox(width: 30, child: Text('$rank', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage(user.avatarUrl ?? "https://ui-avatars.com/api/?name=${user.firstName}"),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${user.firstName} ${user.lastName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(user.mainSpecialty ?? 'Specialist', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Text('${user.totalWins} Wins', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 13)),
        ],
      ),
    );
  }
}