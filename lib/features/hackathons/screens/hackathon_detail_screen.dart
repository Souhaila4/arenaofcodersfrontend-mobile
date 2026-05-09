import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:arena/core/models/competition_model.dart';
import 'package:arena/core/models/auth_models.dart';
import 'package:arena/core/services/api_service.dart';
import 'package:arena/core/services/storage_service.dart';
import 'package:arena/core/theme/app_theme.dart';
import 'package:arena/features/hackathons/screens/submit_checkpoint_screen.dart';
import 'package:arena/features/profile/screens/public_profile_screen.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart' as stream;
import 'package:arena/features/chat/screens/chat_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'admin_participants_screen.dart';
import 'package:arena/features/hackathons/widgets/team_synergy_widget.dart';

class HackathonDetailScreen extends StatefulWidget {
  final String competitionId;

  const HackathonDetailScreen({super.key, required this.competitionId});

  @override
  State<HackathonDetailScreen> createState() => _HackathonDetailScreenState();
}

class _HackathonDetailScreenState extends State<HackathonDetailScreen> {
  final _api = ApiService();
  Competition? _competition;
  bool _loading = true;
  String? _error;
  bool _joining = false;
  bool _joined = false;
  AuthUser? _user;

  // --- Equipe (Team) ---
  Map<String, dynamic>? _myEquipe;
  String? _myRole; // LEADER or MEMBER
  bool _loadingEquipe = false;
  bool _creatingTeam = false;

  // --- Participant status ---
  String _participantStatus = 'JOINED';
  bool _isWinner = false;

  // --- Final Submission ---
  final _githubUrlCtrl = TextEditingController();
  bool _submittingFinal = false;
  bool _finalSubmitted = false;
  String? _finalGithubUrl;
  Map<String, dynamic>? _finalResult;
  Timer? _scoringPollingTimer;

  List<CheckpointSubmissionWithCheckpoint> _checkpointSubmissions = [];
  bool _loadingCheckpoints = false;
  @override
  void initState() {
    super.initState();
    _loadUser();
    _load();
  }

  @override
  void dispose() {
    _scoringPollingTimer?.cancel();
    _githubUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    try {
      final u = await _api.getMe();
      if (mounted) setState(() => _user = u);
    } catch (_) {}
  }

  void _startPollingScore() {
    if (_scoringPollingTimer != null && _scoringPollingTimer!.isActive) return;
    _scoringPollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      try {
        final details = await _api.getParticipationDetails(widget.competitionId);
        if (details != null) {
          final score = details['score'];
          final report = details['scoringReport'];
          final status = details['status'] as String? ?? 'JOINED';
          
          if (score != null || report != null || status == 'DISQUALIFIED') {
            timer.cancel();
            if (mounted) {
              setState(() {
                _participantStatus = status;
                if (score != null || report != null) {
                  _finalResult = {
                    if (score != null) 'score': score,
                    if (report is Map) ...report,
                  };
                }
              });
            }
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final c = await _api.getCompetitionById(widget.competitionId);

      bool alreadyJoined = false;
      try {
        alreadyJoined = await _api.checkMyParticipation(widget.competitionId);
        if (alreadyJoined) {
          try {
            final details = await _api.getParticipationDetails(widget.competitionId);
            if (details != null) {
              _participantStatus = details['status'] as String? ?? 'JOINED';
              _isWinner = details['isWinner'] as bool? ?? false;
              // Vérifier si déjà soumis
              final submittedUrl = details['githubUrl'] as String?;
              if (submittedUrl != null && submittedUrl.isNotEmpty) {
                _finalSubmitted = true;
                _finalGithubUrl = submittedUrl;
                _githubUrlCtrl.text = submittedUrl;
                // Charger score et rapport depuis la participation
                final score = details['score'];
                final report = details['scoringReport'];
                if (score != null || report != null) {
                  _finalResult = {
                    if (score != null) 'score': score,
                    if (report is Map) ...report,
                  };
                } else {
                  // Already submitted but no score yet -> start polling
                  _startPollingScore();
                }
              }
            }
          } catch (_) {}
        }
      } catch (_) {}

      if (mounted) setState(() {
        _competition = c;
        _joined = alreadyJoined;
        _loading = false;
      });

      // Load equipe info
      _loadEquipe();

      if (alreadyJoined) {
        _loadCheckpointSubmissions();
      }
    } on ApiError catch (e) {
      if (e.statusCode == 401 && mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/signin', (route) => false);
        return;
      }
      if (mounted) setState(() {
        if (e.statusCode == 404) {
          _error = 'HACKATHON_DELETED';
        } else {
          _error = e.displayMessage;
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _error = 'Erreur de connexion';
        _loading = false;
      });
    }
  }

  Future<void> _loadEquipe() async {
    setState(() => _loadingEquipe = true);
    try {
      final equipe = await _api.getMyEquipe(widget.competitionId);
      if (mounted) setState(() {
        _myEquipe = equipe;
        _myRole = equipe?['myRole'] as String?;
        _loadingEquipe = false;
        // If user has equipe, they are "joined"
        if (equipe != null) _joined = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingEquipe = false);
    }
  }

  Future<void> _loadCheckpointSubmissions() async {
    if (!mounted) return;
    setState(() => _loadingCheckpoints = true);
    try {
      final list = await _api.getMyCheckpointSubmissions(widget.competitionId);
      if (mounted) setState(() {
        _checkpointSubmissions = list;
        _loadingCheckpoints = false;

        // Auto-fill final GitHub URL from the first valid checkpoint submission
        if (_githubUrlCtrl.text.isEmpty && list.isNotEmpty) {
          try {
            final firstValid = list.firstWhere(
              (s) => s.proofUrl != null && s.proofUrl!.isNotEmpty,
            );
            _githubUrlCtrl.text = firstValid.proofUrl!;
          } catch (_) {
            // No valid proofUrl found, keep empty
          }
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loadingCheckpoints = false);
    }
  }

  // ─── Create Team ───
  Future<void> _showCreateTeamDialog() async {
    // 1. Prendre une photo obligatoirement avant !
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 70,
    );

    if (image == null) return; // Annulé

    // Copier l'image vers un emplacement permanent pour éviter la suppression de cache
    final dir = await getApplicationDocumentsDirectory();
    final ext = image.name.split('.').last;
    final permanentPath = '${dir.path}/face_image_${widget.competitionId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await File(image.path).copy(permanentPath);

    // Sauvegarder l'image localement pour l'anti-triche du Checkpoint
    final storage = StorageService();
    await storage.saveData('face_image_${widget.competitionId}', permanentPath);

    // 2. Demander le nom de l'équipe
    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A2332),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.groups, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Créer une équipe', style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Créez votre équipe pour ce hackathon. Vous serez le leader et pourrez inviter des membres.',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Nom de l\'équipe',
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  prefixIcon: const Icon(Icons.edit, color: AppColors.primary, size: 20),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.length >= 2) {
                  Navigator.pop(ctx, name);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Créer'),
            ),
          ],
        );
      },
    );

    if (result == null || result.isEmpty) return;

    setState(() => _creatingTeam = true);
    try {
      await _api.createEquipe(name: result, competitionId: widget.competitionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Équipe créée avec succès ! Vous êtes le leader.'),
            backgroundColor: Colors.green,
          ),
        );
        _load(); // Reload everything
      }
    } on ApiError catch (e) {
      if (mounted) {
        setState(() => _creatingTeam = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.displayMessage), backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _creatingTeam = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la création'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /**
   * RECHERCHE ET INVITATION D'UN MEMBRE
   * 
   * Affiche une BottomSheet permettant au Leader de l'équipe de chercher un utilisateur.
   * La recherche se fait via l'API NestJS (`searchUsersForTeam`), qui filtre 
   * par spécialité (ex: FRONTEND) et/ou par texte (nom/email).
   * 
   * Lorsqu'il clique sur "Inviter", la requête est envoyée au serveur.
   */
  Future<void> _showInviteDialog() async {
    if (_myEquipe == null) return;
    final equipeId = _myEquipe!['id'] as String;
    final searchController = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    bool searching = false;
    String? selectedSpecialty;
    
    // All specialties from Prisma Schema
    final specialties = [
      'FRONTEND', 'BACKEND', 'FULLSTACK', 
      'MOBILE', 'DATA', 'BI', 
      'CYBERSECURITY', 'DESIGN', 'DEVOPS'
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F141C), // Matching dark background
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> performSearch() async {
              final val = searchController.text.trim();
              if (val.length < 2 && selectedSpecialty == null) {
                setModalState(() => searchResults = []);
                return;
              }
              setModalState(() => searching = true);
              try {
                final results = await _api.searchUsersForTeam(
                  val.isEmpty ? null : val,
                  competitionId: widget.competitionId,
                  specialty: selectedSpecialty,
                );
                if (mounted) {
                  setModalState(() {
                    searchResults = results;
                    searching = false;
                  });
                }
              } catch (_) {
                if (mounted) setModalState(() => searching = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade700,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.person_add, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('Inviter un membre', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: specialties.map((spec) {
                      final isSelected = selectedSpecialty == spec;
                      // Display text format (e.g. "FRONTEND" -> "Frontend")
                      final displaySpec = spec == 'BI' || spec == 'DEVOPS' || spec == 'UI/UX'
                          ? spec
                          : spec[0] + spec.substring(1).toLowerCase();

                      return GestureDetector(
                        onTap: () {
                          setModalState(() => selectedSpecialty = isSelected ? null : spec);
                          performSearch();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF152A38) : const Color(0xFF1A2332),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF00E5FF) : Colors.transparent,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected) ...[
                                const Icon(Icons.check, size: 14, color: Color(0xFF00E5FF)),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                displaySpec,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isSelected ? const Color(0xFF00E5FF) : Colors.grey.shade300,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Nom ou email...',
                      hintStyle: TextStyle(color: Colors.grey.shade600),
                      prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                      suffixIcon: searching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) => performSearch(),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.35),
                    child: searchResults.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                searchController.text.trim().length < 2 && selectedSpecialty == null
                                    ? 'Tapez au moins 2 caractères ou choisissez une spécialité'
                                    : 'Aucun utilisateur trouvé',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: searchResults.length,
                            itemBuilder: (_, i) {
                              final user = searchResults[i];
                              final uName = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
                              final uEmail = user['email'] as String? ?? '';
                              final uAvatar = user['avatarUrl'] as String?;

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primary.withAlpha(40),
                                  backgroundImage: (uAvatar != null && uAvatar.isNotEmpty)
                                      ? NetworkImage('${ApiService.baseUrl}$uAvatar')
                                      : null,
                                  child: (uAvatar == null || uAvatar.isEmpty)
                                      ? const Icon(Icons.person, color: AppColors.primary, size: 20)
                                      : null,
                                ),
                                title: Text(uName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                subtitle: Text(uEmail, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                trailing: SizedBox(
                                  height: 34,
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      try {
                                        await _api.inviteToEquipe(equipeId, uEmail);
                                        if (mounted) {
                                          Navigator.pop(ctx);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('✅ Invitation envoyée à $uName'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                          _loadEquipe();
                                        }
                                      } on ApiError catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text(e.displayMessage), backgroundColor: Colors.red),
                                          );
                                        }
                                      } catch (_) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Erreur'), backgroundColor: Colors.red),
                                          );
                                        }
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      elevation: 0,
                                    ),
                                    child: const Text('Inviter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── Join via face photo (for direct join without team) ───
  Future<void> _joinWithFacePhoto() async {
    if (_competition == null || !_competition!.canJoin) return;

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 70,
    );

    if (image == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Une photo personnelle est obligatoire pour rejoindre ce hackathon (Anti-Triche).'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _joining = true);
    try {
      await _api.joinCompetition(widget.competitionId, File(image.path));
      if (mounted) setState(() {
        _joined = true;
        _joining = false;
      });
      _loadCheckpointSubmissions();
    } on ApiError catch (e) {
      if (mounted) setState(() => _joining = false);
      if (e.statusCode == 409) {
        setState(() => _joined = true);
        return;
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.displayMessage), backgroundColor: Colors.red),
      );
    } catch (_) {
      if (mounted) setState(() => _joining = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Échec de l\'inscription'), backgroundColor: Colors.red),
      );
    }
  }

  // ─── Open Team Chat ───
  Future<void> _openTeamChat() async {
    if (_myEquipe == null || _user == null) return;

    final equipeId = _myEquipe!['id'] as String;
    final competitionId = widget.competitionId;
    final teamName = _myEquipe!['name'] as String? ?? 'Mon Équipe';

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );

      // Get Stream token
      final streamData = await _api.getStreamToken();
      final apiKey = streamData['apiKey'] as String;
      final token = streamData['token'] as String;

      // Join team chat channel
      await _api.joinTeamChat(equipeId, competitionId);

      // Connect to Stream
      final client = stream.StreamChatClient(apiKey);
      await client.connectUser(
        stream.User(id: _user!.id, name: '${_user!.firstName} ${_user!.lastName}'.trim()),
        token,
      );

      // Channel ID matches backend: team-{equipeId}-comp-{competitionId}
      final channelId = 'team-$equipeId-comp-$competitionId';
      final channel = client.channel('messaging', id: channelId);
      await channel.watch();

      if (mounted) Navigator.of(context).pop(); // dismiss loading

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => stream.StreamChat(
              client: client,
              child: stream.StreamChannel(
                channel: channel,
                child: Navigator(
                  onGenerateRoute: (settings) => MaterialPageRoute(
                    builder: (innerContext) => ChatScreen(
                      roomId: channelId,
                      roomName: '💬 $teamName',
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'ouverture du chat'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ─── Mark Team Ready ───
  Future<void> _markReady() async {
    if (_myEquipe == null) return;
    try {
      await _api.markTeamReady(_myEquipe!['id'] as String);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Équipe marquée comme prête !'), backgroundColor: Colors.green),
        );
        _loadEquipe();
      }
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.displayMessage), backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ─── Remove Team Member ───
  Future<void> _removeMember(String memberUserId, String memberName) async {
    if (_myEquipe == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirer un membre'),
        content: Text('Voulez-vous vraiment retirer $memberName de votre équipe ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retirer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _api.removeTeamMember(_myEquipe!['id'] as String, memberUserId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ $memberName a été retiré de l\'équipe'), backgroundColor: Colors.green),
        );
        _loadEquipe();
      }
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.displayMessage), backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors du retrait du membre'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0B1121), Color(0xFF0F141C), Color(0xFF0B0E14)],
                )
              : null,
          color: isDark ? null : AppColors.backgroundLight,
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _error != null
                  ? _buildErrorView(isDark)
                  : _competition == null
                      ? const SizedBox.shrink()
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: AppColors.primary,
                          child: CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                                child: Row(
                                  children: [
                                    IconButton(
                                      onPressed: () => Navigator.of(context).pop(),
                                      icon: Icon(Icons.arrow_back, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                                    ),
                                    const Expanded(
                                      child: Text(
                                        'Hackathon',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    const SizedBox(width: 48),
                                  ],
                                ),
                              ),
                            ),
                            if (_isWinner)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade400,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(color: Colors.amber.withAlpha(50), blurRadius: 10, spreadRadius: 2),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Row(
                                          children: [
                                            Text('🏆', style: TextStyle(fontSize: 28)),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                'Félicitations, vous avez gagné !',
                                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          "Vous avez été sélectionné comme le gagnant de ce hackathon.",
                                          style: TextStyle(fontSize: 14, color: Colors.black.withAlpha(180)),
                                        ),
                                        if (_competition?.creator?.id != null) ...[
                                          const SizedBox(height: 12),
                                          SizedBox(
                                            height: 38,
                                            child: OutlinedButton.icon(
                                              onPressed: () {
                                                Navigator.push(context, MaterialPageRoute(
                                                  builder: (_) => PublicProfileScreen(userId: _competition!.creator!.id),
                                                ));
                                              },
                                              icon: const Icon(Icons.person, size: 16),
                                              label: const Text("Voir le profil de l'organisateur"),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.black87,
                                                side: BorderSide(color: Colors.amber.shade700),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        _chip(_competition!.difficultyDisplay, _diffColor()),
                                        if (_competition!.specialty != null) ...[
                                          const SizedBox(width: 8),
                                          _chip(_competition!.specialty!, AppColors.primary),
                                        ],
                                        const Spacer(),
                                        Text(
                                          _competition!.statusDisplay,
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _competition!.title,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : AppColors.textLightPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _competition!.description,
                                      style: TextStyle(
                                        fontSize: 15,
                                        height: 1.5,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    _infoRow(Icons.calendar_today, '${_formatDate(_competition!.startDate)} – ${_formatDate(_competition!.endDate)}'),
                                    if (_competition!.rewardPool > 0)
                                      _infoRow(Icons.emoji_events, 'Prix : \$${_competition!.rewardPool.toStringAsFixed(0)}'),
                                    if (_competition!.maxParticipants != null)
                                      _infoRow(Icons.people_outline, 'Max ${_competition!.maxParticipants} participants'),
                                    if (_competition!.participantsCount > 0)
                                      _infoRow(Icons.people, '${_competition!.participantsCount} inscrits'),
                                    const SizedBox(height: 24),

                                    // ─── TEAM SECTION (USER role) ───
                                    if (_user?.role == 'USER') ...[
                                      _buildTeamSection(isDark),
                                      // AI Team Synergy Predictor
                                      if (_myEquipe != null && (_myEquipe!['members'] as List<dynamic>? ?? []).length >= 2)
                                        TeamSynergyWidget(
                                          equipeId: _myEquipe!['id'] as String,
                                          isLeader: _myRole == 'LEADER',
                                        ),
                                      if (_joined) ...[
                                        if (_myEquipe?['status'] == 'READY') ...[
                                          const SizedBox(height: 24),
                                          _buildCheckpointsSection(isDark),
                                          const SizedBox(height: 24),
                                          _buildFinalSubmitSection(isDark),
                                        ] else ...[
                                          const SizedBox(height: 24),
                                          Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withAlpha(20),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: Colors.orange.withAlpha(50)),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.lock, color: Colors.orange, size: 20),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    'Votre équipe n\'est pas encore prête. Les checkpoints et la soumission finale seront débloqués lorsque le leader marquera l\'équipe comme prête (ou si elle est complète).',
                                                    style: TextStyle(fontSize: 13, color: Colors.orange.shade300, height: 1.4),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ]
                                      ],
                                    ],

                                    // Admin/Company: view participants button
                                    if (_user?.role == 'ADMIN' || _user?.role == 'COMPANY') ...[
                                      const SizedBox(height: 24),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 48,
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => AdminParticipantsScreen(
                                                  competitionId: widget.competitionId,
                                                  competitionTitle: _competition!.title,
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.people, color: AppColors.primary),
                                          label: const Text(
                                            'Voir les participants',
                                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: AppColors.primary),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                          ),
                                        ),
                                      ),
                                      ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
        ),
      );
  }

  // ═══════════════════════════════════════════════════════════════
  // TEAM SECTION
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTeamSection(bool isDark) {
    // If loading equipe
    if (_loadingEquipe) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(20),
        child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
      ));
    }

    // If user has NO team
    if (_myEquipe == null) {
      return _buildNoTeamSection(isDark);
    }

    // If user HAS a team
    return _buildTeamDetailsSection(isDark);
  }

  Widget _buildNoTeamSection(bool isDark) {
    final canJoin = _competition?.canJoin ?? false;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Mon Équipe',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textLightPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Vous n\'avez pas encore d\'équipe pour ce hackathon. Créez une équipe pour participer et invitez vos coéquipiers !',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
          if (canJoin) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withAlpha(50)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pour créer et diriger une équipe, vous devez prendre une photo (Anti-Triche).',
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade300),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _creatingTeam ? null : _showCreateTeamDialog,
                icon: _creatingTeam
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.camera_alt, size: 20),
                label: Text(_creatingTeam ? 'Création en cours...' : 'Créer une équipe (Photo requise)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  _competition!.statusDisplay,
                  style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTeamDetailsSection(bool isDark) {
    final teamName = _myEquipe!['name'] as String? ?? 'Mon Équipe';
    final status = _myEquipe!['status'] as String? ?? 'FORMING';
    final members = (_myEquipe!['members'] as List<dynamic>?) ?? [];
    final invitations = ((_myEquipe!['invitations'] as List<dynamic>?) ?? [])
        .where((inv) => inv['status'] == 'PENDING').toList();
    final isLeader = _myRole == 'LEADER';

    Color statusColor;
    String statusText;
    switch (status.toUpperCase()) {
      case 'READY':
        statusColor = Colors.green;
        statusText = 'Prête';
        break;
      case 'DISQUALIFIED':
        statusColor = Colors.red;
        statusText = 'Disqualifiée';
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'En formation';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(60)),
        boxShadow: isDark ? [BoxShadow(color: AppColors.primary.withAlpha(10), blurRadius: 10)] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF2563EB)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.groups, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(teamName, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.textLightPrimary)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withAlpha(80)),
                          ),
                          child: Text(statusText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
                        ),
                        const SizedBox(width: 8),
                        if (isLeader)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.amber.withAlpha(30),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.amber.withAlpha(80)),
                            ),
                            child: const Text('👑 Leader', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.amber)),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Membre', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Members list
          Text('Membres (${members.length})', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade400)),
          const SizedBox(height: 8),
          ...members.map((m) {
            final user = m['user'] as Map<String, dynamic>? ?? {};
            final role = m['role'] as String? ?? 'MEMBER';
            final name = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
            final email = user['email'] as String? ?? '';
            final avatar = user['avatarUrl'] as String?;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withAlpha(40) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primary.withAlpha(30),
                      backgroundImage: (avatar != null && avatar.isNotEmpty) ? NetworkImage('${ApiService.baseUrl}$avatar') : null,
                      child: (avatar == null || avatar.isEmpty) ? const Icon(Icons.person, size: 18, color: AppColors.primary) : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textLightPrimary)),
                          Text(email, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                    if (role == 'LEADER')
                      const Text('👑', style: TextStyle(fontSize: 16))
                    else if (isLeader)
                      IconButton(
                        icon: const Icon(Icons.person_remove, size: 18, color: Colors.redAccent),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _removeMember(user['id'] as String, name),
                      ),
                  ],
                ),
              ),
            );
          }),

          // Pending invitations (Hide if group is already full at 6 members)
          if (invitations.isNotEmpty && isLeader && members.length < 6) ...[
            const SizedBox(height: 12),
            Text('Invitations en attente (${invitations.length})', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.orange.shade400)),
            const SizedBox(height: 6),
            ...invitations.map((inv) {
              final invitee = inv['invitee'] as Map<String, dynamic>? ?? {};
              final iName = '${invitee['firstName'] ?? ''} ${invitee['lastName'] ?? ''}'.trim();
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_bottom, size: 14, color: Colors.orange.shade400),
                    const SizedBox(width: 8),
                    Expanded(child: Text(iName, style: TextStyle(fontSize: 13, color: Colors.orange.shade400))),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              // Team Chat button
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _openTeamChat,
                    icon: const Icon(Icons.forum, size: 18),
                    label: const Text('Chat', style: TextStyle(fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accentCyan,
                      side: const BorderSide(color: AppColors.accentCyan),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              if (isLeader && members.length < 6) ...[
                const SizedBox(width: 8),
                // Invite button
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _showInviteDialog,
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text('Inviter', style: TextStyle(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),

          // Mark Ready button (leader only, FORMING status)
          if (isLeader && status.toUpperCase() == 'FORMING') ...[
            const SizedBox(height: 10),
            if (members.length >= 4)
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _markReady,
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Marquer l\'équipe prête', style: TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withAlpha(50)),
                ),
                child: const Column(
                  children: [
                    Text('Équipe incomplète', 
                      style: TextStyle(color: Colors.orange, fontSize: 14, fontWeight: FontWeight.bold)
                    ),
                    SizedBox(height: 4),
                    Text('Il faut au minimum 4 personnes (leader + 3 membres) pour participer. (Max 6)', 
                      textAlign: TextAlign.center, 
                      style: TextStyle(color: Colors.orange, fontSize: 12)
                    ),
                  ],
                ),
              ),
          ],

          // Info for non-leader (REMOVED as requested by user)
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // CHECKPOINTS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildCheckpointsSection(bool isDark) {
    final isLeader = _myEquipe == null || _myRole == 'LEADER';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Checkpoints',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.textLightPrimary,
                  ),
                ),
              ),
              if (!_loadingCheckpoints)
                IconButton(
                  onPressed: _loadCheckpointSubmissions,
                  icon: const Icon(Icons.refresh, size: 20, color: AppColors.primary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Rafraîchir',
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isLeader
                ? 'En tant que leader, vous validez les checkpoints pour toute l\'équipe.'
                : 'Votre leader valide les checkpoints pour toute l\'équipe automatiquement.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
          if (_loadingCheckpoints) ...[
            const SizedBox(height: 16),
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
              ),
            ),
          ] else if (_checkpointSubmissions.isEmpty) ...[
            const SizedBox(height: 16),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _myEquipe == null 
                    ? 'Formez une équipe pour voir vos checkpoints'
                    : 'En attente de l\'initialisation des checkpoints équipe',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            ..._checkpointSubmissions.map((sub) => _buildCheckpointSubmissionTile(isDark, sub, isLeader)),
          ],
        ],
      ),
    );
  }

  Widget _buildCheckpointSubmissionTile(bool isDark, CheckpointSubmissionWithCheckpoint sub, bool isLeader) {
    // Heuristic: If it's missed but we are a member, it might be a sync issue.
    // We treat APPROVED and SUBMITTED as orange/green.
    final statusColor = sub.isApproved
        ? Colors.green
        : sub.isRejected
            ? Colors.red
            : sub.isSubmitted
                ? Colors.orange
                : sub.isMissed 
                   ? (isLeader ? Colors.red : Colors.grey.shade600) // Gray for members if missed (less scary)
                   : AppColors.primary;

    final displayStatus = (sub.isMissed && !isLeader) 
        ? "En attente du leader" 
        : sub.statusDisplay;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.black26 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withAlpha(40)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    sub.checkpoint.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.textLightPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(35),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withAlpha(80)),
                  ),
                  child: Text(
                    displayStatus,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  'Échéance ${_formatDate(sub.checkpoint.dueDate)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
            Row(
              children: [
                Icon(Icons.lock_open, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Ouvre ${_formatDateTime(sub.checkpoint.opensAt)} · Ferme ${_formatDateTime(sub.checkpoint.dueDate)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ),
              ],
            ),
            if (isLeader && (sub.isSubmitted || sub.isApproved) && sub.proofUrl != null && sub.proofUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.link, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      sub.proofUrl!,
                      style: const TextStyle(fontSize: 12, color: AppColors.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (!sub.isSubmitted && !sub.isApproved) ...[
              if (sub.proofUrl != null && sub.proofUrl!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.link, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        sub.proofUrl!,
                        style: const TextStyle(fontSize: 12, color: AppColors.primary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              // Only leader can submit checkpoints
              if (sub.canSubmit && isLeader) ...[
                if (_myEquipe != null && _myEquipe!['status'] == 'READY') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withAlpha(80)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.timer, size: 16, color: Colors.green.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _CountdownText(
                            targetDate: sub.checkpoint.dueDate,
                            prefix: 'Temps restant : ',
                            style: TextStyle(fontSize: 12, color: Colors.green.shade600, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: OutlinedButton(
                      onPressed: () async {
                        final result = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => SubmitCheckpointScreen(
                              competitionId: widget.competitionId,
                              checkpointId: sub.checkpointId,
                              checkpointTitle: sub.checkpoint.title,
                              dueDate: sub.checkpoint.dueDate,
                              opensAt: sub.checkpoint.opensAt,
                              initialSubmission: sub,
                              isLeader: isLeader,
                              onSubmitted: _loadCheckpointSubmissions,
                            ),
                          ),
                        );
                        if (result == true && mounted) _loadCheckpointSubmissions();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Soumettre pour l\'équipe', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withAlpha(80)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Action requise : Formez une équipe complète (4 à 6 personnes) et marquez-la comme "Prête" dans l\'onglet Équipe pour débloquer la validation.',
                            style: TextStyle(fontSize: 12, color: Colors.orange.shade700, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ] else if (sub.canSubmit && !isLeader) ...[
                // Hiding the "Seul le leader peut valider" message as requested
              ] else if (sub.notYetOpen) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _CountdownText(
                          targetDate: sub.checkpoint.opensAt,
                          prefix: 'S\'ouvre dans : ',
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade700, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (sub.windowClosed) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock, size: 16, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Fenêtre de soumission fermée',
                        style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FINAL SUBMISSION
  // ═══════════════════════════════════════════════════════════════

  Future<void> _submitFinalProject() async {
    final url = _githubUrlCtrl.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer l\'URL de votre dépôt GitHub'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Validation basique de l'URL GitHub
    if (!url.toLowerCase().contains('github.com')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('L\'URL doit être un lien GitHub valide'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    String finalUrl = url;
    if (!finalUrl.startsWith('http')) {
      finalUrl = 'https://$finalUrl';
    }

    setState(() => _submittingFinal = true);
    try {
      final result = await _api.submitGithubLink(widget.competitionId, finalUrl);
      if (mounted) {
        setState(() {
          _submittingFinal = false;
          _finalSubmitted = true;
          _finalGithubUrl = finalUrl;
          _finalResult = result;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Projet soumis avec succès ! L\'évaluation IA est en cours.'),
            backgroundColor: Colors.green,
          ),
        );
        // Start polling the API to wait for the background AI evaluation to complete
        _startPollingScore();
      }
    } on ApiError catch (e) {
      if (mounted) {
        setState(() => _submittingFinal = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.displayMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submittingFinal = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildScoreRow(String label, dynamic value, bool isDark) {
    final val = value is num ? value.toStringAsFixed(2) : '—';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
          Text(
            val,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalSubmitSection(bool isDark) {
    final isLeader = _myEquipe == null || _myRole == 'LEADER';
    final competitionEnded = _competition != null && _competition!.endDate.isBefore(DateTime.now());

    // ─── Fenêtre de soumission : 20 minutes avant la fin (synchro backend) ───
    final endDate = _competition!.endDate;
    final submissionOpensAt = endDate.subtract(const Duration(minutes: 20));
    final now = DateTime.now();
    final isSubmissionWindowOpen = now.isAfter(submissionOpensAt) || _finalSubmitted;
    final timeUntilOpen = submissionOpensAt.difference(now);
    final antiCheatEnabled = _competition!.antiCheatEnabled;
    final antiCheatThreshold = _competition!.antiCheatThreshold ?? 70;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _finalSubmitted
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF0B2E1A), const Color(0xFF0F141C)]
                    : [Colors.green.shade50, Colors.white],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF1A1040), const Color(0xFF0F141C)]
                    : [const Color(0xFFF3F0FF), Colors.white],
              ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _finalSubmitted
              ? Colors.green.withAlpha(80)
              : const Color(0xFF7C3AED).withAlpha(60),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (_finalSubmitted ? Colors.green : const Color(0xFF7C3AED)).withAlpha(15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _finalSubmitted
                      ? Colors.green.withAlpha(30)
                      : const Color(0xFF7C3AED).withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _finalSubmitted ? Icons.check_circle : Icons.rocket_launch,
                  color: _finalSubmitted ? Colors.green : const Color(0xFF7C3AED),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _finalSubmitted ? 'Projet Soumis ✅' : 'Soumission Finale',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textLightPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _finalSubmitted
                          ? 'L\'évaluation IA est en cours'
                          : !isSubmissionWindowOpen
                              ? 'S\'ouvre 20 min avant la fin du hackathon'
                              : antiCheatEnabled
                                  ? 'Anti-Triche IA activé 🛡️'
                                  : 'Soumettez votre dépôt GitHub final',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ─── VERROUILLÉ : pas encore dans la fenêtre de 30 min ───
          if (!isSubmissionWindowOpen) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.withAlpha(40)),
              ),
              child: Column(
                children: [
                  Icon(Icons.lock_clock, size: 40, color: Colors.grey.shade500),
                  const SizedBox(height: 12),
                  Text(
                    'Soumission verrouillée',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'La soumission finale s\'ouvre 20 minutes avant la fin du hackathon.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500, height: 1.4),
                  ),
                  if (antiCheatEnabled) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withAlpha(40)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shield, size: 14, color: Colors.red),
                          const SizedBox(width: 6),
                          Text(
                            'Anti-Triche IA actif (seuil : ${antiCheatThreshold.toStringAsFixed(0)}%)',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  // Countdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF7C3AED).withAlpha(50)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer, size: 16, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 8),
                        _CountdownText(
                          targetDate: submissionOpensAt,
                          prefix: 'S\'ouvre dans : ',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ]
          // Si déjà soumis — afficher le résumé
          else if (_finalSubmitted) ...[
            // GitHub URL soumis
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withAlpha(50)),
              ),
              child: Row(
                children: [
                  Icon(Icons.link, size: 16, color: Colors.green.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _finalGithubUrl ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Score & Rapport IA
            if (_finalResult != null && _finalResult!['score'] != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF1A1040), const Color(0xFF0F141C)]
                        : [const Color(0xFFF3E8FF), Colors.white],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF7C3AED).withAlpha(60)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.stars_rounded, size: 22, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Score Final : ${(_finalResult!['score'] as num).toStringAsFixed(1)} / 100',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF1A1040),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Breakdown details
                    if (_finalResult!['breakdown'] != null) ...[
                      const SizedBox(height: 14),
                      _buildScoreRow('Complexité', _finalResult!['breakdown']['complexityWeighted'], isDark),
                      _buildScoreRow('Innovation', _finalResult!['breakdown']['innovationWeighted'], isDark),
                      _buildScoreRow('Impact', _finalResult!['breakdown']['impactWeighted'], isDark),
                      _buildScoreRow('Qualité', _finalResult!['breakdown']['qualityWeighted'], isDark),
                      if (_finalResult!['breakdown']['penalty'] != null && (_finalResult!['breakdown']['penalty'] as num) > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.warning_amber, size: 14, color: Colors.red),
                            const SizedBox(width: 6),
                            Text(
                              'Pénalité Anti-Triche : -${_finalResult!['breakdown']['penalty']}%',
                              style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ],
                    // Highlights & Warnings
                    if (_finalResult!['report'] != null) ...[
                      const SizedBox(height: 14),
                      if (_finalResult!['report']['highlights'] is List && (_finalResult!['report']['highlights'] as List).isNotEmpty) ...[
                        ...(_finalResult!['report']['highlights'] as List).map((h) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, size: 14, color: Colors.green),
                              const SizedBox(width: 6),
                              Expanded(child: Text(h.toString(), style: TextStyle(fontSize: 12, color: Colors.green.shade400))),
                            ],
                          ),
                        )),
                      ],
                      if (_finalResult!['report']['warnings'] is List && (_finalResult!['report']['warnings'] as List).isNotEmpty) ...[
                        const SizedBox(height: 6),
                        ...(_finalResult!['report']['warnings'] as List).map((w) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(Icons.warning, size: 14, color: Colors.orange.shade400),
                              const SizedBox(width: 6),
                              Expanded(child: Text(w.toString(), style: TextStyle(fontSize: 12, color: Colors.orange.shade400))),
                            ],
                          ),
                        )),
                      ],
                    ],
                    // ─── Raisonnement IA ───
                    if (_finalResult!['codeJudge'] != null && _finalResult!['codeJudge']['reasoning'] != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.blue.withAlpha(15) : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.withAlpha(40)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.code, size: 16, color: Colors.blue.shade400),
                                const SizedBox(width: 8),
                                Text(
                                  'Analyse du Code',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.blue.shade400),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _finalResult!['codeJudge']['reasoning'].toString(),
                              style: TextStyle(fontSize: 12, height: 1.5, color: isDark ? Colors.white70 : Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_finalResult!['productJudge'] != null && _finalResult!['productJudge']['reasoning'] != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.purple.withAlpha(15) : Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.purple.withAlpha(40)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.category, size: 16, color: Colors.purple.shade400),
                                const SizedBox(width: 8),
                                Text(
                                  'Analyse Produit',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.purple.shade400),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _finalResult!['productJudge']['reasoning'].toString(),
                              style: TextStyle(fontSize: 12, height: 1.5, color: isDark ? Colors.white70 : Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ] else ...[
              // Score pas encore calculé
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withAlpha(50)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.blue.shade400,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'L\'évaluation IA est en cours... Le score apparaîtra bientôt.',
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade400),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Message: soumission finale = définitive
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'La soumission finale est définitive et ne peut pas être modifiée.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Not submitted yet
            if (!isLeader) ...[
              // Non-leader : info message
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withAlpha(50)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.orange.shade600),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Seul le leader de l\'équipe peut soumettre le projet final.',
                        style: TextStyle(fontSize: 12, color: Colors.orange.shade600),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Leader : formulaire de soumission
              Text(
                'Entrez l\'URL du dépôt GitHub contenant votre projet final :',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _githubUrlCtrl,
                style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'https://github.com/user/my-project',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  prefixIcon: const Icon(Icons.code, color: Color(0xFF7C3AED), size: 20),
                  filled: true,
                  fillColor: isDark ? Colors.black26 : Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withAlpha(50)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withAlpha(50)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Warning banner — adapté selon antiCheat
              if (antiCheatEnabled) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withAlpha(50)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shield, size: 18, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(
                            'Anti-Triche IA Activé',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.red.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• L\'IA analysera votre code pour détecter le contenu généré par IA\n'
                        '• Seuil de tolérance : ${antiCheatThreshold.toStringAsFixed(0)}%\n'
                        '• Si le score dépasse le seuil → Disqualification automatique',
                        style: TextStyle(fontSize: 11, height: 1.6, color: Colors.red.shade500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withAlpha(50)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        antiCheatEnabled
                            ? 'Votre code sera analysé par l\'IA Anti-Triche. Assurez-vous que votre code est bien le vôtre et poussé sur GitHub.'
                            : 'L\'IA va analyser votre code, la structure du repo, et les commits. Assurez-vous que tout est poussé sur GitHub.',
                        style: TextStyle(fontSize: 11, height: 1.5, color: Colors.amber.shade600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Submit button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withAlpha(50),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _submittingFinal ? null : _submitFinalProject,
                      child: Center(
                        child: _submittingFinal
                            ? const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Évaluation IA en cours...',
                                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              )
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.rocket_launch, color: Colors.white, size: 20),
                                  SizedBox(width: 10),
                                  Text(
                                    'Soumettre le Projet Final',
                                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════

  Color _diffColor() {
    if (_competition == null) return AppColors.primary;
    return _competition!.difficulty.toUpperCase() == 'HARD'
        ? AppColors.accentOrange
        : _competition!.difficulty.toUpperCase() == 'EASY'
            ? Colors.green
            : AppColors.primary;
  }

  Widget _buildErrorView(bool isDark) {
    final bool isDeleted = _error == 'HACKATHON_DELETED';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDeleted ? Colors.orange.withAlpha(20) : Colors.red.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isDeleted ? Icons.history_toggle_off_rounded : Icons.error_outline_rounded,
                size: 80,
                color: isDeleted ? Colors.orangeAccent : Colors.redAccent,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              isDeleted ? 'Hackathon Indisponible' : 'Une erreur est survenue',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.textLightPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isDeleted
                  ? "Ce hackathon a été archivé ou supprimé par l'organisateur. Ses détails ne sont plus accessibles."
                  : _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushNamedAndRemoveUntil('/shell', (route) => false);
                  }
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text(
                  'Retour à l\'accueil',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDeleted ? Colors.orangeAccent : AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
            if (!isDeleted) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
                style: TextButton.styleFrom(foregroundColor: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade300, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _formatDateTime(DateTime d) {
    const months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${months[d.month - 1]} ${d.day} à $h:$m';
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return '00:00:00';
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

/// Self-contained countdown widget — only rebuilds itself every second,
/// instead of rebuilding the entire HackathonDetailScreen (1500+ lines).
class _CountdownText extends StatefulWidget {
  final DateTime targetDate;
  final String prefix;
  final TextStyle style;

  const _CountdownText({
    required this.targetDate,
    required this.prefix,
    required this.style,
  });

  @override
  State<_CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<_CountdownText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return '00:00:00';
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${widget.prefix}${_formatDuration(widget.targetDate.difference(DateTime.now()))}',
      style: widget.style,
    );
  }
}
