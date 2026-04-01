import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:arena/core/theme/app_theme.dart';
import 'package:arena/core/services/storage_service.dart';
import 'package:arena/core/services/api_service.dart';
import 'package:arena/core/models/auth_models.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:arena/main.dart';
import 'package:provider/provider.dart';
import 'package:arena/accessibility/accessibility_provider.dart';
import 'package:arena/accessibility/accessibility_theme.dart';
import 'package:arena/accessibility/accessibility_voice.dart';
import 'package:arena/features/admin/screens/admin_dashboard_screen.dart';
import 'package:arena/features/hackathons/screens/create_competition_screen.dart';
import 'package:arena/features/wallet/screens/wallet_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _storage = StorageService();
  final _api = ApiService();
  AuthUser? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await _api.getMe();
      if (mounted) setState(() => _user = user);
    } catch (e) {
      final user = await _storage.getUser();
      if (user != null && mounted) {
        setState(() => _user = user);
      }
    }
  }

  Future<void> _handleLogout() async {
    await _api.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/signin', (route) => false);
    }
  }

  Future<void> _launchUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $url')),
        );
      }
    }
  }

  Future<void> _showCompanyRequestDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        title: const Text('Devenir Entreprise', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nom de l\'entreprise',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF0D6CF2))),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Description (Optionnel)',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF0D6CF2))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D6CF2)),
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              try {
                await _api.requestCompanyRole(
                  nameController.text.trim(),
                  description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                );
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Demande envoyée avec succès.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e')),
                  );
                }
              }
            },
            child: const Text('Envoyer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fullName = _user != null ? '${_user!.firstName} ${_user!.lastName}'.trim() : 'User';
    final initials = _user != null ? '${_user!.firstName.isNotEmpty ? _user!.firstName[0] : ''}${_user!.lastName.isNotEmpty ? _user!.lastName[0] : ''}'.toUpperCase() : '?';
    final email = _user?.email ?? '';
    final totalWins = _user?.totalWins ?? 0;
    final totalChallenges = _user?.totalChallenges ?? 0;
    // Calculate a dummy global rank or XP score based on wins for display purposes
    final xpScore = totalWins * 150 + totalChallenges * 25;

    return Scaffold(
      body: Stack(
        children: [
          // Grid pattern background
          if (isDark)
            Positioned.fill(
              child: CustomPaint(
                painter: _GridPatternPainter(),
              ),
            ),
          CustomScrollView(
            slivers: [
              // Top Nav
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                          },
                          icon: Icon(
                            Icons.arrow_back,
                            color: isDark ? Colors.grey.shade300 : Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          'OPERATIVE PROFILE',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3,
                            color: const Color(0xFF0D6CF2),
                          ),
                        ),
                        IconButton(
                          onPressed: _handleLogout,
                          tooltip: 'Sign Out',
                          icon: Icon(
                            Icons.logout,
                            color: isDark ? Colors.grey.shade300 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Profile Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      // Avatar with glow
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Glow behind
                          Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0D6CF2).withAlpha(75),
                                  blurRadius: 40,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                          ),
                          // Outer ring with cyan accent
                          Container(
                            width: 116,
                            height: 116,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.accentCyan.withAlpha(75),
                              ),
                            ),
                          ),
                          // Primary ring
                          Container(
                            width: 112,
                            height: 112,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF0D6CF2),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0D6CF2).withAlpha(130),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: _user?.avatarUrl != null && _user!.avatarUrl!.isNotEmpty
                                ? ClipOval(
                                    child: Image.network(
                                      '${ApiService.baseUrl.replaceAll('/api', '')}${_user!.avatarUrl}',
                                      fit: BoxFit.cover,
                                      width: 108,
                                      height: 108,
                                      errorBuilder: (_, __, ___) => CircleAvatar(
                                        radius: 54,
                                        backgroundColor: isDark ? const Color(0xFF1A2332) : Colors.grey.shade200,
                                        child: Text(
                                          initials.isNotEmpty ? initials : '?',
                                          style: TextStyle(
                                            fontSize: 36,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : CircleAvatar(
                                    radius: 54,
                                    backgroundColor: isDark ? const Color(0xFF1A2332) : Colors.grey.shade200,
                                    child: Text(
                                      initials.isNotEmpty ? initials : '?',
                                      style: TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                  ),
                          ),
                          // Rank badge
                          if (_user?.role != 'COMPANY')
                            Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A2332),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF0D6CF2),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(80),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.military_tech,
                                color: AppColors.accentCyan,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        fullName.isNotEmpty ? fullName : 'User',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email.isNotEmpty ? email : '',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0D6CF2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Rank badge
                      if (_user?.role != 'COMPANY')
                        Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2332),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                            color: const Color(0xFF0D6CF2).withAlpha(75),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.accentCyan,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.accentCyan.withAlpha(100),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _user?.role == 'USER' ? 'CODING TIER' : _user?.role ?? 'USER',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                                color: Colors.grey.shade300,
                              ),
                            ),
                            if (_user?.role == 'USER') ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  '|',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ),
                              Text(
                                _user?.mainSpecialty != null && _user!.mainSpecialty!.isNotEmpty 
                                    ? '${_user!.mainSpecialty}'
                                    : 'GENERAL',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                  color: Colors.grey.shade300,
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Edit Profile Button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context).pushNamed('/edit-profile');
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF0D6CF2),
                                      Color(0xFF2196F3),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0D6CF2).withAlpha(100),
                                      blurRadius: 20,
                                      offset: const Offset(0, 6),
                                      spreadRadius: -2,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                        Icons.edit,
                                        color: Colors.white,
                                        size: 18
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Edit Profile',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        letterSpacing: 0.5,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withAlpha(50),
                                            offset: const Offset(0, 1),
                                            blurRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Face Cursor Toggle Button
                          ValueListenableBuilder<bool>(
                            valueListenable: globalCursorController.isRunningNotifier,
                            builder: (context, isEnabled, child) {
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    if (isEnabled) {
                                      // User wants to disable it completely
                                      globalCursorController.isRunningNotifier.value = false;
                                      globalCursorController.stop();
                                    } else {
                                      // User wants to enable it
                                      globalCursorController.isRunningNotifier.value = true;
                                      // Reset inactivity detector so it will trigger the cursor to show after 5s
                                      globalInactivityDetector.reset(); 
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Cursor enabled. Do not touch the screen for 5 seconds to activate it.'),
                                          duration: Duration(seconds: 3),
                                        ),
                                      );
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: !isEnabled ? const Color(0xFF1A2332) : AppColors.accentCyan.withAlpha(50),
                                      border: Border.all(
                                        color: !isEnabled ? Colors.grey.shade700 : AppColors.accentCyan,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          !isEnabled ? Icons.face_retouching_off : Icons.face,
                                          color: !isEnabled ? Colors.grey.shade400 : AppColors.accentCyan,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          !isEnabled ? 'Cursor Off' : 'Cursor On',
                                          style: TextStyle(
                                            color: !isEnabled ? Colors.grey.shade400 : AppColors.accentCyan,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      if (_user != null && _user!.role == 'USER') ...[
                        const SizedBox(height: 16),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _showCompanyRequestDialog,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A2332),
                                border: Border.all(color: Colors.orangeAccent),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.business,
                                    color: Colors.orangeAccent,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Devenir Entreprise',
                                    style: TextStyle(
                                      color: Colors.orangeAccent,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (_user != null && _user!.role == 'COMPANY') ...[
                        const SizedBox(height: 16),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const CreateCompetitionScreen()),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A2332),
                                border: Border.all(color: Colors.cyanAccent),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.add_circle,
                                    color: Colors.cyanAccent,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Créer un Hackathon',
                                    style: TextStyle(
                                      color: Colors.cyanAccent,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (_user != null && _user!.role == 'ADMIN') ...[
                        const SizedBox(height: 16),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A2332),
                                border: Border.all(color: Colors.purpleAccent),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.admin_panel_settings,
                                    color: Colors.purpleAccent,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Admin Dashboard',
                                    style: TextStyle(
                                      color: Colors.purpleAccent,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      // ── Arena Wallet button (all roles) ──
                      if (_user != null) ...[
                        const SizedBox(height: 16),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const WalletScreen()),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A2332),
                                border: Border.all(color: const Color(0xFF00C2FF)),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.account_balance_wallet,
                                    color: Color(0xFF00C2FF),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Mon Wallet',
                                    style: TextStyle(
                                      color: Color(0xFF00C2FF),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Show balance inline
                                  if (_user!.walletBalance > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00C2FF).withAlpha(30),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${_user!.walletBalance.toStringAsFixed(0)} ARENA',
                                        style: const TextStyle(
                                          color: Color(0xFF00C2FF),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Connect (Socials)
              if (_user?.githubUrl != null || _user?.linkedinUrl != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_user?.githubUrl != null && _user!.githubUrl!.isNotEmpty)
                          _buildSocialButton(
                            icon: Icons.code, 
                            label: 'GitHub', 
                            color: Colors.white, 
                            onTap: () => _launchUrl(_user!.githubUrl),
                          ),
                        if (_user?.githubUrl != null && _user?.linkedinUrl != null && _user!.githubUrl!.isNotEmpty && _user!.linkedinUrl!.isNotEmpty)
                          const SizedBox(width: 16),
                        if (_user?.linkedinUrl != null && _user!.linkedinUrl!.isNotEmpty)
                          _buildSocialButton(
                            icon: Icons.work_outline, 
                            label: 'LinkedIn', 
                            color: const Color(0xFF0077B5), 
                            onTap: () => _launchUrl(_user!.linkedinUrl),
                          ),
                      ],
                    ),
                  ),
                ),
              // Skill Matrix
              if (_user?.role != 'COMPANY')
                SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'SKILL MATRIX',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D6CF2).withAlpha(25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _user?.mainSpecialty ?? 'Specialty Not Set',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF0D6CF2),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Radar chart
                      Container(
                        width: double.infinity,
                        height: 280,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2332),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF0D6CF2).withAlpha(25),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(50),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: CustomPaint(
                            painter: _RadarChartPainter(),
                            size: Size.infinite,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Skills & Technologies Tags
              if (_user != null && _user!.skillTags.isNotEmpty && _user!.role != 'COMPANY')
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SKILLS & TECHNOLOGIES',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _user!.skillTags.map(_buildSkillChip).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              // Battle Data
              if (_user?.role != 'COMPANY')
                SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BATTLE DATA',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _buildBattleStat(context, '$totalWins', 'Won', Colors.white),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildBattleStat(
                              context,
                              '$totalChallenges',
                              'Played',
                              AppColors.accentCyan,
                              hasGlow: true,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildBattleStat(context, '$xpScore', 'XP Score', Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Accessibility Settings
              SliverToBoxAdapter(
                child: Consumer<AccessibilityProvider>(
                  builder: (context, provider, _) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('ACCESSIBILITY ENGINE'),
                          const SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B).withOpacity(0.5),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                                width: 1.5,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(32),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      children: [
                                        _buildModernTile(
                                          icon: Icons.record_voice_over_rounded,
                                          title: 'Voice Assistant',
                                          subtitle: 'AI-guided navigation system',
                                          value: provider.voiceGuideEnabled,
                                          onChanged: (val) => provider.setVoiceGuideEnabled(val),
                                          accentColor: const Color(0xFF38BDF8),
                                        ),
                                        const Divider(height: 40, color: Colors.white10),
                                        _buildModernTile(
                                          icon: Icons.mic_none_rounded,
                                          title: 'Neural Commands',
                                          subtitle: 'Control via natural language',
                                          value: provider.talkToAppEnabled,
                                          onChanged: (val) => provider.setTalkToAppEnabled(val, context),
                                          accentColor: const Color(0xFF818CF8),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24),
                                    child: _buildGlassButton(
                                      onTap: () => provider.isTourRunning
                                          ? AccessibilityVoice().cancelTour(provider)
                                          : AccessibilityVoice().orchestrateTour(provider),
                                      label: provider.isTourRunning ? 'TERMINATE TOUR' : 'LAUNCH SYSTEM TOUR',
                                      icon: provider.isTourRunning ? Icons.stop_circle_outlined : Icons.auto_awesome_outlined,
                                      isActive: provider.isTourRunning,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.3),
                                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildSubHeader('VISUAL INTERFACE'),
                                        const SizedBox(height: 16),
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.03),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                                          ),
                                          child: Row(
                                            children: AccessibilityThemeType.values.map((type) {
                                              final isSelected = provider.themeType == type;
                                              return Expanded(
                                                child: GestureDetector(
                                                  onTap: () => provider.setTheme(type),
                                                  child: AnimatedContainer(
                                                    duration: const Duration(milliseconds: 300),
                                                    curve: Curves.easeInOut,
                                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                                    decoration: BoxDecoration(
                                                      color: isSelected ? const Color(0xFF38BDF8) : Colors.transparent,
                                                      borderRadius: BorderRadius.circular(12),
                                                      boxShadow: isSelected ? [
                                                        BoxShadow(
                                                          color: const Color(0xFF38BDF8).withOpacity(0.3),
                                                          blurRadius: 12,
                                                          offset: const Offset(0, 4),
                                                        )
                                                      ] : [],
                                                    ),
                                                    child: Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          _getThemeIcon(type),
                                                          size: 18,
                                                          color: isSelected ? Colors.white : Colors.white38,
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          _getThemeName(type),
                                                          style: TextStyle(
                                                            color: isSelected ? Colors.white : Colors.white38,
                                                            fontSize: 9,
                                                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                                            letterSpacing: 0.5,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                        const SizedBox(height: 32),
                                        _buildSlider(provider),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // GitHub Showcase
              if (_user != null && _user!.githubRepos.isNotEmpty && _user!.role != 'COMPANY')
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'GITHUB SHOWCASE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 120,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            scrollDirection: Axis.horizontal,
                            itemCount: _user!.githubRepos.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 16),
                            itemBuilder: (context, index) {
                              return _buildRepoCard(_user!.githubRepos[index]);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Recent Achievements
              if (_user?.role != 'COMPANY')
                SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'RECENT UNLOCKABLES',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text(
                          'View All',
                          style: TextStyle(
                            color: Color(0xFF0D6CF2),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_user?.role != 'COMPANY')
                SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                  child: Column(
                    children: [
                      _buildAchievementItem(
                        context,
                        icon: Icons.psychology,
                        iconColor: AppColors.accentCyan,
                        bgColor: const Color(0xFF0D6CF2).withAlpha(50),
                        title: 'AI Pioneer',
                        description: 'Solved 10 Artificial Intelligence challenges with >90% accuracy.',
                        timeAgo: '2d ago',
                        hoverColor: AppColors.primary,
                      ),
                      const SizedBox(height: 10),
                      _buildAchievementItem(
                        context,
                        icon: Icons.bedtime,
                        iconColor: Colors.purple.shade300,
                        bgColor: Colors.purple.withAlpha(50),
                        title: 'Night Owl',
                        description: 'Commit code to the arena repository after 2:00 AM local time.',
                        timeAgo: '5d ago',
                        hoverColor: Colors.purple,
                      ),
                      const SizedBox(height: 10),
                      _buildAchievementItem(
                        context,
                        icon: Icons.local_fire_department,
                        iconColor: Colors.green.shade300,
                        bgColor: Colors.green.withAlpha(50),
                        title: 'Streak Master',
                        description: 'Maintained a 7-day login streak in the arena.',
                        timeAgo: '1w ago',
                        hoverColor: Colors.green,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 3,
        color: Colors.white.withOpacity(0.4),
      ),
    );
  }

  Widget _buildSubHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildModernTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color accentColor,
  }) {
    return Row(
      children: [
        Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: value ? accentColor.withOpacity(0.2) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: value ? accentColor.withOpacity(0.5) : Colors.transparent),
          ),
          child: Icon(icon, color: value ? accentColor : Colors.white38, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
              Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
            ],
          ),
        ),
        _buildIOSStyleSwitch(value, onChanged, accentColor),
      ],
    );
  }

  Widget _buildIOSStyleSwitch(bool value, ValueChanged<bool> onChanged, Color activeColor) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 50,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          color: value ? activeColor : Colors.white.withOpacity(0.1),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassButton({
    required VoidCallback onTap,
    required String label,
    required IconData icon,
    bool isActive = false,
  }) {
    final color = isActive ? Colors.redAccent : const Color(0xFF38BDF8);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isActive ? color.withOpacity(0.1) : Colors.white.withOpacity(0.05),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.2)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlider(AccessibilityProvider provider) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('TEXT SCALE', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
            Text('${(provider.fontScale * 100).toInt()}%', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 2,
            activeTrackColor: const Color(0xFF38BDF8),
            inactiveTrackColor: Colors.white10,
            thumbColor: Colors.white,
            overlayColor: const Color(0xFF38BDF8).withOpacity(0.2),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 5),
          ),
          child: Slider(
            value: provider.fontScale,
            min: 1.0,
            max: 2.0,
            onChanged: (val) => provider.setFontScale(val),
          ),
        ),
      ],
    );
  }

  IconData _getThemeIcon(AccessibilityThemeType type) {
    switch (type) {
      case AccessibilityThemeType.standardDark:
        return Icons.dark_mode_rounded;
      case AccessibilityThemeType.standardLight:
        return Icons.light_mode_rounded;
      case AccessibilityThemeType.highContrast:
        return Icons.contrast_rounded;
      case AccessibilityThemeType.protanopia:
        return Icons.visibility_rounded;
      case AccessibilityThemeType.deuteranopia:
        return Icons.brush_rounded;
      case AccessibilityThemeType.tritanopia:
        return Icons.color_lens_rounded;
    }
  }

  String _getThemeName(AccessibilityThemeType type) {
    switch (type) {
      case AccessibilityThemeType.standardDark:
        return 'DARK';
      case AccessibilityThemeType.standardLight:
        return 'LIGHT';
      case AccessibilityThemeType.highContrast:
        return 'HIGH-C';
      case AccessibilityThemeType.protanopia:
        return 'PROTAN';
      case AccessibilityThemeType.deuteranopia:
        return 'DEUTAN';
      case AccessibilityThemeType.tritanopia:
        return 'TRITAN';
    }
  }

  Widget _buildBattleStat(
    BuildContext context,
    String value,
    String label,
    Color valueColor, {
    bool hasGlow = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF0D6CF2).withAlpha(25),
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: valueColor,
              shadows: hasGlow
                  ? [
                      Shadow(
                        color: AppColors.accentCyan.withAlpha(130),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String description,
    required String timeAgo,
    required Color hoverColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF0D6CF2).withAlpha(25),
        ),
      ),
      child: Row(
        children: [
          // Hexagon-like icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeAgo,
            style: TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillChip(String skill) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.accentCyan.withAlpha(50),
        ),
      ),
      child: Text(
        skill,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.accentCyan,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2332),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: color.withAlpha(50)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRepoCard(GithubRepo repo) {
    return GestureDetector(
      onTap: () => _launchUrl(repo.url),
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2332),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF0D6CF2).withAlpha(25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.book, color: Colors.grey, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    repo.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                if (repo.language != null) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    repo.language!,
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                const Icon(Icons.star_border, color: Colors.amber, size: 14),
                const SizedBox(width: 4),
                Text(
                  '${repo.stars}',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
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

/// Draws the grid pattern background
class _GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0D6CF2).withAlpha(10)
      ..strokeWidth = 0.5;

    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Draws the skill radar chart
class _RadarChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = math.min(cx, cy) * 0.75;

    // Labels
    final labels = ['AI (98%)', 'Algo', 'Sys', 'DB', 'Sec', 'UI/UX'];
    final dataValues = [0.95, 0.85, 0.70, 0.65, 0.60, 0.55]; // normalized 0..1

    // Grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (double scale in [1.0, 0.66, 0.33]) {
      final path = Path();
      for (int i = 0; i < 6; i++) {
        final angle = (i * 60 - 90) * math.pi / 180;
        final x = cx + radius * scale * math.cos(angle);
        final y = cy + radius * scale * math.sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // Axis lines
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 90) * math.pi / 180;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + radius * math.cos(angle), cy + radius * math.sin(angle)),
        gridPaint,
      );
    }

    // Data polygon
    final dataPath = Path();
    final dataPaint = Paint()
      ..color = const Color(0xFF0D6CF2).withAlpha(60)
      ..style = PaintingStyle.fill;
    final dataStrokePaint = Paint()
      ..color = const Color(0xFF0D6CF2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 90) * math.pi / 180;
      final x = cx + radius * dataValues[i] * math.cos(angle);
      final y = cy + radius * dataValues[i] * math.sin(angle);
      if (i == 0) {
        dataPath.moveTo(x, y);
      } else {
        dataPath.lineTo(x, y);
      }
    }
    dataPath.close();
    canvas.drawPath(dataPath, dataPaint);
    canvas.drawPath(dataPath, dataStrokePaint);

    // Data points (cyan dots)
    final dotPaint = Paint()
      ..color = const Color(0xFF00F0FF)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 90) * math.pi / 180;
      final x = cx + radius * dataValues[i] * math.cos(angle);
      final y = cy + radius * dataValues[i] * math.sin(angle);
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
    }

    // Labels
    final labelStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: Colors.grey.shade400,
      fontFamily: 'Inter',
    );

    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 90) * math.pi / 180;
      final labelRadius = radius + 20;
      final x = cx + labelRadius * math.cos(angle);
      final y = cy + labelRadius * math.sin(angle);

      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: i == 0
              ? labelStyle.copyWith(
                  color: Colors.grey.shade300,
                  fontWeight: FontWeight.w700,
                )
              : labelStyle,
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(
        canvas,
        Offset(x - tp.width / 2, y - tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
