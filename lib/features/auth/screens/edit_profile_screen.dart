import 'package:flutter/material.dart';
import 'package:arena/core/models/auth_models.dart';
import 'package:arena/core/models/competition_model.dart';
import 'package:arena/core/services/api_service.dart';
import 'package:arena/core/services/storage_service.dart';
import 'package:arena/core/theme/app_theme.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _githubController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _api = ApiService();
  final _storage = StorageService();

  bool _isLoading = false;
  bool _isFetching = true;
  String? _errorMessage;
  String? _successMessage;
  AuthUser? _user;
  Specialty? _selectedSpecialty;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isFetching = true);

    try {
      // Try to get from API first (freshest data)
      final user = await _api.getMe();
      _populateFields(user);
    } on ApiError catch (e) {
      if (e.statusCode == 401) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/signin');
        return;
      }
      // Fallback to cached user
      final cached = await _storage.getUser();
      if (cached != null) {
        _populateFields(cached);
      } else {
        setState(() => _errorMessage = 'Failed to load profile');
      }
    } catch (_) {
      // Fallback to cached user
      final cached = await _storage.getUser();
      if (cached != null) {
        _populateFields(cached);
      } else {
        setState(() => _errorMessage = 'Connection error');
      }
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  void _populateFields(AuthUser user) {
    _user = user;
    _firstNameController.text = user.firstName;
    _lastNameController.text = user.lastName;
    _emailController.text = user.email;
    _githubController.text = user.githubUrl ?? '';
    _linkedinController.text = user.linkedinUrl ?? '';
    _selectedSpecialty = Specialty.fromString(user.mainSpecialty);
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final updatedUser = await _api.updateProfile(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        mainSpecialty: _selectedSpecialty?.name,
        githubUrl: _githubController.text.trim().isNotEmpty ? _githubController.text.trim() : null,
        linkedinUrl: _linkedinController.text.trim().isNotEmpty ? _linkedinController.text.trim() : null,
      );

      setState(() {
        _user = updatedUser;
        _successMessage = 'Profile updated successfully!';
      });
    } on ApiError catch (e) {
      if (e.statusCode == 401) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/signin');
        return;
      }
      setState(() => _errorMessage = e.displayMessage);
    } catch (_) {
      setState(() => _errorMessage = 'Connection error. Check your network.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Sign Out',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade400)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _api.signOut();
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/signin', (route) => false);
              }
            },
            child: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _githubController.dispose();
    _linkedinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF020617),
              Color(0xFF0F172A),
              Color(0xFF020617),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.arrow_back, color: Colors.grey.shade300),
                    ),
                    const Expanded(
                      child: Text(
                        'OPERATIVE SETTINGS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                          color: Color(0xFF0D6CF2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // Balance the back button
                  ],
                ),
              ),
              // Body
              Expanded(
                child: _isFetching
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Avatar
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.primary,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withAlpha(60),
                                          blurRadius: 20,
                                        ),
                                      ],
                                    ),
                                    child: CircleAvatar(
                                      radius: 48,
                                      backgroundColor: const Color(0xFF1A2332),
                                      child: Text(
                                        _user != null
                                            ? '${_user!.firstName.isNotEmpty ? _user!.firstName[0] : ''}${_user!.lastName.isNotEmpty ? _user!.lastName[0] : ''}'
                                                .toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_user != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _user!.role,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.5,
                                    color: AppColors.accentCyan,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 32),

                              // Messages
                              if (_errorMessage != null) ...[
                                _buildMessage(_errorMessage!, isError: true),
                                const SizedBox(height: 16),
                              ],
                              if (_successMessage != null) ...[
                                _buildMessage(_successMessage!, isError: false),
                                const SizedBox(height: 16),
                              ],

                              // Section header
                              _buildSectionHeader('PERSONAL INFO'),
                              const SizedBox(height: 16),

                              // First Name
                              _buildTextField(
                                controller: _firstNameController,
                                label: 'First Name',
                                prefixIcon: Icons.person_outline,
                                validator: (val) {
                                  if (val == null || val.isEmpty) return 'Required';
                                  if (val.length > 100) return 'Too long';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Last Name
                              _buildTextField(
                                controller: _lastNameController,
                                label: 'Last Name',
                                prefixIcon: Icons.person_outline,
                                validator: (val) {
                                  if (val == null || val.isEmpty) return 'Required';
                                  if (val.length > 100) return 'Too long';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),

                              _buildSectionHeader('SPECIALTY'),
                              const SizedBox(height: 10),
                              Text(
                                'Used to show you matching hackathons and send notifications.',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: Specialty.values.map((s) {
                                  final selected = _selectedSpecialty == s;
                                  return FilterChip(
                                    label: Text(s.displayName),
                                    selected: selected,
                                    onSelected: (_) => setState(() => _selectedSpecialty = selected ? null : s),
                                    selectedColor: AppColors.primary.withAlpha(40),
                                    checkmarkColor: AppColors.accentCyan,
                                    backgroundColor: const Color(0xFF1E293B).withAlpha(150),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: selected ? AppColors.accentCyan : Colors.white.withAlpha(20),
                                      ),
                                    ),
                                    labelStyle: TextStyle(
                                      color: selected ? AppColors.accentCyan : Colors.grey.shade300,
                                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 24),

                              _buildSectionHeader('SOCIAL LINKS'),
                              const SizedBox(height: 16),
                              
                              _buildTextField(
                                controller: _githubController,
                                label: 'GitHub URL',
                                prefixIcon: Icons.code,
                                keyboardType: TextInputType.url,
                              ),
                              const SizedBox(height: 16),
                              
                              _buildTextField(
                                controller: _linkedinController,
                                label: 'LinkedIn URL',
                                prefixIcon: Icons.work_outline,
                                keyboardType: TextInputType.url,
                              ),
                              const SizedBox(height: 24),

                              _buildSectionHeader('ACCOUNT'),
                              const SizedBox(height: 16),

                              // Email (read-only)
                              _buildTextField(
                                controller: _emailController,
                                label: 'Email',
                                prefixIcon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                readOnly: true,
                              ),
                              const SizedBox(height: 36),

                              // Save button
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _handleSave,
                                  icon: _isLoading
                                      ? const SizedBox.shrink()
                                      : const Icon(Icons.save_outlined, size: 20),
                                  label: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : const Text(
                                          'Save Changes',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: AppColors.primary.withAlpha(100),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Sign out button
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: OutlinedButton.icon(
                                  onPressed: _handleLogout,
                                  icon: const Icon(Icons.logout, size: 20),
                                  label: const Text(
                                    'Sign Out',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    side: const BorderSide(color: Colors.redAccent, width: 1.5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
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

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }

  Widget _buildMessage(String message, {required bool isError}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (isError ? Colors.red : Colors.green).withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isError ? Colors.red : Colors.green).withAlpha(60),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? Colors.redAccent : Colors.greenAccent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError ? Colors.redAccent : Colors.greenAccent,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade400,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          readOnly: readOnly,
          style: TextStyle(color: readOnly ? Colors.grey.shade500 : Colors.white, fontSize: 15),
          decoration: InputDecoration(
            prefixIcon: Icon(prefixIcon, color: AppColors.primary, size: 20),
            filled: true,
            fillColor: const Color(0xFF0F172A).withAlpha(100),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.primary.withAlpha(30)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withAlpha(15)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.accentCyan, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
            errorStyle: const TextStyle(fontSize: 11),
          ),
        ),
      ],
    );
  }
}
