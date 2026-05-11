import 'package:flutter/material.dart';
import 'package:arena/app/router.dart';
import 'package:arena/features/home/screens/dashboard_screen.dart';
import 'package:arena/features/hackathons/screens/hackathons_screen.dart';
import 'package:arena/features/courses/screens/courses_screen.dart';
import 'package:arena/features/leaderboard/screens/leaderboard_3d_screen.dart';
import 'package:arena/features/profile/screens/profile_screen.dart';

const _primaryColor = Color(0xFF00C2FF);

/// Bottom-navigation shell that hosts the main tabs.
///
/// Kept separate from [ArenaApp] so routing and layout concerns are distinct.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  static MainShellState? of(BuildContext context) {
    return context.findAncestorStateOfType<MainShellState>();
  }

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  void switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  /// Only build the active screen — avoids keeping all 5 screens in memory.
  Widget _buildActiveScreen() {
    switch (_currentIndex) {
      case 0:
        return const DashboardScreen();
      case 1:
        return const HackathonsScreen();
      case 2:
        return const CoursesScreen();
      case 3:
        return const Leaderboard3DScreen();
      case 4:
        return const ProfileScreen();
      default:
        return const DashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: _buildActiveScreen(),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        isDark: isDark,
        onTap: (i) {
          setState(() => _currentIndex = i);
        },
        onChatTap: () => Navigator.of(context).pushNamed(AppRouter.rooms),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final bool isDark;
  final ValueChanged<int> onTap;
  final VoidCallback onChatTap;

  const _BottomNav({
    required this.currentIndex,
    required this.isDark,
    required this.onTap,
    required this.onChatTap,
  });


  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F141C).withAlpha(230)
            : Colors.white.withAlpha(230),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withAlpha(13)
                : Colors.grey.shade200,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home', index: 0, currentIndex: currentIndex, onTap: onTap),
              _NavItem(icon: Icons.emoji_events_outlined, activeIcon: Icons.emoji_events, label: 'Hackathons', index: 1, currentIndex: currentIndex, onTap: onTap),
              _NavItem(icon: Icons.school_outlined, activeIcon: Icons.school, label: 'Courses', index: 2, currentIndex: currentIndex, onTap: onTap),
              _NavItem(icon: Icons.leaderboard_outlined, activeIcon: Icons.leaderboard, label: 'Ranking', index: 3, currentIndex: currentIndex, onTap: onTap),
              _NavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile', index: 4, currentIndex: currentIndex, onTap: onTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? _primaryColor : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? _primaryColor : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatFab extends StatelessWidget {
  final VoidCallback onTap;

  const _ChatFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        transform: Matrix4.translationValues(0, -16, 0),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_primaryColor, Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withAlpha(100),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF0B0E14)
                : Colors.white,
            width: 4,
          ),
        ),
        child: const Icon(Icons.forum_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}
