import 'package:flutter/material.dart';
import 'package:arena/core/models/competition_model.dart';
import 'package:arena/core/services/api_service.dart';
import 'package:arena/core/theme/app_theme.dart';
import 'package:arena/core/models/auth_models.dart';

class CreateCompetitionScreen extends StatefulWidget {
  const CreateCompetitionScreen({super.key});

  @override
  State<CreateCompetitionScreen> createState() => _CreateCompetitionScreenState();
}

class _CreateCompetitionScreenState extends State<CreateCompetitionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _rewardController = TextEditingController(text: '0');
  final _maxParticipantsController = TextEditingController();

  String _difficulty = 'MEDIUM';
  Specialty? _specialty;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _loading = false;
  String? _error;

  // --- Hackathon ideas (from AI) ---
  List<HackathonIdea>? _ideas;
  bool _loadingIdeas = false;
  String? _ideasError;

  // --- Anti-cheat variables ---
  bool _antiCheatEnabled = false;
  final _antiCheatThresholdController = TextEditingController(text: '70');

  @override
  void dispose() {
    _antiCheatThresholdController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _rewardController.dispose();
    _maxParticipantsController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d != null) {
      final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (t != null && mounted) setState(() => _startDate = DateTime(d.year, d.month, d.day, t.hour, t.minute));
    }
  }

  Future<void> _pickEndDate() async {
    final start = _startDate ?? DateTime.now().add(const Duration(days: 7));
    final d = await showDatePicker(
      context: context,
      initialDate: _endDate ?? start.add(const Duration(days: 2)),
      firstDate: start,
      lastDate: start.add(const Duration(days: 90)),
    );
    if (d != null) {
      final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 18, minute: 0));
      if (t != null && mounted) setState(() => _endDate = DateTime(d.year, d.month, d.day, t.hour, t.minute));
    }
  }

  Future<void> _fetchIdeas() async {
    if (_loadingIdeas) return;
    setState(() {
      _loadingIdeas = true;
      _ideasError = null;
      _ideas = null;
    });
    try {
      final list = await _api.getHackathonIdeas();
      if (mounted) setState(() {
        _ideas = list;
        _loadingIdeas = false;
        _ideasError = list.isEmpty ? 'No ideas returned.' : null;
      });
    } on ApiError catch (e) {
      if (e.statusCode == 401 && mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/signin', (route) => false);
        return;
      }
      if (mounted) setState(() {
        _ideasError = e.displayMessage;
        _loadingIdeas = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _ideasError = 'Failed to load ideas';
        _loadingIdeas = false;
      });
    }
  }

  void _applyIdea(HackathonIdea idea) {
    _titleController.text = idea.title;
    _descriptionController.text = idea.description;
    if (idea.targetMarket.isNotEmpty) {
      _descriptionController.text += '\n\nTarget market: ${idea.targetMarket}';
    }
    if (idea.feasibility.isNotEmpty) {
      _descriptionController.text += '\nFeasibility: ${idea.feasibility}';
    }
    setState(() {});
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      setState(() => _error = 'Please set start and end date');
      return;
    }
    if (_endDate!.isBefore(_startDate!) || _endDate!.isAtSameMomentAs(_startDate!)) {
      setState(() => _error = 'End date must be after start date');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final reward = double.tryParse(_rewardController.text.trim()) ?? 0;
      final maxPart = int.tryParse(_maxParticipantsController.text.trim());

      await _api.createCompetition(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        difficulty: _difficulty,
        specialty: _specialty?.name,
        startDate: _startDate!.toUtc().toIso8601String(),
        endDate: _endDate!.toUtc().toIso8601String(),
        rewardPool: reward,
        maxParticipants: maxPart,
        antiCheatEnabled: _antiCheatEnabled,
        antiCheatThreshold: _antiCheatEnabled ? double.tryParse(_antiCheatThresholdController.text.trim()) : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hackathon created!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } on ApiError catch (e) {
      if (e.statusCode == 401 && mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/signin', (route) => false);
        return;
      }
      if (mounted) setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to create');
    }
    if (mounted) setState(() => _loading = false);
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                    ),
                    const Expanded(
                      child: Text(
                        'Create Hackathon',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_error != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withAlpha(25),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.withAlpha(80)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.redAccent, size: 22),
                                const SizedBox(width: 10),
                                Expanded(child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        // --- Hackathon ideas (AI) ---
                        Container(
                          padding: const EdgeInsets.all(16),
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
                                  const Icon(Icons.lightbulb_outline, color: AppColors.accentOrange),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Hackathon ideas',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  FilledButton.icon(
                                    onPressed: _loadingIdeas ? null : _fetchIdeas,
                                    icon: _loadingIdeas
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.auto_awesome, size: 18),
                                    label: Text(_loadingIdeas ? 'Loading…' : 'Get ideas'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    ),
                                  ),
                                ],
                              ),
                              if (_ideasError != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  _ideasError!,
                                  style: TextStyle(fontSize: 13, color: Colors.orange.shade300),
                                ),
                              ],
                              if (_ideas != null && _ideas!.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Text(
                                  'Tap a card to use it as title & description:',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                                ),
                                const SizedBox(height: 10),
                                ...(_ideas!.map((idea) => _ideaCard(context, idea, isDark))),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _label('Title'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _titleController,
                          validator: (v) {
                            if (v == null || v.trim().length < 3) return 'Min 3 characters';
                            if (v.trim().length > 120) return 'Max 120 characters';
                            return null;
                          },
                          style: TextStyle(color: isDark ? Colors.white : AppColors.textLightPrimary, fontSize: 15),
                          decoration: _inputDecoration(context, 'e.g. AI Challenge 2026'),
                        ),
                        const SizedBox(height: 20),
                        _label('Description'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 4,
                          validator: (v) {
                            if (v == null || v.trim().length < 10) return 'Min 10 characters';
                            return null;
                          },
                          style: TextStyle(color: isDark ? Colors.white : AppColors.textLightPrimary, fontSize: 15),
                          decoration: _inputDecoration(context, 'Challenge brief for participants...'),
                        ),
                        const SizedBox(height: 20),
                        _label('Difficulty'),
                        const SizedBox(height: 8),
                        Row(
                          children: ['EASY', 'MEDIUM', 'HARD'].map((d) {
                            final selected = _difficulty == d;
                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: ChoiceChip(
                                label: Text(d == 'EASY' ? 'Easy' : (d == 'HARD' ? 'Hard' : 'Medium')),
                                selected: selected,
                                onSelected: (_) => setState(() => _difficulty = d),
                                selectedColor: AppColors.primary.withAlpha(60),
                                side: BorderSide(color: selected ? AppColors.primary : Colors.grey.shade600),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                        _label('Specialty (optional – users with this specialty get notified)'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: Specialty.values.map((s) {
                            final selected = _specialty == s;
                            return FilterChip(
                              label: Text(s.displayName),
                              selected: selected,
                              onSelected: (_) => setState(() => _specialty = selected ? null : s),
                              selectedColor: AppColors.primary.withAlpha(50),
                              checkmarkColor: AppColors.primary,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                        _label('Start date & time'),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _pickStartDate,
                          icon: const Icon(Icons.calendar_today, size: 20),
                          label: Text(_startDate == null ? 'Pick start' : _formatDateTime(_startDate!)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _label('End date & time'),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _pickEndDate,
                          icon: const Icon(Icons.calendar_today, size: 20),
                          label: Text(_endDate == null ? 'Pick end' : _formatDateTime(_endDate!)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _label('Reward pool (\$)'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _rewardController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: isDark ? Colors.white : AppColors.textLightPrimary, fontSize: 15),
                          decoration: _inputDecoration(context, '0'),
                        ),
                        const SizedBox(height: 16),
                        _label('Max participants (optional)'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _maxParticipantsController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: isDark ? Colors.white : AppColors.textLightPrimary, fontSize: 15),
                          decoration: _inputDecoration(context, 'Leave empty for unlimited'),
                        ),
                        // --- Anti Cheat Section ---
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
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
                                  const Icon(Icons.security, color: AppColors.accentOrange),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Contrôle Anti-Triche IA',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  Switch(
                                    value: _antiCheatEnabled,
                                    onChanged: (val) => setState(() => _antiCheatEnabled = val),
                                    activeColor: AppColors.accentOrange,
                                  ),
                                ],
                              ),
                              if (_antiCheatEnabled) ...[
                                const SizedBox(height: 16),
                                _label('Seuil d\'acceptation (%)'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _antiCheatThresholdController,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 15),
                                  decoration: _inputDecoration(context, 'Ex: 70'),
                                  validator: (v) {
                                    if (!_antiCheatEnabled) return null;
                                    final val = double.tryParse(v ?? '');
                                    if (val == null || val < 0 || val > 100) return 'Entre 0 et 100';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Les participants dont le code est détecté comme généré par IA à plus de ${_antiCheatThresholdController.text}% seront disqualifiés.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // --------------------------
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: _loading ? null : _submit,
                            icon: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : const Icon(Icons.add_circle_outline, size: 22),
                            label: Text(_loading ? 'Creating…' : 'Create hackathon'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade400,
      ),
    );
  }

  InputDecoration _inputDecoration(BuildContext context, String hint) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade600),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B).withAlpha(180) : Colors.grey.shade100,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? Colors.white.withAlpha(15) : Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    );
  }

  String _formatDateTime(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Widget _ideaCard(BuildContext context, HackathonIdea idea, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _applyIdea(idea),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        idea.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.textLightPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(50),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Score ${idea.score}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (idea.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    idea.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey.shade300 : AppColors.textLightSecondary,
                    ),
                  ),
                ],
                if (idea.targetMarket.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Target: ${idea.targetMarket}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
