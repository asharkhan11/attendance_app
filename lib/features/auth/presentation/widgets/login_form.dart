import 'package:flutter/material.dart';
import '../../../../design_system/app_radius.dart';
import '../../../../design_system/app_spacing.dart';

class LoginForm extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController schoolCodeController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool rememberCredentials;
  final ValueChanged<bool> onRememberChanged;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onSubmit;

  const LoginForm({
    super.key,
    required this.formKey,
    required this.schoolCodeController,
    required this.emailController,
    required this.passwordController,
    required this.rememberCredentials,
    required this.onRememberChanged,
    required this.isLoading,
    this.errorMessage,
    required this.onSubmit,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: AppRadius.cardBorderRadius,
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      widget.errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          TextFormField(
            controller: widget.schoolCodeController,
            decoration: const InputDecoration(
              labelText: 'School Code',
              hintText: 'e.g. demo-school',
              prefixIcon: Icon(Icons.business),
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              final val = v?.trim() ?? '';
              if (val.isEmpty) return 'Please enter your school code';
              if (val.length < 2) return 'School code must be at least 2 characters';
              final validRegExp = RegExp(r'^[a-zA-Z0-9_-]+$');
              if (!validRegExp.hasMatch(val)) {
                return 'Use letters, numbers, hyphens or underscores';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: widget.emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              hintText: 'e.g. admin@school.edu',
              prefixIcon: Icon(Icons.email),
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              final val = v?.trim() ?? '';
              if (val.isEmpty) return 'Please enter your email address';
              final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
              if (!emailRegExp.hasMatch(val)) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: widget.passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: const OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please enter your password';
              if (v.length < 4) return 'Password must be at least 4 characters';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.xs),
          InkWell(
            onTap: () => widget.onRememberChanged(!widget.rememberCredentials),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Checkbox(
                    value: widget.rememberCredentials,
                    onChanged: (val) => widget.onRememberChanged(val ?? true),
                  ),
                  Text(
                    'Remember School Code & Email',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton(
            onPressed: widget.isLoading ? null : widget.onSubmit,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
            child: widget.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'LOG IN',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }
}
