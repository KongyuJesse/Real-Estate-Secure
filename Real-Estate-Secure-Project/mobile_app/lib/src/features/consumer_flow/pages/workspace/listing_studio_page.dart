import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../data/consumer_api.dart';
import '../../../../data/consumer_draft_store.dart';
import '../../../../data/local_file_selection.dart';
import '../../../../ui/app_icons.dart';
import '../../../../ui/brand.dart';
import '../../../../ui/components/buttons.dart';
import '../../../../ui/components/cards.dart';
import '../../../../ui/components/location_map.dart';
import '../../../../ui/components/page_sections.dart';
import '../../../../ui/components/upload.dart';
import '../../consumer_controller.dart';
import '../../consumer_models.dart';
import 'cameroon_location_catalog.dart';
import 'listing_location_capture_page.dart';

class ConsumerListingStudioPage extends StatefulWidget {
  const ConsumerListingStudioPage({super.key, required this.controller});

  final ConsumerController controller;

  @override
  State<ConsumerListingStudioPage> createState() =>
      _ConsumerListingStudioPageState();
}

class _ConsumerListingStudioPageState extends State<ConsumerListingStudioPage> {
  static const _draftKey = 'consumer_draft_listing_studio';

  final ConsumerDraftStore _draftStore = SecureConsumerDraftStore();
  List<CameroonRegionCatalog> _locationCatalog = cameroonLocationCatalog;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _regionController;
  late final TextEditingController _departmentController;
  late final TextEditingController _cityController;
  late final TextEditingController _districtController;
  late final TextEditingController _streetController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _documentNumberController;
  late final TextEditingController _issuingAuthorityController;
  late final TextEditingController _documentTitleController;
  late final TextEditingController _documentIssueDateController;
  String _propertyType = 'house';
  String _listingType = 'sale';
  String _imageType = 'exterior';
  String _documentType = 'land_title';
  ConsumerUploadedAsset? _imageAsset;
  ConsumerUploadedAsset? _documentAsset;
  ConsumerUploadCapabilities _uploadCapabilities =
      defaultConsumerUploadCapabilities;
  String? _imageFileName;
  String? _documentFileName;
  LocalUploadQualityReport? _imageQuality;
  LocalUploadQualityReport? _documentQuality;
  bool _uploadingImage = false;
  bool _uploadingDocument = false;
  bool _submitting = false;
  String? _statusMessage;
  int _currentStepIndex = 0;

  List<_StudioOption> get _propertyTypeOptions => const [
    _StudioOption(value: 'house', label: 'House', icon: ResIcons.house),
    _StudioOption(value: 'land', label: 'Land', icon: ResIcons.land),
    _StudioOption(
      value: 'apartment',
      label: 'Apartment',
      icon: ResIcons.apartment,
    ),
    _StudioOption(
      value: 'commercial',
      label: 'Commercial',
      icon: ResIcons.commercial,
    ),
  ];

  List<_StudioOption> get _listingTypeOptions => const [
    _StudioOption(value: 'sale', label: 'Sale', icon: ResIcons.sale),
    _StudioOption(value: 'rent', label: 'Rent', icon: ResIcons.rent),
    _StudioOption(value: 'lease', label: 'Lease', icon: ResIcons.rent),
  ];

  List<String> get _regionOptions =>
      _locationCatalog.map((region) => region.name).toList(growable: false);

  CameroonRegionCatalog? get _selectedRegionData =>
      cameroonRegionNamedInCatalog(_locationCatalog, _regionController.text);

  CameroonDepartmentCatalog? get _selectedDepartmentData =>
      _selectedRegionData?.departmentNamed(_departmentController.text);

  CameroonCityCatalog? get _selectedCityData =>
      _selectedDepartmentData?.cityNamed(_cityController.text);

  List<String> get _departmentOptions =>
      (_selectedRegionData?.departments ?? [])
          .map((department) => department.name)
          .toList(growable: false);

  List<String> get _cityOptions => (_selectedDepartmentData?.cities ?? [])
      .map((city) => city.name)
      .toList(growable: false);

  List<String> get _districtOptions =>
      _selectedCityData?.districts.toList(growable: false) ?? const [];

  String? get _selectedRegion =>
      _validDropdownValue(_regionController.text, _regionOptions);

  String? get _selectedDepartment =>
      _validDropdownValue(_departmentController.text, _departmentOptions);

  String? get _selectedCity =>
      _validDropdownValue(_cityController.text, _cityOptions);

  String? get _selectedDistrict =>
      _validDropdownValue(_districtController.text, _districtOptions);

  double? get _capturedLatitude =>
      double.tryParse(_latitudeController.text.trim());

  double? get _capturedLongitude =>
      double.tryParse(_longitudeController.text.trim());

  bool get _hasCapturedMapPoint =>
      _capturedLatitude != null && _capturedLongitude != null;

  bool get _hasCoreBasics =>
      _titleController.text.trim().isNotEmpty &&
      _descriptionController.text.trim().isNotEmpty &&
      double.tryParse(_priceController.text.trim()) != null;

  bool get _hasLocationPackage =>
      _selectedRegion != null &&
      _selectedDepartment != null &&
      _selectedCity != null &&
      _hasCapturedMapPoint;

  bool get _hasVerificationPackage =>
      _imageAsset != null &&
      _documentAsset != null &&
      _documentTitleController.text.trim().isNotEmpty &&
      _documentNumberController.text.trim().isNotEmpty &&
      _issuingAuthorityController.text.trim().isNotEmpty &&
      _documentIssueDateController.text.trim().isNotEmpty;

  bool get _isLand => _propertyType == 'land';

  String get _pageTitle => _isLand ? 'List land' : 'List your property';

  String get _pageSubtitle => _isLand
      ? 'Map the parcel, add the key details, and attach one title file.'
      : 'Set the core details, add a strong photo, and attach one supporting file.';

  String get _basicsTitle => _isLand ? 'Land basics' : 'Property basics';

  String get _basicsSubtitle => _isLand
      ? 'Set the parcel story, price, and intent before you add the file.'
      : 'Set the headline, price, and listing intent before you add the file.';

  String get _locationSubtitle => _isLand
      ? 'Choose the official area, then capture the exact parcel point on-site.'
      : 'Choose the official area, then capture the exact property point on-site.';

  String get _visualTitle => _isLand ? 'Site visuals' : 'Visual proof';

  String get _visualSubtitle => _isLand
      ? 'Lead with one clear site image that shows access, boundaries, or surroundings.'
      : 'Lead with one polished hero photo that gives buyers confidence immediately.';

  String get _imageUploadTitle => _isLand ? 'Site photo' : 'Hero photo';

  String get _imageUploadSubtitle => _isLand
      ? 'Use a clear site shot, access-road photo, or aerial capture.'
      : 'Use one bright exterior image with a clean angle, straight lines, and no heavy filters.';

  String get _documentTitle => _isLand ? 'Land proof' : 'Legal evidence';

  String get _documentSubtitle => _isLand
      ? 'Attach one title, survey, or ownership file now. You can add more later.'
      : 'Attach one supporting file now. You can add more after the listing is created.';

  String get _documentUploadTitle =>
      _isLand ? 'Ownership file' : 'Legal document';

  String get _documentUploadSubtitle => _isLand
      ? 'Upload a land title, survey, mutation, or similar ownership file.'
      : 'Use live capture or upload a clear PDF or image of the main supporting file.';

  String get _titleHint =>
      _isLand ? 'Serviced plot in Bastos' : 'Modern villa in Bastos';

  String get _descriptionHint => _isLand
      ? 'Summarize access, terrain, neighborhood, utilities, and title strength.'
      : 'Describe the property, surroundings, and value signals clearly.';

  String get _streetLabel =>
      _isLand ? 'Access road or landmark' : 'Street or landmark';

  String get _locationNoteTitle => _isLand ? 'Parcel point' : 'Map point';

  String get _locationNoteBody => _isLand
      ? 'Pin the actual parcel, not the city center. This is what buyers and review teams rely on.'
      : 'Use the actual property point, not just a city center.';

  String get _mapCaptureActionLabel =>
      _hasCapturedMapPoint ? 'Rescan location' : 'Scan location';

  String get _mapCaptureStateLabel =>
      _hasCapturedMapPoint ? 'Map point saved' : 'Map point needed';

  String get _mapCaptureSupportText => _hasCapturedMapPoint
      ? 'Coordinates are stored from the Google Maps scan. Sellers do not type them manually.'
      : _isLand
      ? 'Stand at the land and run a live Google Maps scan before you continue.'
      : 'Stand at the property and run a live Google Maps scan before you continue.';

  String? get _selectedRegionMeta {
    final region = _selectedRegionData;
    if (region == null) {
      return null;
    }
    final parts = <String>[
      if (region.capital.trim().isNotEmpty) 'Capital: ${region.capital.trim()}',
      '${region.departments.length} departments',
    ];
    return parts.join(' • ');
  }

  String? get _selectedDepartmentMeta {
    final department = _selectedDepartmentData;
    if (department == null) {
      return null;
    }
    final cityCount = department.cities.length;
    if (cityCount <= 0) {
      return 'Official department selection';
    }
    return '$cityCount localities ready';
  }

  String? get _selectedCityMeta {
    final city = _selectedCityData;
    if (city == null) {
      return null;
    }
    if (city.districts.isEmpty) {
      return 'Select the street or landmark below';
    }
    return '${city.districts.length} districts available';
  }

  String get _reviewMapPointSummary => _hasCapturedMapPoint
      ? '${_capturedLatitude!.toStringAsFixed(6)}, ${_capturedLongitude!.toStringAsFixed(6)}'
      : 'Not captured';

  String get _reviewPhotoLabel => _isLand ? 'Site photo' : 'Hero photo';

  String get _reviewDocumentLabel => _isLand ? 'Ownership file' : 'Legal file';

  String get _vaultTitle => _uploadCapabilities.cloudEnabled
      ? (_isLand ? 'Cloud-backed land file' : 'Cloud-backed listing file')
      : (_isLand ? 'Secure land file' : 'Secure listing file');

  String get _vaultBody => _isLand
      ? (_uploadCapabilities.cloudEnabled
            ? 'Your draft stays on this device until you submit. Uploaded photos and title files sync securely to the cloud.'
            : 'Your draft stays on this device until you submit. Uploaded photos and title files stay protected and ready to attach.')
      : (_uploadCapabilities.cloudEnabled
            ? 'Your draft stays on this device until you submit. Uploaded photos and supporting files sync securely to the cloud.'
            : 'Your draft stays on this device until you submit. Uploaded photos and supporting files stay protected and ready to attach.');

  String get _vaultChipLabel =>
      _uploadCapabilities.cloudEnabled ? 'Cloud sync on' : 'Secure uploads';

  String get _submitLabel => _isLand ? 'Publish land' : 'Publish listing';

  String get _draftHint => _isLand
      ? 'Auto-draft is on. You can stop here and finish the land file later.'
      : 'Auto-draft is active. You can leave this screen and continue later.';

  bool get _hasFilesStepComplete => _hasVerificationPackage;

  String get _reviewLocationSummary {
    final parts = [_selectedDistrict, _selectedCity, _selectedRegion]
        .whereType<String>()
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return 'Not set';
    }
    return parts.join(', ');
  }

  List<_StudioOption> get _imageTypeOptions => _isLand
      ? const [
          _StudioOption(
            value: 'site_view',
            label: 'Site',
            icon: ResIcons.photo,
          ),
          _StudioOption(
            value: 'access_road',
            label: 'Access',
            icon: ResIcons.location,
          ),
          _StudioOption(value: 'aerial', label: 'Aerial', icon: ResIcons.video),
          _StudioOption(
            value: 'survey_plan',
            label: 'Survey',
            icon: ResIcons.document,
          ),
        ]
      : const [
          _StudioOption(
            value: 'exterior',
            label: 'Exterior',
            icon: ResIcons.photo,
          ),
          _StudioOption(
            value: 'interior',
            label: 'Interior',
            icon: ResIcons.photo,
          ),
          _StudioOption(value: 'drone', label: 'Drone', icon: ResIcons.video),
          _StudioOption(
            value: 'floor_plan',
            label: 'Floor plan',
            icon: ResIcons.document,
          ),
        ];

  List<_StudioOption> get _documentTypeOptions => _isLand
      ? const [
          _StudioOption(
            value: 'land_title',
            label: 'Land title',
            icon: ResIcons.document,
          ),
          _StudioOption(
            value: 'survey_plan',
            label: 'Survey plan',
            icon: ResIcons.map,
          ),
          _StudioOption(
            value: 'mutation',
            label: 'Mutation',
            icon: ResIcons.legal,
          ),
          _StudioOption(
            value: 'tax_clearance',
            label: 'Tax clearance',
            icon: ResIcons.receipt,
          ),
        ]
      : const [
          _StudioOption(
            value: 'land_title',
            label: 'Land title',
            icon: ResIcons.document,
          ),
          _StudioOption(
            value: 'survey_plan',
            label: 'Survey plan',
            icon: ResIcons.map,
          ),
          _StudioOption(
            value: 'tax_clearance',
            label: 'Tax clearance',
            icon: ResIcons.receipt,
          ),
          _StudioOption(
            value: 'non_encumbrance',
            label: 'Non-encumbrance',
            icon: ResIcons.legal,
          ),
        ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _priceController = TextEditingController();
    _regionController = TextEditingController();
    _departmentController = TextEditingController();
    _cityController = TextEditingController();
    _districtController = TextEditingController();
    _streetController = TextEditingController();
    _latitudeController = TextEditingController();
    _longitudeController = TextEditingController();
    _documentNumberController = TextEditingController();
    _issuingAuthorityController = TextEditingController();
    _documentTitleController = TextEditingController();
    _documentIssueDateController = TextEditingController();
    for (final controller in [
      _titleController,
      _descriptionController,
      _priceController,
      _regionController,
      _departmentController,
      _cityController,
      _districtController,
      _streetController,
      _latitudeController,
      _longitudeController,
      _documentNumberController,
      _issuingAuthorityController,
      _documentTitleController,
      _documentIssueDateController,
    ]) {
      controller.addListener(_persistDraft);
      controller.addListener(_refresh);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_restoreDraft());
      unawaited(_loadUploadCapabilities());
      unawaited(_loadLocationCatalog());
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _regionController.dispose();
    _departmentController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _streetController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _documentNumberController.dispose();
    _issuingAuthorityController.dispose();
    _documentTitleController.dispose();
    _documentIssueDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final steps = _flowSteps;
    final currentStep = steps[_currentStepIndex];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
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
                              _pageTitle,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _pageSubtitle,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: ResColors.mutedForeground),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        ResIcons.secure,
                        color: ResColors.softForeground,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _StudioOverviewCard(
                    propertyType: _propertyType,
                    listingType: _listingType,
                    typeLabel: _propertyTypeLabel(_propertyType),
                    listingLabel: _listingTypeLabel(_listingType),
                    currentStepTitle: currentStep.title,
                    currentStepIndex: _currentStepIndex,
                    stepCount: steps.length,
                    completedSteps: [
                      _hasCoreBasics,
                      _hasLocationPackage,
                      _hasFilesStepComplete,
                      _hasCoreBasics &&
                          _hasLocationPackage &&
                          _hasFilesStepComplete,
                    ],
                  ),
                  const SizedBox(height: 18),
                  _StudioStepRail(
                    steps: steps,
                    currentStepIndex: _currentStepIndex,
                    maxAccessibleStepIndex: _maxAccessibleStepIndex,
                    onTap: _handleStepTap,
                  ),
                  const SizedBox(height: 18),
                  _buildCurrentStep(context),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 16),
                    _StatusBanner(message: _statusMessage!),
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
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ResOutlineButton(
                          label: _currentStepIndex == 0 ? 'Close' : 'Back',
                          icon: _currentStepIndex == 0
                              ? ResIcons.back
                              : ResIcons.back,
                          isPill: true,
                          onPressed: _submitting
                              ? null
                              : _handleSecondaryAction,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ResPrimaryButton(
                          label: _primaryActionLabel,
                          icon: _currentStepIndex == _flowSteps.length - 1
                              ? ResIcons.arrowRight
                              : Icons.arrow_forward_rounded,
                          isBusy:
                              _submitting &&
                              _currentStepIndex == _flowSteps.length - 1,
                          onPressed: _submitting ? null : _handlePrimaryAction,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _draftHint,
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
  }

  List<_StudioFlowStep> get _flowSteps => [
    _StudioFlowStep(
      title: _isLand ? 'Land details' : 'Listing details',
      caption: 'Type, intent, and price',
      complete: _hasCoreBasics,
    ),
    _StudioFlowStep(
      title: 'Location',
      caption: 'Address and map point',
      complete: _hasLocationPackage,
    ),
    _StudioFlowStep(
      title: 'Files',
      caption: 'Photo and proof',
      complete: _hasFilesStepComplete,
    ),
    _StudioFlowStep(
      title: 'Review',
      caption: 'Check and submit',
      complete: _hasCoreBasics && _hasLocationPackage && _hasFilesStepComplete,
    ),
  ];

  String get _primaryActionLabel {
    switch (_currentStepIndex) {
      case 2:
        return 'Review';
      case 3:
        return _submitLabel;
      default:
        return 'Continue';
    }
  }

  int get _maxAccessibleStepIndex {
    if (!_hasCoreBasics) {
      return 0;
    }
    if (!_hasLocationPackage) {
      return 1;
    }
    if (!_hasFilesStepComplete) {
      return 2;
    }
    return 3;
  }

  String _lockedStepMessage(int index) {
    if (index >= 1 && !_hasCoreBasics) {
      return 'Finish the basics before moving forward.';
    }
    if (index >= 2 && !_hasLocationPackage) {
      return 'Finish the location and scan the map point before moving forward.';
    }
    if (index >= 3 && !_hasFilesStepComplete) {
      return 'Add the photo and ownership file before reviewing the listing.';
    }
    return 'Finish the current step before moving forward.';
  }

  void _handleStepTap(int index) {
    if (index > _maxAccessibleStepIndex) {
      setState(() {
        _statusMessage = _lockedStepMessage(index);
      });
      return;
    }
    setState(() {
      _currentStepIndex = index;
      _statusMessage = null;
    });
  }

  void _handleSecondaryAction() {
    if (_currentStepIndex == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _currentStepIndex -= 1;
      _statusMessage = null;
    });
  }

  void _handlePrimaryAction() {
    if (_currentStepIndex == 0 && !_hasCoreBasics) {
      setState(() {
        _statusMessage =
            'Add the title, description, and price before you continue.';
      });
      return;
    }
    if (_currentStepIndex == 1 && !_hasLocationPackage) {
      setState(() {
        _statusMessage =
            'Choose the address from the dropdowns and scan the map point before you continue.';
      });
      return;
    }
    if (_currentStepIndex == 2 && !_hasFilesStepComplete) {
      setState(() {
        _statusMessage =
            'Add the photo and ownership file before you move to review.';
      });
      return;
    }
    if (_currentStepIndex < _flowSteps.length - 1) {
      setState(() {
        _currentStepIndex += 1;
        _statusMessage = null;
      });
      return;
    }
    unawaited(_createListing());
  }

  Widget _buildCurrentStep(BuildContext context) {
    switch (_currentStepIndex) {
      case 0:
        return _buildBasicsStep(context);
      case 1:
        return _buildLocationStep(context);
      case 2:
        return _buildFilesStep(context);
      default:
        return _buildReviewStep(context);
    }
  }

  Widget _buildBasicsStep(BuildContext context) {
    return _StudioSection(
      title: _basicsTitle,
      subtitle: _basicsSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(text: 'Property type'),
          _StudioOptionDropdown(
            label: 'Property type',
            value: _propertyType,
            options: _propertyTypeOptions,
            onChanged: (value) {
              if (value != null) {
                _setPropertyType(value);
              }
            },
          ),
          const SizedBox(height: 18),
          _FieldLabel(text: 'Listing mode'),
          _StudioOptionDropdown(
            label: 'Listing mode',
            value: _listingType,
            options: _listingTypeOptions,
            onChanged: (value) {
              if (value != null) {
                _setListingType(value);
              }
            },
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Listing title',
              hintText: _titleHint,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _descriptionController,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: 'Description',
              hintText: _descriptionHint,
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Price in XAF',
              prefixIcon: Icon(ResIcons.wallet),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationStep(BuildContext context) {
    return _StudioSection(
      title: 'Location',
      subtitle: _locationSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Official area', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            'Pick the administrative area from the official Cameroon catalog, then capture the exact point on the map.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: ResColors.mutedForeground),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StudioStringDropdown(
                  label: 'Region',
                  value: _selectedRegion,
                  options: _regionOptions,
                  leadingIcon: ResIcons.map,
                  onChanged: _setRegionValue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StudioStringDropdown(
                  label: 'Department',
                  value: _selectedDepartment,
                  options: _departmentOptions,
                  enabled: _selectedRegion != null,
                  onChanged: _setDepartmentValue,
                ),
              ),
            ],
          ),
          if (_selectedRegionMeta != null) ...[
            const SizedBox(height: 8),
            Text(
              _selectedRegionMeta!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: ResColors.mutedForeground),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StudioStringDropdown(
                  label: 'City',
                  value: _selectedCity,
                  options: _cityOptions,
                  enabled: _selectedDepartment != null,
                  onChanged: _setCityValue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StudioStringDropdown(
                  label: 'District',
                  value: _selectedDistrict,
                  options: _districtOptions,
                  enabled: _districtOptions.isNotEmpty,
                  onChanged: _setDistrictValue,
                ),
              ),
            ],
          ),
          if (_selectedDepartmentMeta != null) ...[
            const SizedBox(height: 8),
            Text(
              _selectedDepartmentMeta!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: ResColors.mutedForeground),
            ),
          ],
          if (_selectedCityMeta != null) ...[
            const SizedBox(height: 8),
            Text(
              _selectedCityMeta!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: ResColors.mutedForeground),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _streetController,
            decoration: InputDecoration(labelText: _streetLabel),
          ),
          const SizedBox(height: 14),
          _StudioPanel(
            color: ResColors.surfaceContainerLow,
            padding: const EdgeInsets.all(18),
            radius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: ResColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        ResIcons.location,
                        color: ResColors.foreground,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _locationNoteTitle,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _locationNoteBody,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: ResColors.mutedForeground),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _CoordinateBadge(
                      label: 'Status',
                      value: _mapCaptureStateLabel,
                    ),
                    _CoordinateBadge(
                      label: 'Latitude',
                      value: _capturedLatitude?.toStringAsFixed(6) ?? 'Pending',
                    ),
                    _CoordinateBadge(
                      label: 'Longitude',
                      value:
                          _capturedLongitude?.toStringAsFixed(6) ?? 'Pending',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  _mapCaptureSupportText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ResColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ResOutlineButton(
                        label: _mapCaptureActionLabel,
                        icon: ResIcons.location,
                        isPill: true,
                        onPressed: _openLocationCapture,
                      ),
                    ),
                  ],
                ),
                if (_hasCapturedMapPoint) ...[
                  const SizedBox(height: 16),
                  ResStaticLocationMap(
                    latitude: _capturedLatitude,
                    longitude: _capturedLongitude,
                    title: _selectedCity ?? _locationNoteTitle,
                    height: 180,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesStep(BuildContext context) {
    return _StudioSection(
      title: 'Files',
      subtitle:
          'Add the lead photo and the ownership file before you send the listing for review.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_visualTitle, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            _visualSubtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: ResColors.mutedForeground),
          ),
          const SizedBox(height: 14),
          _PhotoDirectionCard(isLand: _isLand),
          const SizedBox(height: 14),
          ResUploadTile(
            title: _imageUploadTitle,
            subtitle: _imageUploadSubtitle,
            icon: ResIcons.photo,
            fileName: _imageFileName,
            isUploaded: _imageAsset != null,
            isBusy: _uploadingImage,
            actionLabel: _imageAsset != null ? 'Replace photo' : 'Choose photo',
            stateLabel: _imageAsset != null ? 'Ready' : 'Required',
            onPressed: _pickAndUploadImage,
          ),
          if (_imageQuality != null) ...[
            const SizedBox(height: 12),
            _QualityBanner(
              label: 'Listing photo quality',
              report: _imageQuality!,
            ),
          ],
          const SizedBox(height: 16),
          _FieldLabel(text: 'Photo type'),
          _StudioOptionDropdown(
            label: 'Photo type',
            value: _imageType,
            options: _imageTypeOptions,
            onChanged: (value) {
              if (value != null) {
                _setImageType(value);
              }
            },
          ),
          const SizedBox(height: 24),
          Text(_documentTitle, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            _documentSubtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: ResColors.mutedForeground),
          ),
          const SizedBox(height: 14),
          _FieldLabel(text: 'Document type'),
          _StudioOptionDropdown(
            label: 'Document type',
            value: _documentType,
            options: _documentTypeOptions,
            onChanged: (value) {
              if (value != null) {
                _setDocumentType(value);
              }
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _documentTitleController,
            decoration: const InputDecoration(labelText: 'Document title'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _documentNumberController,
            decoration: const InputDecoration(labelText: 'Document number'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _issuingAuthorityController,
            decoration: const InputDecoration(labelText: 'Issuing authority'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _documentIssueDateController,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Issue date',
              suffixIcon: Icon(Icons.calendar_month_outlined),
            ),
            onTap: _pickDocumentIssueDate,
          ),
          const SizedBox(height: 16),
          ResUploadTile(
            title: _documentUploadTitle,
            subtitle: _documentUploadSubtitle,
            icon: ResIcons.upload,
            fileName: _documentFileName,
            isUploaded: _documentAsset != null,
            isBusy: _uploadingDocument,
            actionLabel: _documentAsset != null
                ? 'Replace file'
                : 'Choose file',
            stateLabel: _documentAsset != null ? 'Ready' : 'Required',
            onPressed: _pickAndUploadDocument,
          ),
          if (_documentQuality != null) ...[
            const SizedBox(height: 12),
            _QualityBanner(
              label: 'Legal document quality',
              report: _documentQuality!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewStep(BuildContext context) {
    return Column(
      children: [
        _StudioSection(
          title: 'Review',
          subtitle:
              'Check the essentials before you create the listing. You can add more detail after this.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ResFeatureRow(
                icon: ResIcons.propertyType(_propertyType),
                label: 'Type',
                value: _propertyTypeLabel(_propertyType),
              ),
              const SizedBox(height: 12),
              ResFeatureRow(
                icon: ResIcons.listingType(_listingType),
                label: 'Listing mode',
                value: _listingTypeLabel(_listingType),
                tint: ResColors.secondary,
              ),
              const SizedBox(height: 12),
              ResFeatureRow(
                icon: ResIcons.wallet,
                label: 'Price',
                value: _priceController.text.trim().isEmpty
                    ? 'Not set'
                    : '${_priceController.text.trim()} XAF',
                tint: ResColors.tertiary,
              ),
              const SizedBox(height: 12),
              ResFeatureRow(
                icon: ResIcons.location,
                label: 'Location',
                value: _reviewLocationSummary,
                tint: ResColors.info,
              ),
              const SizedBox(height: 12),
              ResFeatureRow(
                icon: ResIcons.map,
                label: 'Map point',
                value: _reviewMapPointSummary,
                tint: ResColors.warning,
              ),
              const SizedBox(height: 12),
              ResFeatureRow(
                icon: ResIcons.photo,
                label: _reviewPhotoLabel,
                value: _imageFileName ?? 'Not added yet',
                tint: ResColors.primary,
              ),
              const SizedBox(height: 12),
              ResFeatureRow(
                icon: ResIcons.document,
                label: _reviewDocumentLabel,
                value: _documentFileName ?? 'Not added yet',
                tint: ResColors.secondary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _StudioPanel(
          color: ResColors.surfaceContainerLow,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: ResColors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(ResIcons.trust, color: ResColors.foreground),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ResInfoChip(
                      label: _vaultChipLabel,
                      color: ResColors.info,
                      icon: _uploadCapabilities.cloudEnabled
                          ? Icons.cloud_done_rounded
                          : ResIcons.secure,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _vaultTitle,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _vaultBody,
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
      ],
    );
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  void _setPropertyType(String value) {
    setState(() {
      _propertyType = value;
      if (value == 'land') {
        if (!_imageTypeOptions.any((option) => option.value == _imageType)) {
          _imageType = 'site_view';
        }
        if (!_documentTypeOptions.any(
          (option) => option.value == _documentType,
        )) {
          _documentType = 'land_title';
        }
      } else {
        if (!_imageTypeOptions.any((option) => option.value == _imageType)) {
          _imageType = 'exterior';
        }
        if (!_documentTypeOptions.any(
          (option) => option.value == _documentType,
        )) {
          _documentType = 'land_title';
        }
      }
      _statusMessage = null;
    });
    unawaited(_persistDraft());
  }

  void _setListingType(String value) {
    setState(() => _listingType = value);
    unawaited(_persistDraft());
  }

  void _setImageType(String value) {
    setState(() => _imageType = value);
    unawaited(_persistDraft());
  }

  void _setDocumentType(String value) {
    setState(() => _documentType = value);
    unawaited(_persistDraft());
  }

  void _setRegionValue(String? value) {
    if (_regionController.text.trim() == (value ?? '')) {
      return;
    }
    setState(() {
      _regionController.text = value ?? '';
      _departmentController.clear();
      _cityController.clear();
      _districtController.clear();
      _statusMessage = null;
    });
  }

  void _setDepartmentValue(String? value) {
    if (_departmentController.text.trim() == (value ?? '')) {
      return;
    }
    setState(() {
      _departmentController.text = value ?? '';
      _cityController.clear();
      _districtController.clear();
      _statusMessage = null;
    });
  }

  void _setCityValue(String? value) {
    if (_cityController.text.trim() == (value ?? '')) {
      return;
    }
    setState(() {
      _cityController.text = value ?? '';
      _districtController.clear();
      _statusMessage = null;
    });
  }

  void _setDistrictValue(String? value) {
    setState(() {
      _districtController.text = value ?? '';
      _statusMessage = null;
    });
  }

  Future<void> _loadLocationCatalog() async {
    final catalog = await widget.controller.loadCameroonLocationCatalog();
    if (!mounted || catalog.isEmpty) {
      return;
    }
    setState(() {
      _locationCatalog = catalog;
      _normalizeLocationSelection();
    });
  }

  void _normalizeLocationSelection() {
    final region = _validDropdownValue(_regionController.text, _regionOptions);
    if (region == null) {
      _regionController.clear();
      _departmentController.clear();
      _cityController.clear();
      _districtController.clear();
      return;
    }
    _regionController.text = region;

    final department = _validDropdownValue(
      _departmentController.text,
      _departmentOptions,
    );
    if (department == null) {
      _departmentController.clear();
      _cityController.clear();
      _districtController.clear();
      return;
    }
    _departmentController.text = department;

    final city = _validDropdownValue(_cityController.text, _cityOptions);
    if (city == null) {
      _cityController.clear();
      _districtController.clear();
      return;
    }
    _cityController.text = city;

    final district = _validDropdownValue(
      _districtController.text,
      _districtOptions,
    );
    if (district == null) {
      _districtController.clear();
      return;
    }
    _districtController.text = district;
  }

  Future<void> _openLocationCapture() async {
    final result = await Navigator.of(context)
        .push<ConsumerListingLocationCaptureResult>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => ConsumerListingLocationCapturePage(
              isLand: _isLand,
              initialLatitude: _capturedLatitude,
              initialLongitude: _capturedLongitude,
              cityLabel: _selectedCity,
            ),
          ),
        );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      _latitudeController.text = result.latitude.toStringAsFixed(6);
      _longitudeController.text = result.longitude.toStringAsFixed(6);
      _statusMessage = null;
    });
  }

  Future<void> _pickAndUploadImage() async {
    final picker = await _showUploadChoiceSheet(
      title: _imageUploadTitle,
      liveLabel: _isLand ? 'Capture site photo' : 'Take live photo',
      uploadLabel: 'Upload image',
      livePicker: () async {
        final granted = await _ensureCameraAccess();
        if (!granted) {
          return null;
        }
        return captureImageForUpload(useFrontCamera: false);
      },
      uploadPicker: pickImageForUpload,
    );
    if (picker == null) {
      return;
    }

    setState(() {
      _uploadingImage = true;
      _statusMessage = null;
    });
    try {
      final file = await picker();
      if (file == null) {
        return;
      }
      if (!_isWithinUploadLimit(file)) {
        return;
      }
      final quality = await assessImageForUpload(
        file,
        target: LocalImageQualityTarget.propertyPhoto,
      );
      if (!quality.isAcceptable) {
        if (!mounted) {
          return;
        }
        setState(() {
          _imageQuality = quality;
          _statusMessage = [quality.summary, ...quality.issues].join(' ');
        });
        return;
      }
      final asset = await widget.controller.uploadAsset(
        category: 'property_image',
        fileName: file.name,
        mimeType: file.mimeType,
        bytes: file.bytes,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _imageQuality = quality;
        _imageAsset = asset;
        _imageFileName = file.name;
        _statusMessage = _isLand
            ? 'Site photo uploaded. Your land file is ready for the next step.'
            : 'Listing photo uploaded. Your file is ready for the next step.';
      });
      await _persistDraft();
    } finally {
      if (mounted) {
        setState(() => _uploadingImage = false);
      }
    }
  }

  Future<void> _pickAndUploadDocument() async {
    final picker = await _showUploadChoiceSheet(
      title: _documentTitle,
      liveLabel: 'Take live scan',
      uploadLabel: 'Upload PDF or image',
      livePicker: () async {
        final granted = await _ensureCameraAccess();
        if (!granted) {
          return null;
        }
        return captureImageForUpload(useFrontCamera: false);
      },
      uploadPicker: pickDocumentForUpload,
    );
    if (picker == null) {
      return;
    }

    setState(() {
      _uploadingDocument = true;
      _statusMessage = null;
    });
    try {
      final file = await picker();
      if (file == null) {
        return;
      }
      if (!_isWithinUploadLimit(file)) {
        return;
      }
      LocalUploadQualityReport? quality;
      if (file.mimeType.startsWith('image/')) {
        final report = await assessImageForUpload(
          file,
          target: LocalImageQualityTarget.document,
        );
        quality = report;
        if (!report.isAcceptable) {
          if (!mounted) {
            return;
          }
          setState(() {
            _documentQuality = report;
            _statusMessage = [report.summary, ...report.issues].join(' ');
          });
          return;
        }
      }
      final asset = await widget.controller.uploadAsset(
        category: 'property_document',
        fileName: file.name,
        mimeType: file.mimeType,
        bytes: file.bytes,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _documentQuality = quality;
        _documentAsset = asset;
        _documentFileName = file.name;
        _statusMessage = _isLand
            ? 'Ownership file uploaded. The land file is ready for review.'
            : 'Legal file uploaded. The listing package is ready for review.';
      });
      await _persistDraft();
    } finally {
      if (mounted) {
        setState(() => _uploadingDocument = false);
      }
    }
  }

  Future<void> _pickDocumentIssueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1980),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      _documentIssueDateController.text = picked
          .toIso8601String()
          .split('T')
          .first;
      await _persistDraft();
    }
  }

  Future<bool> _ensureCameraAccess() async {
    final granted = await widget.controller.ensureCameraPermission();
    if (!granted && mounted) {
      setState(
        () => _statusMessage = widget.controller.cameraPermissionStatus.summary,
      );
    }
    return granted;
  }

  Future<Future<LocalUploadFile?> Function()?> _showUploadChoiceSheet({
    required String title,
    required String liveLabel,
    required String uploadLabel,
    required Future<LocalUploadFile?> Function() livePicker,
    required Future<LocalUploadFile?> Function() uploadPicker,
  }) {
    return showModalBottomSheet<Future<LocalUploadFile?> Function()>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Choose a live capture path or upload a clean file that is ready for review.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ResColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 16),
              _UploadChoiceTile(
                icon: Icons.photo_camera_back_rounded,
                title: liveLabel,
                subtitle: 'Camera permission is requested the first time.',
                onTap: () => Navigator.of(context).pop(livePicker),
              ),
              const SizedBox(height: 10),
              _UploadChoiceTile(
                icon: ResIcons.upload,
                title: uploadLabel,
                subtitle: 'Use this when the file is already clean and ready.',
                onTap: () => Navigator.of(context).pop(uploadPicker),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createListing() async {
    final price = double.tryParse(_priceController.text.trim());
    final latitude = _capturedLatitude;
    final longitude = _capturedLongitude;
    final region = _selectedRegion;
    final department = _selectedDepartment;
    final city = _selectedCity;
    final district = _selectedDistrict;
    if (_titleController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty ||
        price == null ||
        region == null ||
        department == null ||
        city == null ||
        !_hasFilesStepComplete ||
        latitude == null ||
        longitude == null) {
      setState(() {
        _currentStepIndex = !_hasCoreBasics
            ? 0
            : !_hasLocationPackage
            ? 1
            : 2;
        _statusMessage = !_hasFilesStepComplete
            ? 'Add the lead photo and ownership file before submitting.'
            : _isLand
            ? 'Complete the land basics, choose the location, and scan the parcel point before submitting.'
            : 'Complete the listing basics, choose the location, and scan the property point before submitting.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _statusMessage = null;
    });
    try {
      final propertyId = await widget.controller.createProperty(
        propertyType: _propertyType,
        listingType: _listingType,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: price,
        region: region,
        department: department,
        city: city,
        district: district,
        streetAddress: _streetController.text.trim().isEmpty
            ? null
            : _streetController.text.trim(),
        latitude: latitude,
        longitude: longitude,
      );

      if (_imageAsset != null) {
        await widget.controller.addPropertyImage(
          propertyId: propertyId,
          asset: _imageAsset!,
          imageType: _imageType,
          title: _titleController.text.trim(),
        );
      }

      if (_documentAsset != null &&
          _documentNumberController.text.trim().isNotEmpty &&
          _documentTitleController.text.trim().isNotEmpty &&
          _issuingAuthorityController.text.trim().isNotEmpty &&
          _documentIssueDateController.text.trim().isNotEmpty) {
        await widget.controller.addPropertyDocument(
          propertyId: propertyId,
          asset: _documentAsset!,
          documentType: _documentType,
          documentNumber: _documentNumberController.text.trim(),
          documentTitle: _documentTitleController.text.trim(),
          issuingAuthority: _issuingAuthorityController.text.trim(),
          issueDate: _documentIssueDateController.text.trim(),
        );
      }

      await widget.controller.submitPropertyForVerification(propertyId);
      await widget.controller.refreshMarketplace();
      await _draftStore.clear(_draftKey);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _restoreDraft() async {
    final draft = await _draftStore.read(_draftKey);
    if (draft == null || !mounted) {
      return;
    }
    setState(() {
      _propertyType = draft['property_type']?.toString() ?? _propertyType;
      _listingType = draft['listing_type']?.toString() ?? _listingType;
      _imageType = draft['image_type']?.toString() ?? _imageType;
      _documentType = draft['document_type']?.toString() ?? _documentType;
      _titleController.text = draft['title']?.toString() ?? '';
      _descriptionController.text = draft['description']?.toString() ?? '';
      _priceController.text = draft['price']?.toString() ?? '';
      _regionController.text = draft['region']?.toString() ?? '';
      _departmentController.text = draft['department']?.toString() ?? '';
      _cityController.text = draft['city']?.toString() ?? '';
      _districtController.text = draft['district']?.toString() ?? '';
      _streetController.text = draft['street']?.toString() ?? '';
      _latitudeController.text = draft['latitude']?.toString() ?? '';
      _longitudeController.text = draft['longitude']?.toString() ?? '';
      _documentNumberController.text =
          draft['document_number']?.toString() ?? '';
      _issuingAuthorityController.text =
          draft['issuing_authority']?.toString() ?? '';
      _documentTitleController.text = draft['document_title']?.toString() ?? '';
      _documentIssueDateController.text =
          draft['document_issue_date']?.toString() ?? '';
      _imageAsset = _draftAsset(draft['image_asset']);
      _documentAsset = _draftAsset(draft['document_asset']);
      _imageFileName = draft['image_file_name']?.toString();
      _documentFileName = draft['document_file_name']?.toString();
      _normalizeLocationSelection();
    });
  }

  Future<void> _loadUploadCapabilities() async {
    try {
      final capabilities = await widget.controller.loadUploadCapabilities();
      if (!mounted) {
        return;
      }
      setState(() {
        _uploadCapabilities = capabilities;
      });
    } on ConsumerApiFailure {
      if (!mounted) {
        return;
      }
      setState(() {
        _uploadCapabilities = defaultConsumerUploadCapabilities;
      });
    }
  }

  Future<void> _persistDraft() {
    return _draftStore.write(_draftKey, {
      'property_type': _propertyType,
      'listing_type': _listingType,
      'image_type': _imageType,
      'document_type': _documentType,
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'price': _priceController.text.trim(),
      'region': _regionController.text.trim(),
      'department': _departmentController.text.trim(),
      'city': _cityController.text.trim(),
      'district': _districtController.text.trim(),
      'street': _streetController.text.trim(),
      'latitude': _latitudeController.text.trim(),
      'longitude': _longitudeController.text.trim(),
      'document_number': _documentNumberController.text.trim(),
      'issuing_authority': _issuingAuthorityController.text.trim(),
      'document_title': _documentTitleController.text.trim(),
      'document_issue_date': _documentIssueDateController.text.trim(),
      'image_asset': _assetToDraft(_imageAsset),
      'document_asset': _assetToDraft(_documentAsset),
      'image_file_name': _imageFileName,
      'document_file_name': _documentFileName,
    });
  }

  Map<String, dynamic>? _assetToDraft(ConsumerUploadedAsset? asset) {
    if (asset == null) {
      return null;
    }
    return {
      'category': asset.category,
      'cloud_enabled': asset.cloudEnabled,
      'file_name': asset.fileName,
      'mime_type': asset.mimeType,
      'file_size': asset.fileSize,
      'file_hash': asset.fileHash,
      'storage_driver': asset.storageDriver,
      'storage_path': asset.storagePath,
      'public_url': asset.publicUrl,
      'uploaded_at': asset.uploadedAt?.toIso8601String(),
    };
  }

  ConsumerUploadedAsset? _draftAsset(Object? value) {
    if (value is Map<String, dynamic>) {
      return ConsumerUploadedAsset.fromJson(value);
    }
    if (value is Map) {
      return ConsumerUploadedAsset.fromJson(
        value.map((key, item) => MapEntry(key.toString(), item)),
      );
    }
    return null;
  }

  bool _isWithinUploadLimit(LocalUploadFile file) {
    if (file.bytes.length <= _uploadCapabilities.maxUploadBytes) {
      return true;
    }
    setState(() {
      _statusMessage =
          'This file is ${_formatFileSize(file.bytes.length)}. Keep uploads under ${_formatFileSize(_uploadCapabilities.maxUploadBytes)}.';
    });
    return false;
  }

  String _formatFileSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$bytes B';
  }

  String? _validDropdownValue(String rawValue, List<String> options) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return options.contains(trimmed) ? trimmed : null;
  }

  String _propertyTypeLabel(String value) {
    switch (value) {
      case 'land':
        return 'Land';
      case 'apartment':
        return 'Apartment';
      case 'commercial':
        return 'Commercial';
      default:
        return 'House';
    }
  }

  String _listingTypeLabel(String value) {
    switch (value) {
      case 'rent':
        return 'Rental';
      case 'lease':
        return 'Lease';
      default:
        return 'Sale';
    }
  }
}

class _StudioOption {
  const _StudioOption({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;
}

class _StudioFlowStep {
  const _StudioFlowStep({
    required this.title,
    required this.caption,
    required this.complete,
  });

  final String title;
  final String caption;
  final bool complete;
}

class _StudioPanel extends StatelessWidget {
  const _StudioPanel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color = ResColors.surfaceContainerLowest,
    this.radius = 26,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: ResColors.outlineVariant.withValues(alpha: 0.22),
        ),
      ),
      child: child,
    );
  }
}

class _StudioOverviewCard extends StatelessWidget {
  const _StudioOverviewCard({
    required this.propertyType,
    required this.listingType,
    required this.typeLabel,
    required this.listingLabel,
    required this.currentStepTitle,
    required this.currentStepIndex,
    required this.stepCount,
    required this.completedSteps,
  });

  final String propertyType;
  final String listingType;
  final String typeLabel;
  final String listingLabel;
  final String currentStepTitle;
  final int currentStepIndex;
  final int stepCount;
  final List<bool> completedSteps;

  @override
  Widget build(BuildContext context) {
    return _StudioPanel(
      color: ResColors.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ResInfoChip(
                label: typeLabel,
                color: ResColors.info,
                icon: ResIcons.propertyType(propertyType),
              ),
              ResInfoChip(
                label: listingLabel,
                color: ResColors.secondary,
                icon: ResIcons.listingType(listingType),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Step ${currentStepIndex + 1} of $stepCount',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: ResColors.softForeground),
          ),
          const SizedBox(height: 4),
          Text(
            currentStepTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(
              completedSteps.length,
              (index) => Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(
                    right: index == completedSteps.length - 1 ? 0 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: completedSteps[index]
                        ? ResColors.secondary
                        : index == currentStepIndex
                        ? ResColors.foreground
                        : ResColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioStepRail extends StatelessWidget {
  const _StudioStepRail({
    required this.steps,
    required this.currentStepIndex,
    required this.maxAccessibleStepIndex,
    required this.onTap,
  });

  final List<_StudioFlowStep> steps;
  final int currentStepIndex;
  final int maxAccessibleStepIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(
          steps.length,
          (index) => Padding(
            padding: EdgeInsets.only(right: index == steps.length - 1 ? 0 : 10),
            child: _StudioStepChip(
              step: steps[index],
              index: index,
              selected: index == currentStepIndex,
              enabled: index <= maxAccessibleStepIndex,
              onTap: () => onTap(index),
            ),
          ),
        ),
      ),
    );
  }
}

class _StudioStepChip extends StatelessWidget {
  const _StudioStepChip({
    required this.step,
    required this.index,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final _StudioFlowStep step;
  final int index;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? ResColors.foreground
        : step.complete
        ? ResColors.secondary.withValues(alpha: 0.30)
        : ResColors.outlineVariant.withValues(alpha: 0.24);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: 150,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? ResColors.surfaceContainerLow
                : ResColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STEP ${index + 1}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected
                      ? ResColors.foreground
                      : enabled
                      ? ResColors.softForeground
                      : ResColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                step.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: enabled
                      ? ResColors.foreground
                      : ResColors.softForeground,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                step.complete
                    ? 'Ready'
                    : enabled
                    ? step.caption
                    : 'Complete earlier steps',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: step.complete
                      ? ResColors.secondary
                      : enabled
                      ? ResColors.mutedForeground
                      : ResColors.softForeground,
                  fontWeight: step.complete ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudioSection extends StatelessWidget {
  const _StudioSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _StudioPanel(
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: ResColors.softForeground),
      ),
    );
  }
}

class _StudioOptionDropdown extends StatelessWidget {
  const _StudioOptionDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<_StudioOption> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      menuMaxHeight: 320,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      decoration: InputDecoration(labelText: label),
      items: options
          .map(
            (option) => DropdownMenuItem<String>(
              value: option.value,
              child: Row(
                children: [
                  Icon(option.icon, size: 18, color: ResColors.softForeground),
                  const SizedBox(width: 10),
                  Text(option.label),
                ],
              ),
            ),
          )
          .toList(growable: false),
      onChanged: onChanged,
    );
  }
}

class _StudioStringDropdown extends StatelessWidget {
  const _StudioStringDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.leadingIcon,
    this.enabled = true,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final IconData? leadingIcon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      menuMaxHeight: 320,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: leadingIcon == null ? null : Icon(leadingIcon),
      ),
      items: options
          .map(
            (option) =>
                DropdownMenuItem<String>(value: option, child: Text(option)),
          )
          .toList(growable: false),
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _CoordinateBadge extends StatelessWidget {
  const _CoordinateBadge({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ResColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: ResColors.foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PhotoDirectionCard extends StatelessWidget {
  const _PhotoDirectionCard({required this.isLand});

  final bool isLand;

  @override
  Widget build(BuildContext context) {
    final title = isLand ? 'What to show' : 'What makes a strong hero photo';
    final points = isLand
        ? const ['Access road', 'Boundary context', 'Clear daylight']
        : const ['Front exterior', 'Bright daylight', 'Straight framing'];

    return _StudioPanel(
      color: ResColors.surfaceContainerLow,
      padding: const EdgeInsets.all(16),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: points
                .map(
                  (point) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: ResColors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      point,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: ResColors.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _StudioPanel(
      color: ResColors.surfaceContainerLow,
      padding: const EdgeInsets.all(16),
      radius: 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ResColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(ResIcons.check, color: ResColors.foreground),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ResColors.foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QualityBanner extends StatelessWidget {
  const _QualityBanner({required this.label, required this.report});

  final String label;
  final LocalUploadQualityReport report;

  @override
  Widget build(BuildContext context) {
    final tint = report.isAcceptable ? ResColors.secondary : ResColors.tertiary;
    final icon = report.isAcceptable ? ResIcons.check : ResIcons.security;
    final details = report.issues.join(' ');
    return _StudioPanel(
      color: ResColors.surfaceContainerLow,
      padding: const EdgeInsets.all(16),
      radius: 20,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: ResColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: tint, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: tint,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  details.isEmpty
                      ? report.summary
                      : '${report.summary} $details',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadChoiceTile extends StatelessWidget {
  const _UploadChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ResColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: ResColors.outline.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ResColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: ResColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ResColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(ResIcons.arrowRight, color: ResColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
