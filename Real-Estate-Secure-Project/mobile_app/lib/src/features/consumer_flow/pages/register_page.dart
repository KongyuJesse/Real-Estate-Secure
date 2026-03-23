import 'package:flutter/material.dart';

import '../consumer_controller.dart';
import '../../../ui/app_icons.dart';
import '../../../ui/brand.dart';
import '../../../ui/components/avatar.dart';
import '../../../ui/components/buttons.dart';
import '../../../ui/components/cards.dart';

class ConsumerRegisterPage extends StatefulWidget {
  const ConsumerRegisterPage({
    super.key,
    required this.controller,
    required this.onBack,
  });

  final ConsumerController controller;
  final VoidCallback onBack;

  @override
  State<ConsumerRegisterPage> createState() => _ConsumerRegisterPageState();
}

class _ConsumerRegisterPageState extends State<ConsumerRegisterPage> {
  final _stepOneKey = GlobalKey<FormState>();
  final _stepTwoKey = GlobalKey<FormState>();
  final _stepThreeKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _bioController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _currentStep = 0;
  String _selectedRole = 'buyer';
  String _preferredLanguage = 'en';
  bool _emailNotifications = true;
  bool _smsNotifications = true;
  bool _pushNotifications = true;
  bool _marketingNotifications = false;
  bool _acceptedTerms = true;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _isFinishing = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _bioController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _RoundBackButton(
                            onPressed: _currentStep == 0
                                ? widget.onBack
                                : _goBackStep,
                          ),
                          Expanded(
                            child: Text(
                              'Create Account',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(width: 40),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ResInfoChip(
                            label: 'Step ${_currentStep + 1} of 4',
                            color: ResColors.primary,
                            icon: ResIcons.secure,
                          ),
                          ResInfoChip(
                            label: _roleLabel(_selectedRole),
                            color: ResColors.accent,
                            icon: ResIcons.profile,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _stepSubtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: ResColors.mutedForeground),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _RegisterStepper(currentStep: _currentStep),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: const [
                          ResInfoChip(
                            label: 'Mobile-first onboarding',
                            color: ResColors.primary,
                            icon: ResIcons.secure,
                          ),
                          ResInfoChip(
                            label: 'Verification ready',
                            color: ResColors.secondary,
                            icon: ResIcons.trust,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      switch (_currentStep) {
                        0 => _IdentityStep(
                          formKey: _stepOneKey,
                          fullNameController: _fullNameController,
                          emailController: _emailController,
                          selectedRole: _selectedRole,
                          onRoleSelected: (value) {
                            setState(() => _selectedRole = value);
                          },
                        ),
                        1 => _DetailsStep(
                          formKey: _stepTwoKey,
                          phoneController: _phoneController,
                          dobController: _dobController,
                          bioController: _bioController,
                          preferredLanguage: _preferredLanguage,
                          onLanguageChanged: (value) {
                            setState(() => _preferredLanguage = value);
                          },
                          onPickDob: _pickDateOfBirth,
                        ),
                        2 => _SecurityStep(
                          formKey: _stepThreeKey,
                          passwordController: _passwordController,
                          confirmPasswordController: _confirmPasswordController,
                          passwordVisible: _passwordVisible,
                          confirmPasswordVisible: _confirmPasswordVisible,
                          emailNotifications: _emailNotifications,
                          smsNotifications: _smsNotifications,
                          pushNotifications: _pushNotifications,
                          marketingNotifications: _marketingNotifications,
                          onTogglePasswordVisibility: () {
                            setState(
                              () => _passwordVisible = !_passwordVisible,
                            );
                          },
                          onToggleConfirmPasswordVisibility: () {
                            setState(
                              () => _confirmPasswordVisible =
                                  !_confirmPasswordVisible,
                            );
                          },
                          onEmailNotificationsChanged: (value) {
                            setState(() => _emailNotifications = value);
                          },
                          onSmsNotificationsChanged: (value) {
                            setState(() => _smsNotifications = value);
                          },
                          onPushNotificationsChanged: (value) {
                            setState(() => _pushNotifications = value);
                          },
                          onMarketingNotificationsChanged: (value) {
                            setState(() => _marketingNotifications = value);
                          },
                        ),
                        _ => _ReviewStep(
                          fullName: _fullNameController.text.trim(),
                          email: _emailController.text.trim(),
                          phone: _phoneController.text.trim(),
                          role: _roleLabel(_selectedRole),
                          preferredLanguage: _preferredLanguage == 'fr'
                              ? 'French'
                              : 'English',
                          acceptedTerms: _acceptedTerms,
                          onTermsChanged: (value) {
                            setState(() => _acceptedTerms = value);
                          },
                        ),
                      },
                      if (widget.controller.authError != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          widget.controller.authError!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: ResColors.destructive),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                  decoration: const BoxDecoration(
                    color: ResColors.background,
                    boxShadow: [
                      BoxShadow(
                        color: Color.fromRGBO(25, 28, 32, 0.05),
                        blurRadius: 22,
                        offset: Offset(0, -8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          if (_currentStep > 0)
                            Expanded(
                              child: ResOutlineButton(
                                label: 'Back',
                                icon: ResIcons.back,
                                onPressed: _goBackStep,
                              ),
                            ),
                          if (_currentStep > 0) const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ResPrimaryButton(
                              label: _currentStep == 3
                                  ? 'Create Account'
                                  : 'Continue',
                              icon: ResIcons.arrowRight,
                              isBusy:
                                  widget.controller.isSubmittingAuth ||
                                  _isFinishing,
                              onPressed: _currentStep == 3
                                  ? _finishRegistration
                                  : _goNextStep,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'By continuing, you agree to our Terms of Service.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ResColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String get _stepSubtitle => switch (_currentStep) {
    0 =>
      'Start with identity details and the role that best matches your marketplace lane.',
    1 =>
      'Add trusted contact details and profile settings used across the platform.',
    2 =>
      'Set credentials and communication preferences for a secure mobile workspace.',
    _ => 'Review everything carefully before we create your secure account.',
  };

  void _goBackStep() {
    if (_currentStep == 0) {
      widget.onBack();
      return;
    }
    setState(() => _currentStep -= 1);
  }

  void _goNextStep() {
    final canProceed = switch (_currentStep) {
      0 => _stepOneKey.currentState?.validate() == true,
      1 => _stepTwoKey.currentState?.validate() == true,
      2 => _stepThreeKey.currentState?.validate() == true,
      _ => true,
    };
    if (!canProceed) {
      return;
    }
    setState(() => _currentStep += 1);
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 18, now.month, now.day),
    );
    if (selected == null) {
      return;
    }
    _dobController.text =
        '${selected.year.toString().padLeft(4, '0')}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
  }

  Future<void> _finishRegistration() async {
    if (!_acceptedTerms) {
      setState(() {});
      return;
    }

    final parts = _fullNameController.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    final firstName = parts.isNotEmpty ? parts.first : '';
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    setState(() => _isFinishing = true);
    try {
      final success = await widget.controller.register(
        email: _emailController.text,
        password: _passwordController.text,
        phoneNumber: _phoneController.text,
        firstName: firstName,
        lastName: lastName,
        dateOfBirth: _dobController.text,
        role: _selectedRole,
      );
      if (!success) {
        return;
      }

      try {
        await widget.controller.saveProfile(
          preferredLanguage: _preferredLanguage,
          bio: _bioController.text,
          phoneNumber: _phoneController.text,
        );
        await widget.controller.savePreferences(
          locale: _preferredLanguage,
          emailNotificationsEnabled: _emailNotifications,
          smsNotificationsEnabled: _smsNotifications,
          pushNotificationsEnabled: _pushNotifications,
          marketingNotificationsEnabled: _marketingNotifications,
        );
      } catch (_) {
        // Best-effort enrichment after account creation.
      }
    } finally {
      if (mounted) {
        setState(() => _isFinishing = false);
      }
    }
  }

  String _roleLabel(String value) {
    switch (value) {
      case 'lawyer':
        return 'Lawyer';
      case 'notary':
        return 'Notary';
      case 'seller':
        return 'Seller';
      default:
        return 'Buyer';
    }
  }
}

class _RoundBackButton extends StatelessWidget {
  const _RoundBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ResColors.card,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(ResIcons.back, size: 22),
        ),
      ),
    );
  }
}

class _RegisterStepper extends StatelessWidget {
  const _RegisterStepper({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    const labels = ['Identity', 'Details', 'Verify', 'Done'];
    return SizedBox(
      height: 70,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 15,
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: ResColors.muted,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: ((3 - currentStep) * 72).toDouble(),
            top: 15,
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: ResColors.primary,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(labels.length, (index) {
              final isActive = index <= currentStep;
              final isCurrent = index == currentStep;
              return SizedBox(
                width: 72,
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isActive ? ResColors.primary : ResColors.card,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isActive
                              ? ResColors.primary
                              : ResColors.border,
                          width: 2,
                        ),
                        boxShadow: isCurrent ? ResShadows.pill : null,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: isActive
                                    ? Colors.white
                                    : ResColors.mutedForeground,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      labels[index].toUpperCase(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isCurrent
                            ? ResColors.primary
                            : ResColors.mutedForeground,
                        fontWeight: isCurrent
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _IdentityStep extends StatelessWidget {
  const _IdentityStep({
    required this.formKey,
    required this.fullNameController,
    required this.emailController,
    required this.selectedRole,
    required this.onRoleSelected,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController fullNameController;
  final TextEditingController emailController;
  final String selectedRole;
  final ValueChanged<String> onRoleSelected;

  @override
  Widget build(BuildContext context) {
    return ResSurfaceCard(
      child: Form(
        key: formKey,
        child: Column(
          children: [
            _FieldShell(
              label: 'Full Name',
              child: TextFormField(
                controller: fullNameController,
                decoration: const InputDecoration(
                  hintText: 'Alex Johnson',
                  prefixIcon: Icon(ResIcons.profile),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your full name.'
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            _FieldShell(
              label: 'Email Address',
              child: TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'alex.johnson@example.com',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your email.'
                    : null,
              ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'I am primarily a...',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.3,
              children: _roles
                  .map(
                    (role) => _RoleChip(
                      label: role.$2,
                      selected: selectedRole == role.$1,
                      onTap: () => onRoleSelected(role.$1),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsStep extends StatelessWidget {
  const _DetailsStep({
    required this.formKey,
    required this.phoneController,
    required this.dobController,
    required this.bioController,
    required this.preferredLanguage,
    required this.onLanguageChanged,
    required this.onPickDob,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController phoneController;
  final TextEditingController dobController;
  final TextEditingController bioController;
  final String preferredLanguage;
  final ValueChanged<String> onLanguageChanged;
  final VoidCallback onPickDob;

  @override
  Widget build(BuildContext context) {
    return ResSurfaceCard(
      child: Form(
        key: formKey,
        child: Column(
          children: [
            _FieldShell(
              label: 'Phone Number',
              child: TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: '+237 677 123 456',
                  prefixIcon: Icon(ResIcons.phone),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your phone number.'
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            _FieldShell(
              label: 'Date of Birth',
              child: TextFormField(
                controller: dobController,
                readOnly: true,
                onTap: onPickDob,
                decoration: const InputDecoration(
                  hintText: 'YYYY-MM-DD',
                  prefixIcon: Icon(Icons.calendar_month_outlined),
                  suffixIcon: Icon(Icons.chevron_right_rounded),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Select your date of birth.'
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            _FieldShell(
              label: 'Preferred Language',
              child: DropdownButtonFormField<String>(
                initialValue: preferredLanguage,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.translate_rounded),
                ),
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'fr', child: Text('French')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    onLanguageChanged(value);
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            _FieldShell(
              label: 'Short Bio',
              child: TextField(
                controller: bioController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'A short note about your property goals.',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecurityStep extends StatelessWidget {
  const _SecurityStep({
    required this.formKey,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.passwordVisible,
    required this.confirmPasswordVisible,
    required this.emailNotifications,
    required this.smsNotifications,
    required this.pushNotifications,
    required this.marketingNotifications,
    required this.onTogglePasswordVisibility,
    required this.onToggleConfirmPasswordVisibility,
    required this.onEmailNotificationsChanged,
    required this.onSmsNotificationsChanged,
    required this.onPushNotificationsChanged,
    required this.onMarketingNotificationsChanged,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool passwordVisible;
  final bool confirmPasswordVisible;
  final bool emailNotifications;
  final bool smsNotifications;
  final bool pushNotifications;
  final bool marketingNotifications;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onToggleConfirmPasswordVisibility;
  final ValueChanged<bool> onEmailNotificationsChanged;
  final ValueChanged<bool> onSmsNotificationsChanged;
  final ValueChanged<bool> onPushNotificationsChanged;
  final ValueChanged<bool> onMarketingNotificationsChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ResSurfaceCard(
          child: Form(
            key: formKey,
            child: Column(
              children: [
                _FieldShell(
                  label: 'Password',
                  child: TextFormField(
                    controller: passwordController,
                    obscureText: !passwordVisible,
                    decoration: InputDecoration(
                      hintText: 'Minimum 8 characters',
                      prefixIcon: const Icon(ResIcons.security),
                      suffixIcon: IconButton(
                        onPressed: onTogglePasswordVisibility,
                        icon: Icon(
                          passwordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    validator: (value) => value == null || value.length < 8
                        ? 'Use at least 8 characters.'
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                _FieldShell(
                  label: 'Confirm Password',
                  child: TextFormField(
                    controller: confirmPasswordController,
                    obscureText: !confirmPasswordVisible,
                    decoration: InputDecoration(
                      hintText: 'Repeat password',
                      prefixIcon: const Icon(ResIcons.security),
                      suffixIcon: IconButton(
                        onPressed: onToggleConfirmPasswordVisibility,
                        icon: Icon(
                          confirmPasswordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    validator: (value) => value != passwordController.text
                        ? 'Passwords do not match.'
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ResSurfaceCard(
          color: ResColors.muted,
          child: Column(
            children: [
              _PreferenceSwitch(
                title: 'Email notifications',
                value: emailNotifications,
                onChanged: onEmailNotificationsChanged,
              ),
              _PreferenceSwitch(
                title: 'SMS alerts',
                value: smsNotifications,
                onChanged: onSmsNotificationsChanged,
              ),
              _PreferenceSwitch(
                title: 'Push notifications',
                value: pushNotifications,
                onChanged: onPushNotificationsChanged,
              ),
              _PreferenceSwitch(
                title: 'Marketing updates',
                value: marketingNotifications,
                onChanged: onMarketingNotificationsChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.preferredLanguage,
    required this.acceptedTerms,
    required this.onTermsChanged,
  });

  final String fullName;
  final String email;
  final String phone;
  final String role;
  final String preferredLanguage;
  final bool acceptedTerms;
  final ValueChanged<bool> onTermsChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ResSurfaceCard(
          child: Column(
            children: [
              ResAvatar(
                name: fullName.isNotEmpty ? fullName : 'RE Secure',
                imageUrl: '',
                size: 88,
                borderColor: ResColors.background,
                backgroundColor: ResColors.primary,
              ),
              const SizedBox(height: 14),
              Text(
                fullName.isNotEmpty ? fullName : 'New account',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'You can upload your photo after sign-up by tapping the portrait area from Profile.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ResColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ResSurfaceCard(
          child: Column(
            children: [
              _ReviewRow(label: 'Name', value: fullName),
              _ReviewRow(label: 'Email', value: email),
              _ReviewRow(label: 'Phone', value: phone),
              _ReviewRow(label: 'Role', value: role),
              _ReviewRow(label: 'Language', value: preferredLanguage),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          value: acceptedTerms,
          onChanged: (value) => onTermsChanged(value ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('I agree to the secure marketplace terms'),
          subtitle: const Text(
            'I confirm the information is accurate and ready for verification.',
          ),
        ),
      ],
    );
  }
}

class _FieldShell extends StatelessWidget {
  const _FieldShell({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: selected
                ? ResColors.primary.withValues(alpha: 0.05)
                : ResColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? ResColors.primary : ResColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              if (selected)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: ResColors.primary,
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                      ),
                    ),
                    child: const Icon(
                      ResIcons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: selected
                          ? ResColors.primary
                          : ResColors.mutedForeground,
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
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: ResColors.mutedForeground),
            ),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

const _roles = <(String, String)>[
  ('buyer', 'Buyer'),
  ('seller', 'Seller'),
  ('lawyer', 'Lawyer'),
  ('notary', 'Notary'),
];
