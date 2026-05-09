import 'package:flutter/material.dart';
import 'package:arena/core/services/api_service.dart';
import 'package:arena/core/models/course_model.dart';
import 'package:arena/core/models/auth_models.dart';
import 'package:arena/core/services/storage_service.dart';
import 'package:arena/core/theme/app_theme.dart';
import 'package:arena/features/courses/screens/course_detail_screen.dart';
import 'package:arena/features/courses/screens/admin_create_course_screen.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  final _storage = StorageService();
  final _searchController = TextEditingController();

  List<Course> _courses = [];
  bool _isLoading = true;
  String? _selectedCategory;
  AuthUser? _currentUser;

  final List<String> _categories = [
    'ALL',
    'PROGRAMMING',
    'WEB_DEVELOPMENT',
    'MOBILE_DEVELOPMENT',
    'DATA_SCIENCE',
    'CYBERSECURITY',
    'DESIGN',
    'DEVOPS',
    'OTHER',
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadCourses();
  }

  Future<void> _loadUser() async {
    try {
      final user = await _api.getMe();
      if (mounted) setState(() => _currentUser = user);
    } catch (_) {
      final user = await _storage.getUser();
      if (mounted) setState(() => _currentUser = user);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    setState(() => _isLoading = true);
    try {
      final result = await _api.getCourses(
        category: _selectedCategory == 'ALL' ? null : _selectedCategory,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );
      if (mounted) {
        final list = (result['data'] as List<dynamic>?) ?? [];
        setState(() {
          _courses =
              list.map((e) => Course.fromJson(e as Map<String, dynamic>)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient blobs
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6366F1).withAlpha(30),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withAlpha(20),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Courses',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Learn. Build. Grow.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context)
                                    .pushNamed('/my-courses')
                                    .then((_) => _loadCourses());
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF6366F1),
                                      Color(0xFF8B5CF6),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          const Color(0xFF6366F1).withAlpha(60),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.bookmark_rounded,
                                        color: Colors.white, size: 16),
                                    SizedBox(width: 6),
                                    Text(
                                      'My Courses',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Search bar
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.white.withAlpha(13)),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Search courses...',
                              hintStyle:
                                  TextStyle(color: Colors.grey.shade600),
                              prefixIcon: Icon(Icons.search_rounded,
                                  color: Colors.grey.shade500),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.clear,
                                          color: Colors.grey.shade500,
                                          size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        _loadCourses();
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onSubmitted: (_) => _loadCourses(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Category chips
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected =
                          (_selectedCategory ?? 'ALL') == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedCategory = cat);
                            _loadCourses();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? LinearGradient(
                                      colors: [
                                        Color(cat == 'ALL'
                                            ? 0xFF00C2FF
                                            : CourseCategories.color(cat)),
                                        Color(cat == 'ALL'
                                                ? 0xFF2563EB
                                                : CourseCategories.color(cat))
                                            .withAlpha(180),
                                      ],
                                    )
                                  : null,
                              color: isSelected
                                  ? null
                                  : const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(20),
                              border: isSelected
                                  ? null
                                  : Border.all(
                                      color: Colors.white.withAlpha(13)),
                            ),
                            child: Text(
                              cat == 'ALL'
                                  ? 'All'
                                  : CourseCategories.label(cat),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // Course list
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary)),
                )
              else if (_courses.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.school_outlined,
                            size: 64, color: Colors.grey.shade600),
                        const SizedBox(height: 16),
                        Text('No courses found',
                            style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text('Try a different search or category',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _buildCourseCard(_courses[index]),
                      childCount: _courses.length,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: _currentUser?.role == 'ADMIN'
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context)
                    .pushNamed('/admin-courses')
                    .then((_) => _loadCourses());
              },
              backgroundColor: const Color(0xFF6366F1),
              icon: const Icon(Icons.edit_square, color: Colors.white),
              label: const Text('Manage',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _buildCourseCard(Course course) {
    final catColor = Color(CourseCategories.color(course.category));

    return GestureDetector(
      onTap: () {
        Navigator.of(context)
            .push(MaterialPageRoute(
                builder: (_) => CourseDetailScreen(courseId: course.id)))
            .then((_) => _loadCourses());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF151B26),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withAlpha(13)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              child: Stack(
                children: [
                  Container(
                    height: 140,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          catColor.withAlpha(40),
                          catColor.withAlpha(15),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: course.thumbnailUrl != null &&
                            course.thumbnailUrl!.isNotEmpty
                        ? Image.network(
                            '${ApiService.baseUrl.replaceAll('/api', '')}${course.thumbnailUrl}',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Icon(Icons.school_rounded,
                                  size: 48, color: catColor.withAlpha(120)),
                            ),
                          )
                        : Center(
                            child: Icon(Icons.school_rounded,
                                size: 48, color: catColor.withAlpha(120)),
                          ),
                  ),
                  // Price badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withAlpha(200),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.white.withAlpha(25)),
                      ),
                      child: Text(
                        course.price > 0
                            ? '${course.price.toStringAsFixed(0)} DT'
                            : 'Free',
                        style: TextStyle(
                          color: course.price > 0
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF10B981),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  // Enrolled badge
                  if (course.isEnrolled)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle,
                                color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text('Enrolled',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  // Gradient overlay at bottom
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            const Color(0xFF151B26),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: catColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      CourseCategories.label(course.category),
                      style: TextStyle(
                        color: catColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Title
                  Text(
                    course.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Description
                  Text(
                    course.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                  // Stats row
                  Row(
                    children: [
                      _buildStat(Icons.people_alt_outlined,
                          '${course.enrollmentCount}', 'students'),
                      const SizedBox(width: 20),
                      _buildStat(Icons.description_outlined,
                          '${course.documentCount}', 'docs'),
                      const Spacer(),
                      if (course.creatorName != null)
                        Row(
                          children: [
                            Icon(Icons.person_outline,
                                size: 13, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              course.creatorName!,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600),
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
      ),
    );
  }

  Widget _buildStat(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
        ),
      ],
    );
  }
}
