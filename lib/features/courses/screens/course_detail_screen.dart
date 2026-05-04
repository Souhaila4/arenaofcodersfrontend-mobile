import 'package:flutter/material.dart';
import 'package:arena/core/services/api_service.dart';
import 'package:arena/core/models/course_model.dart';
import 'package:arena/core/models/auth_models.dart';
import 'package:arena/core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class CourseDetailScreen extends StatefulWidget {
  final String courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  Course? _course;
  List<CourseDocument> _documents = [];
  bool _isLoading = true;
  bool _isEnrolling = false;
  bool _loadingDocs = false;

  late AnimationController _joinAnimController;
  late Animation<double> _joinScaleAnim;

  @override
  void initState() {
    super.initState();
    _joinAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
    _joinScaleAnim = _joinAnimController.drive(Tween(begin: 0.95, end: 1.0));
    _loadCourse();
  }

  @override
  void dispose() {
    _joinAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadCourse() async {
    setState(() => _isLoading = true);
    try {
      final data = await _api.getCourseDetail(widget.courseId);
      if (mounted) {
        final course = Course.fromJson(data);
        setState(() {
          _course = course;
          _isLoading = false;
        });
        if (course.isEnrolled) {
          _loadDocuments();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDocuments() async {
    setState(() => _loadingDocs = true);
    try {
      final docs = await _api.getCourseDocuments(widget.courseId);
      if (mounted) {
        setState(() {
          _documents = docs
              .map((e) =>
                  CourseDocument.fromJson(e as Map<String, dynamic>))
              .toList();
          _loadingDocs = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingDocs = false);
    }
  }

  Future<void> _handleEnroll() async {
    if (_isEnrolling) return;
    _joinAnimController.reverse().then((_) => _joinAnimController.forward());
    setState(() => _isEnrolling = true);
    try {
      await _api.enrollInCourse(widget.courseId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Successfully enrolled!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        _loadCourse();
      }
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.displayMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isEnrolling = false);
    }
  }

  Future<void> _openDocument(CourseDocument doc) async {
    final url =
        '${ApiService.baseUrl.replaceAll('/api', '')}${doc.fileUrl}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not open document'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B0E14),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_course == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B0E14),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: Text('Course not found',
              style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final course = _course!;
    final catColor = Color(CourseCategories.color(course.category));

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Hero image/header
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: const Color(0xFF0F172A),
                iconTheme: const IconThemeData(color: Colors.white),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Thumbnail or gradient
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              catColor.withAlpha(60),
                              catColor.withAlpha(15),
                              const Color(0xFF0B0E14),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: course.thumbnailUrl != null &&
                                course.thumbnailUrl!.isNotEmpty
                            ? Image.network(
                                '${ApiService.baseUrl.replaceAll('/api', '')}${course.thumbnailUrl}',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              )
                            : null,
                      ),
                      // Dark overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              const Color(0xFF0B0E14).withAlpha(200),
                              const Color(0xFF0B0E14),
                            ],
                            stops: const [0.0, 0.7, 1.0],
                          ),
                        ),
                      ),
                      // Course info at bottom
                      Positioned(
                        bottom: 16,
                        left: 20,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Category badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: catColor.withAlpha(30),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: catColor.withAlpha(60)),
                              ),
                              child: Text(
                                CourseCategories.label(course.category),
                                style: TextStyle(
                                  color: catColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              course.title,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Stats row
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: [
                      _buildInfoChip(Icons.people_alt_rounded,
                          '${course.enrollmentCount} students', catColor),
                      const SizedBox(width: 12),
                      _buildInfoChip(Icons.description_rounded,
                          '${course.documentCount} documents', catColor),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: course.price > 0
                              ? const Color(0xFFF59E0B).withAlpha(20)
                              : const Color(0xFF10B981).withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: course.price > 0
                                ? const Color(0xFFF59E0B).withAlpha(50)
                                : const Color(0xFF10B981).withAlpha(50),
                          ),
                        ),
                        child: Text(
                          course.price > 0
                              ? '${course.price.toStringAsFixed(0)} DT'
                              : 'FREE',
                          style: TextStyle(
                            color: course.price > 0
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF10B981),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Creator
              if (course.creatorName != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [catColor.withAlpha(60), catColor.withAlpha(30)],
                            ),
                          ),
                          child:
                              const Icon(Icons.person, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Instructor',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w600)),
                            Text(course.creatorName!,
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              // Description
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'About this course',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF151B26),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withAlpha(13)),
                        ),
                        child: Text(
                          course.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade400,
                            height: 1.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Documents section — only if enrolled
              if (course.isEnrolled) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                    child: Row(
                      children: [
                        const Icon(Icons.folder_open_rounded,
                            color: AppColors.primary, size: 22),
                        const SizedBox(width: 8),
                        const Text(
                          'Course Materials',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        Text('${_documents.length} files',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                if (_loadingDocs)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary)),
                    ),
                  )
                else if (_documents.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text('No documents uploaded yet',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 13)),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _buildDocumentTile(_documents[index]),
                        childCount: _documents.length,
                      ),
                    ),
                  ),
              ],
              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
          // Bottom CTA
          if (!course.isEnrolled)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.fromLTRB(20, 16, 20, 32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0B0E14).withAlpha(0),
                      const Color(0xFF0B0E14),
                    ],
                  ),
                ),
                child: ScaleTransition(
                  scale: _joinScaleAnim,
                  child: GestureDetector(
                    onTap: _handleEnroll,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [catColor, catColor.withAlpha(200)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: catColor.withAlpha(80),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isEnrolling
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5))
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.school_rounded,
                                      color: Colors.white, size: 22),
                                  SizedBox(width: 10),
                                  Text(
                                    'Join Course',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildDocumentTile(CourseDocument doc) {
    final iconData = _getFileIcon(doc.fileType);
    final iconColor = _getFileColor(doc.fileType);

    return GestureDetector(
      onTap: () => _openDocument(doc),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2332),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(13)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(iconData, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        doc.fileType.toUpperCase(),
                        style: TextStyle(
                          color: iconColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      if (doc.fileSizeFormatted.isNotEmpty) ...[
                        Text(' · ',
                            style: TextStyle(color: Colors.grey.shade600)),
                        Text(doc.fileSizeFormatted,
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 11)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.download_rounded,
                  color: AppColors.primary, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String type) {
    switch (type) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'image':
        return Icons.image_rounded;
      case 'video':
        return Icons.play_circle_rounded;
      case 'archive':
        return Icons.archive_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _getFileColor(String type) {
    switch (type) {
      case 'pdf':
        return const Color(0xFFEF4444);
      case 'image':
        return const Color(0xFF10B981);
      case 'video':
        return const Color(0xFF8B5CF6);
      case 'archive':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF6B7280);
    }
  }
}
