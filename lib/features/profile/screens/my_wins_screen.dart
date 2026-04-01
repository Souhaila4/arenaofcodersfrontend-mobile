import 'package:flutter/material.dart';
import 'package:arena/core/theme/app_theme.dart';
import 'package:arena/core/services/api_service.dart';
import 'package:arena/core/models/competition_model.dart';
import 'package:arena/features/hackathons/screens/hackathon_detail_screen.dart';

class MyWinsScreen extends StatefulWidget {
  const MyWinsScreen({super.key});

  @override
  State<MyWinsScreen> createState() => _MyWinsScreenState();
}

class _MyWinsScreenState extends State<MyWinsScreen> {
  final _api = ApiService();
  bool _isLoading = true;
  List<Competition> _wins = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWins();
  }

  Future<void> _loadWins() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _api.getMyWins();
      if (mounted) {
        setState(() {
          _wins = res.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load your winning hackathons.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wins', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _wins.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.military_tech_outlined, size: 80, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'No wins yet.',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Keep competing to earn your spot on the podium!',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadWins,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: _wins.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final c = _wins[index];
                          return Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => HackathonDetailScreen(competitionId: c.id)),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.accentOrange.withAlpha(50), width: 2),
                                  gradient: isDark
                                      ? LinearGradient(
                                          colors: [AppColors.surfaceDark, AppColors.backgroundDark],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentOrange.withAlpha(20),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.emoji_events, color: AppColors.accentOrange, size: 32),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.title,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Won \$${c.rewardPool.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                                color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
