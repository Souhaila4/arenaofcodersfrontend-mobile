/// Data models for the Courses feature.

class Course {
  final String id;
  final String title;
  final String description;
  final String category;
  final double price;
  final String? thumbnailUrl;
  final bool isPublished;
  final int enrollmentCount;
  final int documentCount;
  final bool isEnrolled;
  final String? creatorName;
  final DateTime createdAt;

  Course({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.price = 0,
    this.thumbnailUrl,
    this.isPublished = false,
    this.enrollmentCount = 0,
    this.documentCount = 0,
    this.isEnrolled = false,
    this.creatorName,
    required this.createdAt,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    final createdBy = json['createdBy'] as Map<String, dynamic>?;
    String? creatorName;
    if (createdBy != null) {
      creatorName =
          '${createdBy['firstName'] ?? ''} ${createdBy['lastName'] ?? ''}'
              .trim();
    }

    return Course(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      isPublished: json['isPublished'] as bool? ?? false,
      enrollmentCount: json['enrollmentCount'] as int? ??
          (json['_count'] as Map<String, dynamic>?)?['enrollments'] as int? ??
          0,
      documentCount: json['documentCount'] as int? ??
          (json['_count'] as Map<String, dynamic>?)?['documents'] as int? ??
          0,
      isEnrolled: json['isEnrolled'] as bool? ?? false,
      creatorName: creatorName,
      createdAt: DateTime.parse(
          json['createdAt'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
}

class CourseDocument {
  final String id;
  final String courseId;
  final String title;
  final String fileUrl;
  final String fileType;
  final int? fileSize;
  final int order;

  CourseDocument({
    required this.id,
    required this.courseId,
    required this.title,
    required this.fileUrl,
    required this.fileType,
    this.fileSize,
    this.order = 0,
  });

  factory CourseDocument.fromJson(Map<String, dynamic> json) {
    return CourseDocument(
      id: json['id'] as String,
      courseId: json['courseId'] as String,
      title: json['title'] as String,
      fileUrl: json['fileUrl'] as String,
      fileType: json['fileType'] as String? ?? 'other',
      fileSize: json['fileSize'] as int?,
      order: json['order'] as int? ?? 0,
    );
  }

  /// Human-readable file size
  String get fileSizeFormatted {
    if (fileSize == null) return '';
    if (fileSize! < 1024) return '$fileSize B';
    if (fileSize! < 1024 * 1024) return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class CoursesResponse {
  final List<Course> data;
  final int total;
  final int page;
  final int limit;

  CoursesResponse({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
  });

  factory CoursesResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['data'] as List<dynamic>?) ?? [];
    return CoursesResponse(
      data: list.map((e) => Course.fromJson(e as Map<String, dynamic>)).toList(),
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? 20,
    );
  }
}

/// Category display helpers
class CourseCategories {
  static const Map<String, String> labels = {
    'PROGRAMMING': 'Programming',
    'WEB_DEVELOPMENT': 'Web Dev',
    'MOBILE_DEVELOPMENT': 'Mobile Dev',
    'DATA_SCIENCE': 'Data Science',
    'CYBERSECURITY': 'Cybersecurity',
    'DESIGN': 'Design',
    'DEVOPS': 'DevOps',
    'OTHER': 'Other',
  };

  static const Map<String, int> colors = {
    'PROGRAMMING': 0xFF6366F1,
    'WEB_DEVELOPMENT': 0xFF3B82F6,
    'MOBILE_DEVELOPMENT': 0xFF10B981,
    'DATA_SCIENCE': 0xFFF59E0B,
    'CYBERSECURITY': 0xFFEF4444,
    'DESIGN': 0xFFEC4899,
    'DEVOPS': 0xFF8B5CF6,
    'OTHER': 0xFF6B7280,
  };

  static String label(String category) => labels[category] ?? category;
  static int color(String category) => colors[category] ?? 0xFF6B7280;
}
