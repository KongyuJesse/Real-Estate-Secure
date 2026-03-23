import 'package:flutter/material.dart';

import '../../../data/consumer_api.dart';
import '../consumer_controller.dart';
import '../../../ui/app_icons.dart';
import '../../../ui/brand.dart';
import '../../../ui/components/buttons.dart';
import '../../../ui/components/cards.dart';

class ConsumerLoginPage extends StatefulWidget {
  const ConsumerLoginPage({
    super.key,
    required this.controller,
    required this.onBack,
  });

  final ConsumerController controller;
  final VoidCallback onBack;

  @override
  State<ConsumerLoginPage> createState() => _ConsumerLoginPageState();
}

class _ConsumerLoginPageState extends State<ConsumerLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _passwordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final textTheme = Theme.of(context).textTheme;
        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ResCircleIconButton(
                        icon: ResIcons.back,
                        backgroundColor: ResColors.surfaceContainerLowest,
                        onPressed: widget.onBack,
                      ),
                      const SizedBox(width: 12),
                      Text('Login', style: textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 34),
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: ResGradients.premiumButton,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Icon(
                            ResIcons.secure,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Real Estate Secure',
                          style: textTheme.titleLarge?.copyWith(
                            color: ResColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                  Text('Welcome Back', style: textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your details to reopen your secure property workspace.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: ResColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      ResInfoChip(
                        label: 'Encrypted session',
                        color: ResColors.primary,
                        icon: ResIcons.secure,
                      ),
                      ResInfoChip(
                        label: 'MFA ready',
                        color: ResColors.secondary,
                        icon: Icons.verified_user_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ResSurfaceCard(
                    radius: 26,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sign in', style: textTheme.titleMedium),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email or phone',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Email is required.'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_passwordVisible,
                            decoration:
                                const InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: Icon(ResIcons.security),
                                ).copyWith(
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(
                                        () => _passwordVisible =
                                            !_passwordVisible,
                                      );
                                    },
                                    icon: Icon(
                                      _passwordVisible
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                    ),
                                  ),
                                ),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Password is required.'
                                : null,
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _openForgotPasswordFlow,
                              child: const Text('Forgot password?'),
                            ),
                          ),
                          if (widget.controller.authError != null) ...[
                            const SizedBox(height: 14),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                widget.controller.authError!,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: ResColors.destructive),
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          ResPrimaryButton(
                            label: 'Login',
                            icon: ResIcons.login,
                            isPill: true,
                            isBusy: widget.controller.isSubmittingAuth,
                            onPressed: _submit,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: ResColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            ResIcons.trust,
                            size: 16,
                            color: ResColors.tertiary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'FINTECH-GRADE SECURITY',
                            style: textTheme.labelSmall?.copyWith(
                              color: ResColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final success = await widget.controller.login(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (!mounted) {
      return;
    }
    if (!success && widget.controller.hasPendingMfaChallenge) {
      await showDialog<void>(
        context: context,
        builder: (context) => _TwoFactorLoginDialog(
          controller: widget.controller,
          email: _emailController.text.trim(),
        ),
      );
      return;
    }
    if (!success) {
      return;
    }
  }

  Future<void> _openForgotPasswordFlow() async {
    final resetCompleted = await showDialog<bool>(
      context: context,
      builder: (context) => _ForgotPasswordDialog(
        controller: widget.controller,
        initialEmail: _emailController.text,
      ),
    );
    if (!mounted || resetCompleted != true) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Password updated. You can now sign in with your new password.',
        ),
      ),
    );
    _passwordController.clear();
  }
}

class _TwoFactorLoginDialog extends StatefulWidget {
  const _TwoFactorLoginDialog({required this.controller, required this.email});

  final ConsumerController controller;
  final String email;

  @override
  State<_TwoFactorLoginDialog> createState() => _TwoFactorLoginDialogState();
}

class _TwoFactorLoginDialogState extends State<_TwoFactorLoginDialog> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return AlertDialog(
          title: const Text('Two-factor authentication'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the authenticator code for ${widget.email.isNotEmpty ? widget.email : 'your account'} to complete sign-in.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ResColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Authenticator code',
                  prefixIcon: Icon(Icons.security_rounded),
                ),
              ),
              if (widget.controller.pendingMfaExpiresAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Challenge expires ${_formatDialogTime(widget.controller.pendingMfaExpiresAt!)}.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ResColors.mutedForeground,
                  ),
                ),
              ],
              if (widget.controller.authError != null) ...[
                const SizedBox(height: 12),
                Text(
                  widget.controller.authError!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: ResColors.destructive),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: widget.controller.isSubmittingMfa
                  ? null
                  : () {
                      widget.controller.clearPendingMfaChallenge();
                      Navigator.of(context).pop();
                    },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: widget.controller.isSubmittingMfa ? null : _verify,
              child: widget.controller.isSubmittingMfa
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Verify'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length < 6) {
      return;
    }
    final success = await widget.controller.completeTwoFactorLogin(code);
    if (!mounted || !success) {
      return;
    }
    Navigator.of(context).pop();
  }
}

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({
    required this.controller,
    required this.initialEmail,
  });

  final ConsumerController controller;
  final String initialEmail;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _emailController;
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRequesting = false;
  bool _isResetting = false;
  String? _infoMessage;
  String? _errorMessage;
  DateTime? _previewExpiresAt;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail.trim());
  }

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset password'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We will send password reset instructions to the account email if it exists.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: ResColors.mutedForeground),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Account email'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ResPrimaryButton(
                label: 'Send reset instructions',
                icon: Icons.mail_outline_rounded,
                isBusy: _isRequesting,
                onPressed: _requestReset,
              ),
            ),
            if (_infoMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _infoMessage!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: ResColors.secondary),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: ResColors.destructive),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'Continue reset',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Open the email we sent, then paste the reset token below to finish changing the password.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: ResColors.mutedForeground),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(labelText: 'Reset token'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
            if (_previewExpiresAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Current reset token expires ${_formatDialogTime(_previewExpiresAt!)}.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ResColors.mutedForeground,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ResPrimaryButton(
                label: 'Reset password now',
                icon: Icons.lock_reset_rounded,
                isBusy: _isResetting,
                onPressed: _resetPassword,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isRequesting || _isResetting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<void> _requestReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Email is required.';
      });
      return;
    }

    setState(() {
      _isRequesting = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final preview = await widget.controller.requestPasswordReset(email);
      setState(() {
        _infoMessage =
            'If the account exists, reset instructions have been issued.';
        _previewExpiresAt = preview.previewExpiresAt;
      });
    } on ConsumerApiFailure catch (error) {
      setState(() {
        _errorMessage = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRequesting = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    final token = _tokenController.text.trim();
    final password = _passwordController.text;
    if (token.isEmpty || password.length < 8) {
      setState(() {
        _errorMessage =
            'Provide a valid reset token and a password with at least 8 characters.';
      });
      return;
    }

    setState(() {
      _isResetting = true;
      _errorMessage = null;
    });

    try {
      await widget.controller.completePasswordReset(
        token: token,
        password: password,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on ConsumerApiFailure catch (error) {
      setState(() {
        _errorMessage = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResetting = false;
        });
      }
    }
  }
}

String _formatDialogTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour == 0
      ? 12
      : (local.hour > 12 ? local.hour - 12 : local.hour);
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.day}/${local.month}/${local.year} at $hour:$minute $period';
}
