import 'package:flutter/material.dart';

import '../../../../data/local_file_selection.dart';
import '../../../../ui/app_icons.dart';
import '../../../../ui/brand.dart';
import '../../../../ui/components/avatar.dart';
import '../../../../ui/components/buttons.dart';
import '../../../../ui/components/cards.dart';
import '../../../../ui/components/page_sections.dart';
import '../../consumer_controller.dart';
import '../../consumer_models.dart';

class ConsumerAccountInformationPage extends StatefulWidget {
  const ConsumerAccountInformationPage({
    super.key,
    required this.controller,
    required this.profile,
  });

  final ConsumerController controller;
  final ConsumerUserProfile profile;

  @override
  State<ConsumerAccountInformationPage> createState() =>
      _ConsumerAccountInformationPageState();
}

class _ConsumerAccountInformationPageState
    extends State<ConsumerAccountInformationPage> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _bioController;
  late String _preferredLanguage;
  late String _profileImagePreviewUrl;
  String? _profileImageAssetPath;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _firstNameController = TextEditingController(text: profile.firstName);
    _lastNameController = TextEditingController(text: profile.lastName);
    _phoneController = TextEditingController(text: profile.phoneNumber);
    _bioController = TextEditingController(text: profile.bio);
    _preferredLanguage = profile.preferredLanguage.isNotEmpty
        ? profile.preferredLanguage
        : 'en';
    _profileImagePreviewUrl = profile.profileImageUrl.trim();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = [
      _firstNameController.text.trim(),
      _lastNameController.text.trim(),
    ].where((part) => part.isNotEmpty).join(' ');
    final previewImage = _profileImagePreviewUrl.isNotEmpty
        ? _profileImagePreviewUrl
        : widget.profile.resolvedAvatarUrl;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                children: [
                  Row(
                    children: [
                      ResCircleIconButton(
                        icon: ResIcons.back,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Account information',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Edit the profile identity used across your secure workspace.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: ResColors.mutedForeground),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _pickAndUploadAvatar,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ResAvatar(
                              name: displayName.isNotEmpty
                                  ? displayName
                                  : widget.profile.displayName,
                              imageUrl: previewImage,
                              size: 82,
                              borderColor: Colors.white,
                              backgroundColor: Colors.white,
                            ),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: ResColors.primary,
                                    width: 2,
                                  ),
                                ),
                                child: _isUploadingAvatar
                                    ? const Padding(
                                        padding: EdgeInsets.all(8),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.camera_alt_outlined,
                                        color: ResColors.primary,
                                        size: 16,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName.isNotEmpty
                                  ? displayName
                                  : widget.profile.displayName,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.profile.email,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: ResColors.mutedForeground),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ResInfoChip(
                        label: widget.profile.emailVerified
                            ? 'Email verified'
                            : 'Email pending',
                        color: widget.profile.emailVerified
                            ? ResColors.secondary
                            : ResColors.accent,
                        icon: ResIcons.trust,
                      ),
                      ResInfoChip(
                        label: _preferredLanguage == 'fr'
                            ? 'French'
                            : 'English',
                        color: Colors.white,
                        icon: ResIcons.profile,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _ProfileSection(
                    title: 'Identity details',
                    subtitle:
                        'These fields shape the account profile reused in listings, transactions, and KYC.',
                    child: Column(
                      children: [
                        _LabeledField(
                          label: 'First name',
                          child: TextField(
                            controller: _firstNameController,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(ResIcons.profile),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _LabeledField(
                          label: 'Last name',
                          child: TextField(
                            controller: _lastNameController,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(ResIcons.profile),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _LabeledField(
                          label: 'Phone number',
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(ResIcons.phone),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _LabeledField(
                          label: 'Language',
                          child: DropdownButtonFormField<String>(
                            initialValue: _preferredLanguage,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.translate_rounded),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'en',
                                child: Text('English'),
                              ),
                              DropdownMenuItem(
                                value: 'fr',
                                child: Text('French'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() => _preferredLanguage = value);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _ProfileSection(
                    title: 'Public-facing bio',
                    subtitle:
                        'Use a short professional note that fits the trust-first tone of the product.',
                    child: _LabeledField(
                      label: 'Bio',
                      child: TextField(
                        controller: _bioController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText:
                              'Add a concise note about your goals or background.',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.edit_note_rounded),
                        ),
                      ),
                    ),
                  ),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 16),
                    _AccountStatusBanner(message: _statusMessage!),
                  ],
                  const SizedBox(height: 120),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                color: ResColors.background.withValues(alpha: 0.96),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(25, 28, 32, 0.06),
                    blurRadius: 24,
                    offset: Offset(0, -8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ResOutlineButton(
                      label: 'Discard',
                      icon: ResIcons.back,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ResPrimaryButton(
                      label: 'Save',
                      icon: ResIcons.check,
                      isBusy: _isSaving,
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    setState(() {
      _statusMessage = null;
      _isUploadingAvatar = true;
    });

    try {
      final file = await pickImageForUpload();
      if (file == null) {
        return;
      }
      final uploaded = await widget.controller.uploadAsset(
        category: 'profile_image',
        fileName: file.name,
        mimeType: file.mimeType,
        bytes: file.bytes,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _profileImagePreviewUrl = uploaded.publicUrl;
        _profileImageAssetPath = uploaded.storagePath;
        _statusMessage = 'Portrait uploaded. Save to apply it to your account.';
      });
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _statusMessage = null;
    });
    try {
      await widget.controller.saveProfile(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        phoneNumber: _phoneController.text,
        preferredLanguage: _preferredLanguage,
        bio: _bioController.text,
        profileImageUrl: _profileImageAssetPath,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Profile information updated.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ResSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResSectionHeader(title: title, subtitle: subtitle),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

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

class _AccountStatusBanner extends StatelessWidget {
  const _AccountStatusBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ResSurfaceCard(
      color: ResColors.secondary.withValues(alpha: 0.08),
      radius: 22,
      shadow: const [],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ResColors.secondary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(ResIcons.check, color: ResColors.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ResColors.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
