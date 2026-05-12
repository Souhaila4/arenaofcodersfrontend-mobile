import 'package:flutter/material.dart';
import 'package:arena/core/services/api_service.dart';
import 'package:arena/core/models/auth_models.dart';
import 'package:arena/core/theme/app_theme.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _api = ApiService();

  String _email = '';
  bool _isLoading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) {
      _email = args;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;

    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _api.resetPassword(
        email: _email,
        code: _codeController.text.trim(),
        newPassword: _newPasswordController.text,
      );

      if (!mounted) return;
      // Navigate to sign in
      Navigator.of(context).pushNamedAndRemoveUntil('/signin', (route) => false);
    } on ApiError catch (e) {
      setState(() => _errorMessage = e.displayMessage);
    } catch (e) {
      setState(() => _errorMessage = 'Connection error. Check your network.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF020617), Color(0xFF0F172A), Color(0xFF020617)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withAlpha(25)),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withAlpha(40),
                              blurRadius: 30,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.vpn_key_outlined,
                          color: AppColors.primary,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Reset Password',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Enter the 6-digit code sent to $_email and your new password.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 36),

                      if (_errorMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withAlpha(60)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Colors.redAccent, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                      color: Colors.redAccent, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      _buildTextField(
                        controller: _codeController,
                        hintText: '6-digit Reset Code',
                        prefixIcon: Icons.pin_outlined,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        validator: (val) {
                          if (val == null || val.length != 6) return 'Enter 6-digit code';
                          return null;
                        },
                      ),
                      const SizedBox(height: 4),

                      _buildTextField(
                        controller: _newPasswordController,
                        hintText: 'New Password',
                        prefixIcon: Icons.lock_outline,
                        obscureText: _obscureNew,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: Colors.grey.shade600,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscureNew = !_obscureNew),
                        ),
                        validator: (val) {
                          if (val == null || val.length < 8) return 'Min 8 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: _confirmPasswordController,
                        hintText: 'Confirm New Password',
                        prefixIcon: Icons.lock_outline,
                        obscureText: _obscureConfirm,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: Colors.grey.shade600,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Confirm password';
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleReset,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                AppColors.primary.withAlpha(100),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Save New Password',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLength: maxLength,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        counterText: '',
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        prefixIcon: Icon(prefixIcon, color: Colors.grey.shade600, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFF1E293B).withAlpha(180),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withAlpha(15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        errorStyle: const TextStyle(fontSize: 11),
      ),
    );
  }
}
