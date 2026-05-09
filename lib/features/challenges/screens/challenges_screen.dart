import 'package:flutter/material.dart';
import 'package:arena/core/theme/app_theme.dart';

class ChallengesScreen extends StatelessWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Background blobs (dark mode)
          if (isDark) ...[
            Positioned(
              top: -80,
              left: -100,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.height * 0.4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF2563EB).withAlpha(50),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).size.height * 0.4,
              right: -100,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.6,
                height: MediaQuery.of(context).size.height * 0.4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF3B82F6).withAlpha(25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              left: MediaQuery.of(context).size.width * 0.2,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.7,
                height: MediaQuery.of(context).size.height * 0.3,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF0284C7).withAlpha(50),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
          CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TUNISIAN ARENA',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 3,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Challenges',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                                border: Border.all(
                                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                                ),
                              ),
                              child: Icon(
                                Icons.person,
                                color: Colors.grey.shade500,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Search bar
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B).withAlpha(130)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                            ),
                            boxShadow: isDark
                                ? null
                                : [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(10),
                                      blurRadius: 8,
                                    ),
                                  ],
                          ),
                          child: TextField(
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Find Python, AI, React...',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.grey.shade500,
                                size: 22,
                              ),
                              suffixIcon: Icon(
                                Icons.tune,
                                color: Colors.grey.shade500,
                                size: 22,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Featured Event
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FEATURED EVENT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildFeaturedCard(context, isDark),
                    ],
                  ),
                ),
              ),
              // Category pills
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        _buildCategoryPill(context, 'All', isActive: true),
                        _buildCategoryPill(context, 'Python', dotColor: Colors.yellow),
                        _buildCategoryPill(context, 'React', dotColor: Colors.blue.shade400),
                        _buildCategoryPill(context, 'Node.js', dotColor: Colors.green),
                        _buildCategoryPill(context, 'AI/ML', dotColor: Colors.purple),
                      ],
                    ),
                  ),
                ),
              ),
              // Latest Challenges
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Text(
                    'LATEST CHALLENGES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                  child: Column(
                    children: [
                      _buildChallengeListItem(
                        context,
                        isDark: isDark,
                        emoji: '🐍',
                        title: 'Python Data Quest',
                        difficulty: 'Intermediate',
                        difficultyColor: Colors.amber,
                        category: 'Data Science',
                        xp: 500,
                        description:
                            'Analyze a large dataset to find hidden patterns in Tunisian e-commerce trends. Use Pandas and Matplotlib.',
                        competitors: 42,
                        accentColor: AppColors.primary,
                      ),
                      const SizedBox(height: 14),
                      _buildChallengeListItem(
                        context,
                        isDark: isDark,
                        emoji: '⚛️',
                        title: 'React UI Master',
                        difficulty: 'Beginner',
                        difficultyColor: Colors.green,
                        category: 'Frontend',
                        xp: 300,
                        description:
                            'Create a responsive dashboard component using Tailwind CSS and React hooks. Pixel perfection required.',
                        competitors: 89,
                        accentColor: Colors.blue,
                      ),
                      const SizedBox(height: 14),
                      _buildChallengeListItem(
                        context,
                        isDark: isDark,
                        emoji: '🧠',
                        title: 'Neural Net Optim',
                        difficulty: 'Hard',
                        difficultyColor: Colors.red,
                        category: 'Deep Learning',
                        xp: 1200,
                        description:
                            'Optimize a pre-trained model for edge devices. Reduce latency while maintaining accuracy.',
                        competitors: 15,
                        accentColor: Colors.purple,
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

  Widget _buildFeaturedCard(BuildContext context, bool isDark) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF004E92)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF004E92).withAlpha(60),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background pattern overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withAlpha(5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentOrange.withAlpha(50),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.accentOrange.withAlpha(75),
                        ),
                      ),
                      child: const Text(
                        '🔥 Hot',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentOrange,
                        ),
                      ),
                    ),
                    Text(
                      '24h Left',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: Colors.white.withAlpha(150),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Esprit AI Hackathon',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Build the next generation of predictive models using real-world datasets.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade300,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Stacked avatars
                        SizedBox(
                          width: 56,
                          height: 24,
                          child: Stack(
                            children: [
                              for (int i = 0; i < 3; i++)
                                Positioned(
                                  left: i * 16.0,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: [
                                        Colors.blue,
                                        Colors.green,
                                        Colors.purple,
                                      ][i],
                                      border: Border.all(
                                        color: const Color(0xFF0F172A),
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '+124 participating',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade300,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPill(
    BuildContext context,
    String label, {
    bool isActive = false,
    Color? dotColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(right: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary
                  : (isDark ? AppColors.cardDark : Colors.white),
              borderRadius: BorderRadius.circular(14),
              border: isActive
                  ? null
                  : Border.all(
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                    ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(75),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                if (dotColor != null) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? Colors.white
                        : (isDark ? Colors.grey.shade300 : Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChallengeListItem(
    BuildContext context, {
    required bool isDark,
    required String emoji,
    required String title,
    required String difficulty,
    required Color difficultyColor,
    required String category,
    required int xp,
    required String description,
    required int competitors,
    required Color accentColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardDark.withAlpha(130)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.grey.shade700.withAlpha(130)
              : Colors.grey.shade100,
        ),
      ),
      child: Stack(
        children: [
          // Accent blob top-right
          Positioned(
            top: -16,
            right: -16,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withAlpha(isDark ? 13 : 10),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Emoji icon box
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(emoji, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: difficultyColor.withAlpha(isDark ? 50 : 30),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  difficulty,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? difficultyColor.shade300
                                        : difficultyColor.shade700,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  '•',
                                  style: TextStyle(color: Colors.grey.shade400),
                                ),
                              ),
                              Text(
                                category,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '$xp XP',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? Colors.grey.shade700.withAlpha(130)
                            : Colors.grey.shade100,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.groups_outlined,
                            size: 16,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$competitors Competitors',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            'View Details',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward,
                            size: 14,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension on Color {
  Color get shade300 {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness + 0.2).clamp(0.0, 1.0)).toColor();
  }

  Color get shade700 {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
  }
}
