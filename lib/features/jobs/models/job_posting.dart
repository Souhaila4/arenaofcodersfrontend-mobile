/// Job listing shown to candidates (sample data until a jobs API exists).
class JobPosting {
  final String id;
  final String title;
  final String company;
  final String description;
  final String? location;

  const JobPosting({
    required this.id,
    required this.title,
    required this.company,
    required this.description,
    this.location,
  });
}
