import 'package:flutter/material.dart';
import 'package:arena/core/theme/app_theme.dart';
import 'package:arena/core/services/api_service.dart';
import 'package:arena/core/models/auth_models.dart';
import 'package:url_launcher/url_launcher.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;
  const PublicProfileScreen({super.key, required this.userId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final _api = ApiService();
  AuthUser? _user;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await _api.getPublicUser(widget.userId);
      if (mounted) {
        setState(() {
          _user = user;
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

  Future<void> _launchUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Profil Public', style: TextStyle(fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Erreur: $_error', style: const TextStyle(color: Colors.red)))
              : _user == null
                  ? const Center(child: Text('Utilisateur introuvable'))
                  : _buildProfileContent(isDark),
    );
  }

  Widget _buildProfileContent(bool isDark) {
    final fullName = '${_user!.firstName} ${_user!.lastName}'.trim();
    final initials = '${_user!.firstName.isNotEmpty ? _user!.firstName[0] : ''}${_user!.lastName.isNotEmpty ? _user!.lastName[0] : ''}'.toUpperCase();
    final totalWins = _user!.totalWins;
    final totalChallenges = _user!.totalChallenges;
    final xpScore = totalWins * 150 + totalChallenges * 25;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          CircleAvatar(
            radius: 54,
            backgroundColor: AppColors.primary.withAlpha(40),
            child: Text(
              initials.isNotEmpty ? initials : '?',
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),
          // Name and Role
          Text(
            fullName.isNotEmpty ? fullName : 'User',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          if (_user!.role != 'USER')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.primary.withAlpha(30), borderRadius: BorderRadius.circular(12)),
              child: Text(
                _user!.role == 'COMPANY' ? 'ENTREPRISE' : _user!.role,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            _user!.email,
            style: const TextStyle(fontSize: 14, color: AppColors.primary),
          ),
          const SizedBox(height: 24),

          // Social Links
          if (_user!.githubUrl != null || _user!.linkedinUrl != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_user!.githubUrl != null && _user!.githubUrl!.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () => _launchUrl(_user!.githubUrl),
                    icon: const Icon(Icons.code, size: 16),
                    label: const Text('GitHub'),
                    style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.white24 : Colors.black87, foregroundColor: Colors.white),
                  ),
                if (_user!.githubUrl != null && _user!.linkedinUrl != null) const SizedBox(width: 12),
                if (_user!.linkedinUrl != null && _user!.linkedinUrl!.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () => _launchUrl(_user!.linkedinUrl),
                    icon: const Icon(Icons.work, size: 16),
                    label: const Text('LinkedIn'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0077B5), foregroundColor: Colors.white),
                  ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          if (_user!.role == 'USER') ...[
            const Divider(),
            const SizedBox(height: 16),
            // Skill Specialty
            Row(
              children: [
                const Icon(Icons.stars, color: Colors.orange),
                const SizedBox(width: 8),
                Text('Spécialité : ${_user!.mainSpecialty ?? 'Non défini'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            // Stats
            Row(
              children: [
                Expanded(child: _buildStatCard('Victoires', '$totalWins', AppColors.primary)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('Hackathons', '$totalChallenges', Colors.purpleAccent)),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatCard('XP Score Estimé', '$xpScore XP', Colors.amber.shade700, isWide: true),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, {bool isWide = false}) {
    return Container(
      width: isWide ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: isWide ? 24 : 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 12, color: color.withAlpha(200), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
