import 'package:flutter/material.dart';
import 'package:arena/core/theme/app_theme.dart';
import 'package:arena/core/services/api_service.dart';

/// Formulaire de création d'une offre d'emploi par une entreprise (COMPANY).
/// Le dropdown [targetSpecialty] est le filtre clé pour minimiser les tokens IA.
class CreateJobScreen extends StatefulWidget {
  const CreateJobScreen({super.key});

  @override
  State<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends State<CreateJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  String _selectedSpecialty = 'BACKEND';
  bool _loading = false;

  static const _specialties = [
    'FRONTEND',
    'BACKEND',
    'FULLSTACK',
    'MOBILE',
    'DATA',
    'BI',
    'CYBERSECURITY',
    'DESIGN',
    'DEVOPS',
  ];

  static const _specialtyIcons = {
    'FRONTEND': Icons.web,
    'BACKEND': Icons.dns,
    'FULLSTACK': Icons.layers,
    'MOBILE': Icons.phone_android,
    'DATA': Icons.bar_chart,
    'BI': Icons.analytics,
    'CYBERSECURITY': Icons.shield,
    'DESIGN': Icons.palette,
    'DEVOPS': Icons.cloud,
  };

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await ApiService().createJob(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        targetSpecialty: _selectedSpecialty,
        companyName: _companyCtrl.text.trim(),
        location:
            _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Offre publiée avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // retour avec refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _companyCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('PUBLIER UNE OFFRE')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Header ───
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E40AF), Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child:
                          const Icon(Icons.work_outline, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nouvelle offre d\'emploi',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'L\'IA trouvera les meilleurs candidats',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ─── Specialty Selector (clé pour minimiser les tokens) ───
              Text(
                'Spécialité recherchée *',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Filtre les candidats avant le matching IA (économie de tokens)',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _specialties.map((s) {
                  final selected = _selectedSpecialty == s;
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _specialtyIcons[s] ?? Icons.code,
                          size: 16,
                          color: selected ? Colors.white : AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(s),
                      ],
                    ),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedSpecialty = s),
                    selectedColor: AppColors.primary,
                    backgroundColor:
                        isDark ? AppColors.surfaceDark : Colors.grey.shade100,
                    labelStyle: TextStyle(
                      color: selected
                          ? Colors.white
                          : isDark
                              ? Colors.grey.shade300
                              : Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: selected
                            ? AppColors.primary
                            : Colors.grey.withAlpha(50),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // ─── Fields ───
              _buildField('Titre du poste *', _titleCtrl, 'Ex: Développeur Backend Senior'),
              const SizedBox(height: 16),
              _buildField('Nom de l\'entreprise *', _companyCtrl, 'Ex: Arena Analytics'),
              const SizedBox(height: 16),
              _buildField('Localisation', _locationCtrl, 'Ex: Remote · Tunis',
                  required: false),
              const SizedBox(height: 16),
              _buildField(
                'Description du poste *',
                _descCtrl,
                'Décrivez les responsabilités, compétences requises, expérience...',
                maxLines: 6,
              ),
              const SizedBox(height: 32),

              // ─── Submit ───
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.publish),
                  label: Text(_loading ? 'Publication...' : 'Publier l\'offre'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
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

  Widget _buildField(
    String label,
    TextEditingController ctrl,
    String hint, {
    bool required = true,
    int maxLines = 1,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          validator: required
              ? (v) => (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null
              : null,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
            filled: true,
            fillColor: isDark ? AppColors.surfaceDark : Colors.grey.shade50,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
