import 'package:flutter/material.dart';
import 'package:arena/core/services/api_service.dart';
import 'package:arena/core/models/course_model.dart';
import 'package:arena/core/theme/app_theme.dart';
import 'package:arena/features/courses/screens/admin_create_course_screen.dart';

class AdminCoursesScreen extends StatefulWidget {
  const AdminCoursesScreen({super.key});
  @override
  State<AdminCoursesScreen> createState() => _AdminCoursesScreenState();
}

class _AdminCoursesScreenState extends State<AdminCoursesScreen> {
  final _api = ApiService();
  List<Course> _courses = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final r = await _api.getAdminCourses();
      final list = (r['data'] as List<dynamic>?) ?? [];
      if (mounted) setState(() { _courses = list.map((e) => Course.fromJson(e as Map<String, dynamic>)).toList(); _isLoading = false; });
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _delete(String id, String title) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Delete Course', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: Text('Delete "$title"? All docs & enrollments will be removed.', style: TextStyle(color: Colors.grey.shade400)),
      actions: [
        TextButton(onPressed: () => Navigator.of(c).pop(false), child: Text('Cancel', style: TextStyle(color: Colors.grey.shade500))),
        ElevatedButton(onPressed: () => Navigator.of(c).pop(true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      ],
    ));
    if (ok != true) return;
    try { await _api.deleteCourseAdmin(id); if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Course deleted'), backgroundColor: Color(0xFF10B981))); _load(); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)); }
  }

  Future<void> _togglePublish(Course c) async {
    try { await _api.updateCourse(c.id, isPublished: !c.isPublished); if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(c.isPublished ? 'Course unpublished' : 'Course published!'), backgroundColor: const Color(0xFF10B981))); _load(); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Manage Courses', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : _courses.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.school_outlined, size: 64, color: Colors.grey.shade700),
              const SizedBox(height: 16),
              Text('No courses yet', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminCreateCourseScreen())).then((_) => _load()),
                icon: const Icon(Icons.add, size: 18), label: const Text('Create Course', style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ]))
          : RefreshIndicator(onRefresh: _load, color: AppColors.primary, child: ListView.builder(
              padding: const EdgeInsets.all(16), itemCount: _courses.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(padding: const EdgeInsets.only(bottom: 12), child: GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminCreateCourseScreen())).then((_) => _load()),
                    child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]), borderRadius: BorderRadius.circular(12)),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add, color: Colors.white), SizedBox(width: 8), Text('Create New Course', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14))])),
                  ));
                }
                return _card(_courses[index - 1]);
              },
            )),
    );
  }

  Widget _card(Course course) {
    final cc = Color(CourseCategories.color(course.category));
    return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF1A2332), borderRadius: BorderRadius.circular(14), border: Border.all(color: course.isPublished ? const Color(0xFF10B981).withAlpha(40) : Colors.white.withAlpha(13))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: cc.withAlpha(20), borderRadius: BorderRadius.circular(6)), child: Text(CourseCategories.label(course.category), style: TextStyle(color: cc, fontSize: 10, fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: course.isPublished ? const Color(0xFF10B981).withAlpha(20) : const Color(0xFFF59E0B).withAlpha(20), borderRadius: BorderRadius.circular(6)),
            child: Text(course.isPublished ? 'LIVE' : 'DRAFT', style: TextStyle(color: course.isPublished ? const Color(0xFF10B981) : const Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.w700))),
          const Spacer(),
          Text(course.price > 0 ? '${course.price.toStringAsFixed(0)} DT' : 'Free', style: TextStyle(color: course.price > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 10),
        Text(course.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.people_alt_outlined, size: 13, color: Colors.grey.shade600), const SizedBox(width: 4),
          Text('${course.enrollmentCount} students', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
          const SizedBox(width: 16),
          Icon(Icons.description_outlined, size: 13, color: Colors.grey.shade600), const SizedBox(width: 4),
          Text('${course.documentCount} docs', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: GestureDetector(onTap: () => _togglePublish(course), child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: (course.isPublished ? const Color(0xFFF59E0B) : const Color(0xFF10B981)).withAlpha(15), borderRadius: BorderRadius.circular(8), border: Border.all(color: (course.isPublished ? const Color(0xFFF59E0B) : const Color(0xFF10B981)).withAlpha(40))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(course.isPublished ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 14, color: course.isPublished ? const Color(0xFFF59E0B) : const Color(0xFF10B981)), const SizedBox(width: 6), Text(course.isPublished ? 'Unpublish' : 'Publish', style: TextStyle(color: course.isPublished ? const Color(0xFFF59E0B) : const Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w600))])))),
          const SizedBox(width: 8),
          Expanded(child: GestureDetector(onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminCreateCourseScreen(editCourseId: course.id))).then((_) => _load()),
            child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: AppColors.primary.withAlpha(15), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.primary.withAlpha(40))),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.edit_outlined, size: 14, color: AppColors.primary), SizedBox(width: 6), Text('Edit', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600))])))),
          const SizedBox(width: 8),
          GestureDetector(onTap: () => _delete(course.id, course.title),
            child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withAlpha(15), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withAlpha(40))),
              child: const Icon(Icons.delete_outline, size: 16, color: Colors.red))),
        ]),
      ]),
    );
  }
}
