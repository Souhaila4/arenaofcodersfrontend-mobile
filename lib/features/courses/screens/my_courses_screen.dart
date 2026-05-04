import 'package:flutter/material.dart';
import 'package:arena/core/services/api_service.dart';
import 'package:arena/core/models/course_model.dart';
import 'package:arena/core/theme/app_theme.dart';
import 'package:arena/features/courses/screens/course_detail_screen.dart';

class MyCoursesScreen extends StatefulWidget {
  const MyCoursesScreen({super.key});

  @override
  State<MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends State<MyCoursesScreen> {
  final _api = ApiService();
  List<Course> _courses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await _api.getMyEnrollments();
      if (mounted) {
        setState(() {
          _courses = data
              .map((e) => Course.fromJson(e as Map<String, dynamic>))
              .toList();
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
      backgroundColor: const Color(0xFF0B0E14),
      appBar: AppBar(
        title: const Text('My Courses',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _courses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withAlpha(13)),
                        ),
                        child: Icon(Icons.school_outlined,
                            size: 40, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 20),
                      Text('No enrolled courses yet',
                          style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text('Join a course to start learning!',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 13)),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.explore_rounded, size: 18),
                        label: const Text('Browse Courses',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _courses.length,
                    itemBuilder: (context, index) =>
                        _buildEnrolledCard(_courses[index]),
                  ),
                ),
    );
  }

  Widget _buildEnrolledCard(Course course) {
    final catColor = Color(CourseCategories.color(course.category));

    return GestureDetector(
      onTap: () {
        Navigator.of(context)
            .push(MaterialPageRoute(
                builder: (_) => CourseDetailScreen(courseId: course.id)))
            .then((_) => _load());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF151B26),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: catColor.withAlpha(40)),
          boxShadow: [
            BoxShadow(
              color: catColor.withAlpha(15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left color accent + icon
            Container(
              width: 80,
              height: 90,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [catColor.withAlpha(40), catColor.withAlpha(15)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16)),
              ),
              child: course.thumbnailUrl != null &&
                      course.thumbnailUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(16)),
                      child: Image.network(
                        '${ApiService.baseUrl.replaceAll('/api', '')}${course.thumbnailUrl}',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Icon(Icons.school_rounded,
                                color: catColor, size: 32),
                      ),
                    )
                  : Icon(Icons.school_rounded,
                      color: catColor, size: 32),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: catColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            CourseCategories.label(course.category),
                            style: TextStyle(
                              color: catColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.arrow_forward_ios,
                            size: 12, color: Colors.grey.shade600),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      course.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.description_outlined,
                            size: 13, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text('${course.documentCount} documents',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 11)),
                        const SizedBox(width: 14),
                        Icon(Icons.people_alt_outlined,
                            size: 13, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text('${course.enrollmentCount}',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
