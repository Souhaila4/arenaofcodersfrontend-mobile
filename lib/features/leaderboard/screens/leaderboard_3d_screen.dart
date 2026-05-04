import 'dart:math';
import 'package:flutter/material.dart';
import 'package:arena/core/models/leaderboard_entry.dart';
import 'package:arena/core/services/leaderboard_live_service.dart';
import 'package:arena/core/services/api_service.dart';
import 'package:arena/core/services/storage_service.dart';
import 'package:arena/core/models/auth_models.dart';

class Leaderboard3DScreen extends StatefulWidget {
  const Leaderboard3DScreen({super.key});
  @override
  State<Leaderboard3DScreen> createState() => _Leaderboard3DScreenState();
}

class _Leaderboard3DScreenState extends State<Leaderboard3DScreen>
    with TickerProviderStateMixin {
  final LeaderboardLiveService _liveService = LeaderboardLiveService();
  final StorageService _storage = StorageService();
  List<LeaderboardEntry> _entries = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  AuthUser? _currentUser;
  late AnimationController _pulseController;
  late AnimationController _crownController;
  final Map<String, AnimationController> _cardControllers = {};

  final Map<String, String?> _filterMap = {
    'All': null, 'Frontend': 'FRONTEND', 'Backend': 'BACKEND',
    'Fullstack': 'FULLSTACK', 'Mobile': 'MOBILE', 'Data': 'DATA',
    'BI': 'BI', 'Cybersecurity': 'CYBERSECURITY', 'Design': 'DESIGN',
    'DevOps': 'DEVOPS',
  };

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _crownController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3000),
    )..repeat();
    _loadUser();
    _liveService.updates.listen((update) {
      if (!mounted) return;
      final filtered = _applyFilter(update.leaderboard);
      // Trigger animations for moved entries
      for (final entry in filtered) {
        if (entry.movedUp || entry.movedDown) {
          _triggerCardAnimation(entry.id);
        }
      }
      setState(() { _entries = filtered; _isLoading = false; });
    });
  }

  Future<void> _loadUser() async {
    _currentUser = await _storage.getUser();
    if (_currentUser?.role == 'USER' && _currentUser?.mainSpecialty != null) {
      for (var e in _filterMap.entries) {
        if (e.value == _currentUser!.mainSpecialty) {
          _selectedFilter = e.key; break;
        }
      }
    }
    if (mounted) setState(() {});
  }

  List<LeaderboardEntry> _applyFilter(List<LeaderboardEntry> list) {
    final enumVal = _filterMap[_selectedFilter];
    if (enumVal == null) return list;
    return list.where((e) => e.mainSpecialty == enumVal).toList();
  }

  void _triggerCardAnimation(String id) {
    _cardControllers[id]?.dispose();
    final c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800),
    );
    _cardControllers[id] = c;
    c.forward().then((_) { c.dispose(); _cardControllers.remove(id); });
  }

  @override
  void dispose() {
    _liveService.dispose();
    _pulseController.dispose();
    _crownController.dispose();
    for (final c in _cardControllers.values) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primary = Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F141C) : Colors.grey.shade50,
      body: Stack(
        children: [
          // Animated background glow
          if (isDark) _buildBackgroundGlow(context),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Header
                SliverToBoxAdapter(child: _buildHeader(primary)),
                // Filter chips
                if (_currentUser?.role != 'USER')
                  SliverToBoxAdapter(child: _buildFilters(isDark, primary)),
                // Live indicator
                SliverToBoxAdapter(child: _buildLiveIndicator(isDark)),
                // Content
                SliverToBoxAdapter(child: _buildContent(isDark, primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundGlow(BuildContext context) {
    return Positioned(
      top: -100,
      left: -50,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (_, child) => Opacity(
          opacity: 0.6 + _pulseController.value * 0.4,
          child: Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height * 0.4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                const Color(0xFF00C2FF).withAlpha((25 + _pulseController.value * 15).toInt()),
                Colors.transparent,
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color primary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: primary.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(
                color: const Color(0xFF22C55E), shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: const Color(0xFF22C55E).withAlpha(128), blurRadius: 6)],
              )),
              const SizedBox(width: 6),
              Text('LIVE RANKING', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                letterSpacing: 2, color: primary,
              )),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        const Text('Leaderboard', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Updates in real-time', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ]),
    );
  }

  Widget _buildFilters(bool isDark, Color primary) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filterMap.keys.length,
        itemBuilder: (_, i) {
          final label = _filterMap.keys.elementAt(i);
          final sel = _selectedFilter == label;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => setState(() {
                _selectedFilter = label;
                _entries = _applyFilter(_entries);
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: sel ? primary : (isDark ? const Color(0xFF1E293B) : Colors.white),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: sel ? primary : (isDark ? Colors.grey.shade800 : Colors.grey.shade300)),
                ),
                alignment: Alignment.center,
                child: Text(label, style: TextStyle(
                  fontSize: 13, fontWeight: sel ? FontWeight.bold : FontWeight.w600,
                  color: sel ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                )),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLiveIndicator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (_, child) => Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.lerp(const Color(0xFF22C55E), const Color(0xFF16A34A), _pulseController.value),
              boxShadow: [BoxShadow(
                color: const Color(0xFF22C55E).withAlpha((80 + _pulseController.value * 80).toInt()),
                blurRadius: 8 + _pulseController.value * 4,
              )],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('${_entries.length} players online',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _buildContent(bool isDark, Color primary) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 100),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Center(child: Text(
          _selectedFilter == 'All' ? 'No Players Found' : 'No players for $_selectedFilter',
        )),
      );
    }

    return Column(children: [
      // 3D Podium (Top 3)
      Padding(
        padding: const EdgeInsets.only(top: 30, bottom: 20, left: 10, right: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (_entries.length > 1) _build3DPodiumSpot(context, _entries[1], 2, 105, isDark,
                const Color(0xFFC0C0C0), [const Color(0xFF71797E), const Color(0xFFE5E4E2)]),
            const SizedBox(width: 8),
            if (_entries.isNotEmpty) _build3DPodiumSpot(context, _entries[0], 1, 150, isDark,
                const Color(0xFFFFD700), [const Color(0xFF996515), const Color(0xFFFFD700), const Color(0xFFFEE101)]),
            const SizedBox(width: 8),
            if (_entries.length > 2) _build3DPodiumSpot(context, _entries[2], 3, 80, isDark,
                const Color(0xFFCD7F32), [const Color(0xFF804A00), const Color(0xFFCD7F32)]),
          ],
        ),
      ),
      // Rank list (4+)
      ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _entries.length > 3 ? _entries.length - 3 : 0,
        itemBuilder: (_, i) {
          final rank = i + 4;
          return _buildAnimatedRankItem(rank, _entries[rank - 1], isDark, primary);
        },
      ),
      const SizedBox(height: 100),
    ]);
  }

  // ── 3D Podium Spot ──
  Widget _build3DPodiumSpot(BuildContext ctx, LeaderboardEntry entry, int rank,
      double blockHeight, bool isDark, Color metalColor, List<Color> gradient) {
    final blockWidth = (MediaQuery.of(ctx).size.width - 70) / 3;
    final isFirst = rank == 1;
    final moved = entry.movedUp || entry.movedDown;

    // 3D tilt animation for movement
    final controller = _cardControllers[entry.id];
    final animation = controller != null
        ? Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
            parent: controller, curve: Curves.elasticOut))
        : const AlwaysStoppedAnimation<double>(0.0);

    return AnimatedBuilder(
      animation: animation,
      builder: (_, child) {
        final tilt = moved ? sin(animation.value * pi * 2) * 0.05 : 0.0;
        final lift = moved ? sin(animation.value * pi) * -10 : 0.0;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(tilt)
            ..translate(0.0, lift, 0.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Movement badge
            if (moved) _buildMovementBadge(entry),
            // Avatar
            Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: metalColor.withAlpha(128), width: 2),
                  boxShadow: moved ? [BoxShadow(
                    color: (entry.movedUp ? const Color(0xFF22C55E) : Colors.red).withAlpha(80),
                    blurRadius: 16,
                  )] : null,
                ),
                child: CircleAvatar(
                  radius: isFirst ? 42 : 34,
                  backgroundImage: NetworkImage(_avatarUrl(entry)),
                ),
              ),
              // Crown
              Positioned(
                top: isFirst ? -28 : -20,
                child: AnimatedBuilder(
                  animation: _crownController,
                  builder: (_, child) => Transform.rotate(
                    angle: sin(_crownController.value * pi * 2) * 0.1,
                    child: Icon(Icons.workspace_premium, color: metalColor,
                      size: isFirst ? 34 : 24,
                      shadows: [Shadow(color: Colors.black.withAlpha(77), blurRadius: 10)],
                    ),
                  ),
                ),
              ),
              Positioned(bottom: 0, right: 0, child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: metalColor, shape: BoxShape.circle,
                  border: Border.all(color: isDark ? const Color(0xFF0F141C) : Colors.white, width: 2),
                ),
                child: Text('$rank', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              )),
            ]),
            const SizedBox(height: 12),
            Text(entry.firstName.toLowerCase(),
              style: TextStyle(fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
                fontSize: isFirst ? 16 : 14)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isFirst ? const Color(0xFFB4F03B) : (isDark ? Colors.white10 : Colors.black12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${entry.totalWins} Wins',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                  color: isFirst ? Colors.black : (isDark ? Colors.white : Colors.black))),
            ),
            const SizedBox(height: 12),
            // 3D Block with perspective transform
            Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.002)
                ..rotateX(-0.15),
              child: Container(
                width: blockWidth, height: blockHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: gradient),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(color: metalColor.withAlpha(51), blurRadius: 15, offset: const Offset(0, 4)),
                    BoxShadow(color: Colors.white.withAlpha(51), blurRadius: 0, offset: const Offset(0, 2)),
                  ],
                ),
                child: Center(child: Text('$rank',
                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900,
                    color: Colors.white.withAlpha(102), letterSpacing: -2))),
              ),
            ),
          ]),
        );
      },
    );
  }

  // ── Animated Rank List Item ──
  Widget _buildAnimatedRankItem(int rank, LeaderboardEntry entry, bool isDark, Color primary) {
    final controller = _cardControllers[entry.id];
    final animation = controller != null
        ? Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
            parent: controller, curve: Curves.easeOutBack))
        : const AlwaysStoppedAnimation<double>(0.0);
    final moved = entry.movedUp || entry.movedDown;

    return AnimatedBuilder(
      animation: animation,
      builder: (_, child) {
        final scale = moved ? 1.0 + sin(animation.value * pi) * 0.03 : 1.0;
        final glow = moved && animation.value > 0;

        return Transform.scale(
          scale: scale,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B).withAlpha(128) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: glow
                    ? (entry.movedUp ? const Color(0xFF22C55E) : Colors.red).withAlpha(128)
                    : (isDark ? Colors.white10 : Colors.grey.shade200),
                width: glow ? 1.5 : 1,
              ),
              boxShadow: glow ? [BoxShadow(
                color: (entry.movedUp ? const Color(0xFF22C55E) : Colors.red).withAlpha(30),
                blurRadius: 12,
              )] : null,
            ),
            child: Row(children: [
              SizedBox(width: 30, child: Text('$rank',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
              CircleAvatar(radius: 20, backgroundImage: NetworkImage(_avatarUrl(entry))),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${entry.firstName} ${entry.lastName}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(entry.mainSpecialty ?? 'Specialist',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              )),
              // Movement indicator
              if (moved) _buildMovementBadge(entry),
              const SizedBox(width: 8),
              Text('${entry.totalWins} Wins',
                style: TextStyle(fontWeight: FontWeight.bold, color: primary, fontSize: 13)),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildMovementBadge(LeaderboardEntry entry) {
    final delta = entry.rankDelta.abs();
    final isUp = entry.movedUp;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (isUp ? const Color(0xFF22C55E) : Colors.red).withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward,
          size: 12, color: isUp ? const Color(0xFF22C55E) : Colors.red),
        Text('$delta', style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.bold,
          color: isUp ? const Color(0xFF22C55E) : Colors.red)),
      ]),
    );
  }

  String _avatarUrl(LeaderboardEntry entry) {
    if (entry.avatarUrl != null && entry.avatarUrl!.isNotEmpty) {
      return '${ApiService.baseUrl.replaceAll('/api', '')}${entry.avatarUrl}';
    }
    return 'https://ui-avatars.com/api/?name=${entry.firstName}';
  }
}
