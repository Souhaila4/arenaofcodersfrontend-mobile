/// Hackathon idea from AI/n8n (for admin create flow)
class HackathonIdea {
  final String title;
  final int score;
  final String description;
  final String targetMarket;
  final String feasibility;

  HackathonIdea({
    required this.title,
    required this.score,
    required this.description,
    required this.targetMarket,
    required this.feasibility,
  });

  factory HackathonIdea.fromJson(Map<String, dynamic> json) {
    return HackathonIdea(
      title: (json['title'] as String?) ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
      description: (json['description'] as String?) ?? '',
      targetMarket: (json['target_market'] as String?) ?? '',
      feasibility: (json['feasibility'] as String?) ?? '',
    );
  }
}

/// Backend Specialty enum (must match API)
enum Specialty {
  FRONTEND,
  BACKEND,
  FULLSTACK,
  MOBILE,
  DATA,
  BI,
  CYBERSECURITY,
  DESIGN,
  DEVOPS;

  static Specialty? fromString(String? value) {
    if (value == null) return null;
    final upper = value.toUpperCase();
    for (final e in Specialty.values) {
      if (e.name == upper) return e;
    }
    return null;
  }

  String get displayName {
    switch (this) {
      case Specialty.FRONTEND:
        return 'Frontend';
      case Specialty.BACKEND:
        return 'Backend';
      case Specialty.FULLSTACK:
        return 'Fullstack';
      case Specialty.MOBILE:
        return 'Mobile';
      case Specialty.DATA:
        return 'Data';
      case Specialty.BI:
        return 'BI';
      case Specialty.CYBERSECURITY:
        return 'Cybersecurity';
      case Specialty.DESIGN:
        return 'Design';
      case Specialty.DEVOPS:
        return 'DevOps';
    }
  }
}

/// Competition (hackathon) from API
class Competition {
  final String id;
  final String title;
  final String description;
  final String difficulty;
  final String? specialty;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final double rewardPool;
  final int? maxParticipants;
  final bool isActive;
  final CompetitionCreator? creator;
  final int participantsCount;
  final bool antiCheatEnabled;
  final double? antiCheatThreshold;

  Competition({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    this.specialty,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.rewardPool = 0,
    this.maxParticipants,
    this.isActive = true,
    this.creator,
    this.participantsCount = 0,
    this.antiCheatEnabled = false,
    this.antiCheatThreshold,
  });

  factory Competition.fromJson(Map<String, dynamic> json) {
    final startRaw = json['startDate'];
    final endRaw = json['endDate'];
    return Competition(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      difficulty: (json['difficulty'] as String?) ?? 'MEDIUM',
      specialty: json['specialty'] as String?,
      startDate: startRaw != null ? DateTime.parse(startRaw.toString()) : DateTime.now(),
      endDate: endRaw != null ? DateTime.parse(endRaw.toString()) : DateTime.now(),
      status: (json['status'] as String?) ?? 'SCHEDULED',
      rewardPool: (json['rewardPool'] as num?)?.toDouble() ?? 0,
      maxParticipants: json['maxParticipants'] as int?,
      isActive: json['isActive'] as bool? ?? true,
      creator: json['creator'] != null
          ? CompetitionCreator.fromJson(json['creator'] as Map<String, dynamic>)
          : null,
      participantsCount: (json['_count'] as Map<String, dynamic>?)?['participants'] as int? ?? 0,
      antiCheatEnabled: json['antiCheatEnabled'] as bool? ?? false,
      antiCheatThreshold: (json['antiCheatThreshold'] as num?)?.toDouble(),
    );
  }

  String get difficultyDisplay {
    switch (difficulty.toUpperCase()) {
      case 'EASY':
        return 'Easy';
      case 'HARD':
        return 'Hard';
      default:
        return 'Medium';
    }
  }

  String get statusDisplay {
    switch (status.toUpperCase()) {
      case 'OPEN_FOR_ENTRY':
        return 'Open for entry';
      case 'SUBMISSION_CLOSED':
        return 'Submission closed';
      default:
        return status.replaceAll('_', ' ').toLowerCase();
    }
  }

  bool get canJoin => status.toUpperCase() == 'OPEN_FOR_ENTRY' || status.toUpperCase() == 'RUNNING';
}

class CompetitionCreator {
  final String id;
  final String firstName;
  final String lastName;
  final String? email;

  CompetitionCreator({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.email,
  });

  factory CompetitionCreator.fromJson(Map<String, dynamic> json) {
    return CompetitionCreator(
      id: json['id'] as String,
      firstName: (json['firstName'] as String?) ?? '',
      lastName: (json['lastName'] as String?) ?? '',
      email: json['email'] as String?,
    );
  }
}

class CompetitionsResponse {
  final List<Competition> data;
  final PaginationInfo pagination;

  CompetitionsResponse({required this.data, required this.pagination});

  factory CompetitionsResponse.fromJson(Map<String, dynamic> json) {
    return CompetitionsResponse(
      data: (json['data'] as List<dynamic>)
          .map((e) => Competition.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination: PaginationInfo.fromJson(json['pagination'] as Map<String, dynamic>),
    );
  }
}

class PaginationInfo {
  final int page;
  final int limit;
  final int totalCount;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;

  PaginationInfo({
    required this.page,
    required this.limit,
    required this.totalCount,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      page: json['page'] as int,
      limit: json['limit'] as int,
      totalCount: json['totalCount'] as int,
      totalPages: json['totalPages'] as int,
      hasNext: json['hasNext'] as bool,
      hasPrev: json['hasPrev'] as bool,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// CHECKPOINTS
// ─────────────────────────────────────────────────────────────────

/// Checkpoint for a competition (from GET /competitions/:id/checkpoints)
class CompetitionCheckpoint {
  final String id;
  final String competitionId;
  final String title;
  final String? description;
  final int order;
  final DateTime dueDate;
  final bool isMandatory;
  final DateTime createdAt;

  CompetitionCheckpoint({
    required this.id,
    required this.competitionId,
    required this.title,
    this.description,
    required this.order,
    required this.dueDate,
    this.isMandatory = true,
    required this.createdAt,
  });

  factory CompetitionCheckpoint.fromJson(Map<String, dynamic> json) {
    final dueRaw = json['dueDate'];
    final createdRaw = json['createdAt'];
    return CompetitionCheckpoint(
      id: json['id'] as String,
      competitionId: json['competitionId'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      order: (json['order'] as int?) ?? 0,
      dueDate: dueRaw != null ? DateTime.parse(dueRaw.toString()) : DateTime.now(),
      isMandatory: json['isMandatory'] as bool? ?? true,
      createdAt: createdRaw != null ? DateTime.parse(createdRaw.toString()) : DateTime.now(),
    );
  }
}

/// Checkpoint submission with nested checkpoint info (from GET my-checkpoint-submissions)
class CheckpointSubmissionWithCheckpoint {
  final String id;
  final String checkpointId;
  final String participantId;
  final String? proofUrl;
  final String? notes;
  final String status; // PENDING, SUBMITTED, APPROVED, REJECTED, MISSED
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final CheckpointInfo checkpoint;

  CheckpointSubmissionWithCheckpoint({
    required this.id,
    required this.checkpointId,
    required this.participantId,
    this.proofUrl,
    this.notes,
    required this.status,
    this.submittedAt,
    this.reviewedAt,
    required this.createdAt,
    required this.checkpoint,
  });

  factory CheckpointSubmissionWithCheckpoint.fromJson(Map<String, dynamic> json) {
    final cp = json['checkpoint'] as Map<String, dynamic>?;
    final dueRaw = cp?['dueDate'];
    return CheckpointSubmissionWithCheckpoint(
      id: json['id'] as String,
      checkpointId: json['checkpointId'] as String,
      participantId: json['participantId'] as String,
      proofUrl: json['proofUrl'] as String?,
      notes: json['notes'] as String?,
      status: (json['status'] as String?) ?? 'PENDING',
      submittedAt: json['submittedAt'] != null ? DateTime.parse(json['submittedAt'].toString()) : null,
      reviewedAt: json['reviewedAt'] != null ? DateTime.parse(json['reviewedAt'].toString()) : null,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'].toString()) : DateTime.now(),
      checkpoint: cp != null
          ? CheckpointInfo(
              id: cp['id'] as String,
              title: cp['title'] as String,
              description: cp['description'] as String?,
              order: (cp['order'] as int?) ?? 0,
              dueDate: dueRaw != null ? DateTime.parse(dueRaw.toString()) : DateTime.now(),
              isMandatory: cp['isMandatory'] as bool? ?? true,
            )
          : CheckpointInfo(
              id: json['checkpointId'] as String,
              title: '',
              order: 0,
              dueDate: DateTime.now(),
            ),
    );
  }

  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isSubmitted => status.toUpperCase() == 'SUBMITTED';
  bool get isApproved => status.toUpperCase() == 'APPROVED';
  bool get isRejected => status.toUpperCase() == 'REJECTED';
  bool get isMissed => status.toUpperCase() == 'MISSED';

  /// Submission is allowed only during the 15-min window: [opensAt, dueDate].
  bool get canSubmit {
    if (!isPending) return false;
    final now = DateTime.now();
    return !now.isBefore(checkpoint.opensAt) && now.isBefore(checkpoint.dueDate);
  }

  /// Window has not opened yet (before opensAt).
  bool get notYetOpen =>
      isPending && DateTime.now().isBefore(checkpoint.opensAt);

  /// Window has closed (after dueDate) but still PENDING (will become MISSED).
  bool get windowClosed =>
      isPending && !DateTime.now().isBefore(checkpoint.dueDate);

  String get statusDisplay {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'Pending';
      case 'SUBMITTED':
        return 'Submitted';
      case 'APPROVED':
        return 'Approved';
      case 'REJECTED':
        return 'Rejected';
      case 'MISSED':
        return 'Missed';
      default:
        return status;
    }
  }
}

/// Minimal checkpoint info nested in a submission
class CheckpointInfo {
  final String id;
  final String title;
  final String? description;
  final int order;
  final DateTime dueDate;
  final bool isMandatory;

  /// Submission window length in minutes (must match backend constant).
  static const int submissionWindowMinutes = 15;

  CheckpointInfo({
    required this.id,
    required this.title,
    this.description,
    required this.order,
    required this.dueDate,
    this.isMandatory = true,
  });

  /// When the submission window opens (dueDate minus window length).
  DateTime get opensAt =>
      dueDate.subtract(Duration(minutes: submissionWindowMinutes));
}
