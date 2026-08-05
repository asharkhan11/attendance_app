import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../design_system/app_breakpoints.dart';
import '../design_system/app_spacing.dart';
import '../features/auth/presentation/widgets/login_form.dart';
import '../features/auth/presentation/widgets/login_header.dart';
import '../providers/auth_provider.dart';
import '../utils/app_logger.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _schoolCodeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _rememberCredentials = true;
  bool _isLoadingSavedCredentials = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final saved = await authProvider.getSavedCredentials();
    
    if (mounted) {
      final savedSchool = saved['schoolCode'] ?? '';
      final savedEmail = saved['email'] ?? '';

      _schoolCodeController.text = savedSchool;
      _emailController.text = savedEmail;
      _passwordController.text = '';

      setState(() {
        _isLoadingSavedCredentials = false;
      });
    }
  }

  @override
  void dispose() {
    _schoolCodeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    AppLogger.i(
      'LoginScreen',
      'User submitted login form for ${_emailController.text.trim()} (Remember: $_rememberCredentials)',
    );

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      _schoolCodeController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
      rememberCredentials: _rememberCredentials,
    );

    if (!mounted) return;
    if (!success && authProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(authProvider.errorMessage!)),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isMobile = context.isMobile;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? AppSpacing.md : AppSpacing.xl),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? AppSpacing.md : AppSpacing.lg),
                  child: _isLoadingSavedCredentials
                      ? const SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const LoginHeader(),
                            const SizedBox(height: AppSpacing.lg),
                            LoginForm(
                              formKey: _formKey,
                              schoolCodeController: _schoolCodeController,
                              emailController: _emailController,
                              passwordController: _passwordController,
                              rememberCredentials: _rememberCredentials,
                              onRememberChanged: (val) {
                                setState(() => _rememberCredentials = val);
                              },
                              isLoading: authProvider.isLoading,
                              errorMessage: authProvider.errorMessage,
                              onSubmit: _submit,
                            ),
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
}

