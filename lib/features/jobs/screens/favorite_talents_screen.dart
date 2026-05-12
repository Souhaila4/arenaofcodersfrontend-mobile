import 'package:flutter/material.dart';
import 'package:arena/core/theme/app_theme.dart';
import 'package:arena/core/services/api_service.dart';
import 'package:arena/features/jobs/screens/candidate_profile_screen.dart';
import 'package:arena/core/models/auth_models.dart';

class FavoriteTalentsScreen extends StatefulWidget {
  const FavoriteTalentsScreen({super.key});

  @override
  State<FavoriteTalentsScreen> createState() => _FavoriteTalentsScreenState();
}

class _FavoriteTalentsScreenState extends State<FavoriteTalentsScreen> {
  bool _loading = true;
  List<dynamic> _favorites = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService().getFavoriteUsers();
      if (mounted) {
        setState(() {
          _favorites = data;
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

  Future<void> _toggleFavorite(String userId, int index) async {
    try {
      await ApiService().toggleFavorite(userId);
      // On the favorites page, clicking the star always removes it from the list
      if (mounted) {
        setState(() {
          _favorites.removeAt(index);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Retiré des favoris'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Talents Favoris'),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _favorites.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.star_border, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'Aucun favori pour le moment',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _favorites.length,
                      itemBuilder: (context, index) {
                        final fav = _favorites[index];
                        final userJson = fav['user'];
                        if (userJson == null) return const SizedBox();
                        final user = AuthUser.fromJson(userJson);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                                  ? NetworkImage(
                                      user.avatarUrl!.startsWith('http')
                                          ? user.avatarUrl!
                                          : (user.avatarUrl!.startsWith('/')
                                              ? '${ApiService.baseUrl}${user.avatarUrl}'
                                              : '${ApiService.baseUrl}/${user.avatarUrl}'),
                                    )
                                  : null,
                              child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            title: Text(
                              '${user.firstName} ${user.lastName}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(user.mainSpecialty ?? 'Pas de spécialité'),
                            trailing: IconButton(
                              icon: const Icon(Icons.star, color: Colors.amber),
                              onPressed: () => _toggleFavorite(user.id, index),
                            ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CandidateProfileScreen(
                                    user: user,
                                    // Placeholder values if not coming from a match
                                    matchScore: 0,
                                    matchReason: 'Candidat mis en favori.',
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}
