/// Offre d'emploi publiée par une entreprise (COMPANY).
class JobPosting {
  final String id;
  final String title;
  final String description;
  final String targetSpecialty;
  final String? location;
  final String companyName;
  final String createdBy;
  final bool isActive;
  final DateTime createdAt;

  const JobPosting({
    required this.id,
    required this.title,
    required this.description,
    required this.targetSpecialty,
    this.location,
    required this.companyName,
    required this.createdBy,
    this.isActive = true,
    required this.createdAt,
  });

  factory JobPosting.fromJson(Map<String, dynamic> json) => JobPosting(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        targetSpecialty: json['targetSpecialty'] as String? ?? '',
        location: json['location'] as String?,
        companyName: json['companyName'] as String? ?? '',
        createdBy: json['createdBy'] as String? ?? '',
        isActive: json['isActive'] as bool? ?? true,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );
}
