import 'package:flutter/material.dart';

import '../../data/assisted_lane_api.dart';

const List<String> _offlineStepTypes = <String>[
  'notary_office_step',
  'municipal_certificate_step',
  'tax_registration_step',
  'mindcaf_filing_step',
  'court_case_step',
  'justice_execution_step',
  'commission_visit_step',
  'cadastral_validation_step',
];

const List<String> _offlineStatuses = <String>[
  'awaiting_notary_appointment',
  'awaiting_municipal_certificate',
  'awaiting_registration_receipt',
  'awaiting_mindcaf_filing',
  'awaiting_court_hearing',
  'awaiting_final_judgment',
  'awaiting_non_objection',
  'awaiting_commission_visit',
  'in_review',
  'completed',
  'blocked',
  'cancelled',
];

const List<String> _legalCaseTypes = <String>[
  'administrative_appeal',
  'administrative_litigation',
  'justice_execution',
  'succession_case',
  'judgment_enforcement',
  'domain_national_allocation',
  'old_title_regularization',
  'foreign_party_authorization',
];

const List<String> _legalCaseStatuses = <String>[
  'pending_filing',
  'active',
  'awaiting_decision',
  'resolved',
  'closed',
  'blocked',
];

const List<String> _workflowRoles = <String>[
  'notary',
  'admin',
  'lawyer',
  'seller',
  'buyer',
];

class AssistedLaneDashboardPage extends StatefulWidget {
  const AssistedLaneDashboardPage({
    super.key,
    this.initialSession,
    this.onSessionChanged,
    this.showScaffold = true,
    this.showInternalTabs = true,
    this.initialDeskIndex = 0,
  });

  final ApiSession? initialSession;
  final ValueChanged<ApiSession>? onSessionChanged;
  final bool showScaffold;
  final bool showInternalTabs;
  final int initialDeskIndex;

  @override
  State<AssistedLaneDashboardPage> createState() =>
      _AssistedLaneDashboardPageState();
}

class _AssistedLaneDashboardPageState extends State<AssistedLaneDashboardPage> {
  AssistedLaneApiClient? _apiInstance;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _tokenController;
  late final TextEditingController _transactionIdController;

  WorkspaceData? _workspace;
  ApiSession? _session;
  String? _errorMessage;
  bool _loading = false;
  bool _hasAutoLoadedInitialSession = false;

  AssistedLaneApiClient get _api => _apiInstance ??= AssistedLaneApiClient();

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController();
    _tokenController = TextEditingController();
    _transactionIdController = TextEditingController();
    _applySessionToControllers(widget.initialSession, useDefaultBaseUrl: true);
    _scheduleInitialLoad();
  }

  @override
  void didUpdateWidget(covariant AssistedLaneDashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.initialSession;
    final current = widget.initialSession;
    final sessionChanged =
        previous?.baseUrl != current?.baseUrl ||
        previous?.bearerToken != current?.bearerToken ||
        previous?.transactionId != current?.transactionId;

    if (sessionChanged) {
      _applySessionToControllers(current);
      _hasAutoLoadedInitialSession = false;
      _scheduleInitialLoad();
    }
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _tokenController.dispose();
    _transactionIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.showInternalTabs
        ? DefaultTabController(
            length: 3,
            initialIndex: widget.initialDeskIndex.clamp(0, 2),
            child: _buildDashboardSurface(context),
          )
        : _buildDashboardSurface(context);

    if (!widget.showScaffold) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assisted Lane Workspace'),
        actions: [
          IconButton(
            onPressed: _loading || _session == null ? null : _loadWorkspace,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh workspace',
          ),
        ],
        bottom: widget.showInternalTabs
            ? const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'Overview', icon: Icon(Icons.dashboard_outlined)),
                  Tab(text: 'Notary Desk', icon: Icon(Icons.gavel_outlined)),
                  Tab(
                    text: 'Admin Desk',
                    icon: Icon(Icons.admin_panel_settings),
                  ),
                ],
              )
            : null,
      ),
      body: SafeArea(child: content),
    );
  }

  Widget _buildDashboardSurface(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 520;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, compact ? 12 : 16, 16, 0),
          child: Column(
            children: [
              _buildConnectionCard(context, compact: compact),
              if (_errorMessage case final message?)
                Padding(
                  padding: EdgeInsets.only(top: compact ? 8 : 12),
                  child: _StatusBanner(
                    tone: _BannerTone.warning,
                    title: 'Workspace needs attention',
                    message: message,
                  ),
                ),
              SizedBox(height: compact ? 8 : 12),
              Expanded(
                child: widget.showInternalTabs
                    ? TabBarView(
                        children: [
                          _buildOverviewTab(context),
                          _buildNotaryDesk(context),
                          _buildAdminDesk(context),
                        ],
                      )
                    : _buildDeskForIndex(
                        context,
                        widget.initialDeskIndex.clamp(0, 2),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeskForIndex(BuildContext context, int index) => switch (index) {
    1 => _buildNotaryDesk(context),
    2 => _buildAdminDesk(context),
    _ => _buildOverviewTab(context),
  };

  Widget _buildConnectionCard(BuildContext context, {required bool compact}) {
    final cardPadding = compact ? 16.0 : 20.0;
    final sectionSpacing = compact ? 16.0 : 20.0;
    final fieldSpacing = compact ? 10.0 : 12.0;
    final restoredSessionReady = widget.initialSession != null;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connect To A Transaction Workspace',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF163328),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Load a transaction and manage notary-led physical steps, court-linked cases, and assisted-lane freeze conditions from one place.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF5C635B),
                height: 1.4,
              ),
            ),
            if (restoredSessionReady) ...[
              const SizedBox(height: 10),
              Text(
                'Saved operator session restored. Load will reuse the stored base URL, token, and transaction context.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF1E5A43),
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],
            SizedBox(height: sectionSpacing),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 820 && !compact;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildBaseUrlField()),
                      SizedBox(width: fieldSpacing),
                      Expanded(child: _buildTokenField()),
                      SizedBox(width: fieldSpacing),
                      Expanded(child: _buildTransactionIdField()),
                      SizedBox(width: fieldSpacing),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _loadWorkspace,
                          icon: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.sync_alt_rounded),
                          label: Text(_loading ? 'Loading' : 'Load'),
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    _buildBaseUrlField(),
                    SizedBox(height: fieldSpacing),
                    _buildTokenField(),
                    SizedBox(height: fieldSpacing),
                    _buildTransactionIdField(),
                    SizedBox(height: fieldSpacing),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _loadWorkspace,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.sync_alt_rounded),
                        label: Text(
                          _loading ? 'Loading workspace' : 'Load workspace',
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _applySessionToControllers(
    ApiSession? session, {
    bool useDefaultBaseUrl = false,
  }) {
    final fallbackBaseUrl = useDefaultBaseUrl ? 'http://localhost:8080/v1' : '';
    _baseUrlController.text = session?.baseUrl.trim().isNotEmpty == true
        ? session!.baseUrl
        : fallbackBaseUrl;
    _tokenController.text = session?.bearerToken ?? '';
    _transactionIdController.text = session?.transactionId ?? '';
  }

  void _scheduleInitialLoad() {
    if (_hasAutoLoadedInitialSession) {
      return;
    }
    final session = widget.initialSession;
    if (session == null || !_isValidSession(session)) {
      return;
    }
    _hasAutoLoadedInitialSession = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _loading) {
        return;
      }
      _loadWorkspace();
    });
  }

  bool _isValidSession(ApiSession session) =>
      session.baseUrl.trim().isNotEmpty &&
      session.bearerToken.trim().isNotEmpty &&
      session.transactionId.trim().isNotEmpty;

  Widget _buildBaseUrlField() {
    return TextField(
      controller: _baseUrlController,
      decoration: const InputDecoration(
        labelText: 'API base URL',
        hintText: 'http://localhost:8080/v1',
        prefixIcon: Icon(Icons.link_rounded),
      ),
    );
  }

  Widget _buildTokenField() {
    return TextField(
      controller: _tokenController,
      obscureText: true,
      decoration: const InputDecoration(
        labelText: 'Bearer token',
        hintText: 'Paste access token',
        prefixIcon: Icon(Icons.lock_outline_rounded),
      ),
    );
  }

  Widget _buildTransactionIdField() {
    return TextField(
      controller: _transactionIdController,
      decoration: const InputDecoration(
        labelText: 'Transaction ID',
        hintText: 'Transaction UUID',
        prefixIcon: Icon(Icons.confirmation_number_outlined),
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context) {
    if (_workspace == null) {
      return const _EmptyPanel(
        icon: Icons.account_tree_outlined,
        title: 'No workspace loaded',
        message:
            'Load a transaction to see the assisted-lane compliance profile, offline filing steps, and court-linked case load.',
      );
    }

    final compliance = _workspace!.compliance;
    final requiredDocuments = _stringList(compliance['required_documents']);
    final requiredActions = _stringList(compliance['required_actions']);
    final recommendedServices = _stringList(compliance['recommended_services']);
    final flags = _stringList(compliance['flags']);
    final notes = _noteList(compliance['notes']);
    final automationFrozen = _boolValue(compliance['automation_frozen']);
    final offlineRequired = _boolValue(compliance['offline_workflow_required']);
    final assistedLaneRequired = _boolValue(
      compliance['assisted_lane_required'],
    );
    final freezeReason = _stringValue(compliance['automation_freeze_reason']);

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        _WorkspaceHero(
          transactionId:
              _stringValue(compliance['transaction_id']) ?? 'Unknown',
          closingStage:
              _stringValue(compliance['closing_stage']) ?? 'not_started',
          caseType: _stringValue(compliance['case_type']) ?? 'standard_sale',
          settlementMode:
              _stringValue(compliance['settlement_mode']) ?? 'platform_escrow',
          automationFrozen: automationFrozen,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth >= 940
                ? (constraints.maxWidth - 24) / 4
                : constraints.maxWidth >= 620
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricCard(
                  width: cardWidth,
                  label: 'Lawyer Requirement',
                  value:
                      (_stringValue(compliance['lawyer_requirement_level']) ??
                              'not_required')
                          .humanized(),
                  icon: Icons.balance_outlined,
                ),
                _MetricCard(
                  width: cardWidth,
                  label: 'Notary Requirement',
                  value:
                      (_stringValue(compliance['notary_requirement_level']) ??
                              'required')
                          .humanized(),
                  icon: Icons.approval_outlined,
                ),
                _MetricCard(
                  width: cardWidth,
                  label: 'Offline Steps',
                  value: (_workspace!.offlineSteps.length).toString(),
                  icon: Icons.holiday_village_outlined,
                ),
                _MetricCard(
                  width: cardWidth,
                  label: 'Legal Cases',
                  value: (_workspace!.legalCases.length).toString(),
                  icon: Icons.folder_special_outlined,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        if (automationFrozen ||
            offlineRequired ||
            assistedLaneRequired ||
            freezeReason != null)
          Column(
            children: [
              _StatusBanner(
                tone: automationFrozen ? _BannerTone.warning : _BannerTone.info,
                title: automationFrozen
                    ? 'Automation is frozen'
                    : 'Assisted controls active',
                message: [
                  ?freezeReason,
                  if (assistedLaneRequired)
                    'This file stays in the assisted legal lane and should be coordinated as evidence and workflow, not direct government processing.',
                  if (offlineRequired)
                    'At least one physical or office-based step is still expected before title-transfer completion.',
                ].join(' '),
              ),
              const SizedBox(height: 16),
            ],
          ),
        if (flags.isNotEmpty) ...[
          _SectionCard(
            title: 'Active Compliance Flags',
            subtitle:
                'These flags are driving the assisted-lane logic for this file.',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: flags
                  .map(
                    (flag) => Chip(
                      avatar: const Icon(Icons.flag_outlined, size: 18),
                      label: Text(flag.humanized()),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: 16),
        ],
        _SectionCard(
          title: 'Required Actions',
          subtitle:
              'Operational steps the team needs to track before the file can move forward.',
          child: _BulletColumn(items: requiredActions),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Required Documents',
          subtitle:
              'Evidence the platform expects to receive and store before closing can progress.',
          child: _BulletColumn(items: requiredDocuments),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Recommended Services',
          subtitle:
              'Commercial services the platform can offer without relying on transaction-fee monetization.',
          child: _BulletColumn(items: recommendedServices),
        ),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Compliance Notes',
            subtitle:
                'Short legal-operational guidance generated from the backend rule engine.',
            child: Column(
              children: notes
                  .map(
                    (note) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            note.levelIcon,
                            size: 20,
                            color: note.levelColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  note.level.humanized(),
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF163328),
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  note.message,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.copyWith(height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNotaryDesk(BuildContext context) {
    if (_workspace == null || _session == null) {
      return const _EmptyPanel(
        icon: Icons.gavel_outlined,
        title: 'Notary desk locked',
        message:
            'Load a workspace to seed and update physical filing steps such as notary appointments, municipal certificates, registration receipts, and MINDCAF follow-ups.',
      );
    }

    final steps = _workspace!.offlineSteps;

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        _DeskHeader(
          title: 'Notary-led physical workflow',
          subtitle:
              'Track every office-based step as evidence, with dates and oversight flags that keep the platform honest about what still happens offline.',
          primaryActionLabel: 'Add offline step',
          primaryActionIcon: Icons.add_task_rounded,
          onPrimaryAction: _loading ? null : _createOfflineStep,
        ),
        const SizedBox(height: 16),
        if (steps.isEmpty)
          const _EmptyPanel(
            icon: Icons.inventory_2_outlined,
            title: 'No offline steps yet',
            message:
                'Create the first step when the file needs a notary appointment, municipal certificate, tax filing, MINDCAF submission, or other physical workflow milestone.',
          )
        else
          ...steps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _WorkflowCard(
                title: step.stepType.humanized(),
                status: step.physicalStatus.humanized(),
                statusColor: _statusColor(step.physicalStatus),
                details: [
                  _labelValue('Expected office', step.expectedOffice),
                  _labelValue('Assigned role', step.assignedRole?.humanized()),
                  _labelValue('Filing date', step.filingDate?.dateLabel),
                  _labelValue('Scheduled at', step.scheduledAt?.dateTimeLabel),
                  _labelValue(
                    'Next follow-up',
                    step.nextFollowUpDate?.dateLabel,
                  ),
                  _labelValue('Delay reason', step.delayReason),
                  _labelValue('Notes', step.notes),
                ],
                badges: [
                  if (step.originalRequired) 'Original document required',
                  if (step.oversightRequired) 'Oversight required',
                  if (step.completedAt != null)
                    'Completed ${step.completedAt!.dateTimeLabel}',
                ],
                actionLabel: 'Update status',
                actionIcon: Icons.edit_note_rounded,
                onAction: _loading ? null : () => _updateOfflineStep(step),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAdminDesk(BuildContext context) {
    if (_workspace == null || _session == null) {
      return const _EmptyPanel(
        icon: Icons.admin_panel_settings_outlined,
        title: 'Admin desk locked',
        message:
            'Load a workspace to open assisted legal cases, freeze automation when needed, and coordinate disputed, foreign-party, court-linked, or ministry-dependent files.',
      );
    }

    final legalCases = _workspace!.legalCases;

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        _DeskHeader(
          title: 'Admin and legal oversight',
          subtitle:
              'Manage appeal, litigation, justice-execution, succession, foreign-party, and old-title cases without pretending the platform is the transfer agent.',
          primaryActionLabel: 'Add legal case',
          primaryActionIcon: Icons.add_moderator_outlined,
          onPrimaryAction: _loading ? null : _createLegalCase,
        ),
        const SizedBox(height: 16),
        if (legalCases.isEmpty)
          const _EmptyPanel(
            icon: Icons.policy_outlined,
            title: 'No legal cases yet',
            message:
                'Create a legal case when a file enters appeal, litigation, justice execution, succession, old-title regularization, or foreign authorization handling.',
          )
        else
          ...legalCases.map(
            (legalCase) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _WorkflowCard(
                title: legalCase.caseType.humanized(),
                status: legalCase.status.humanized(),
                statusColor: _statusColor(legalCase.status),
                details: [
                  _labelValue('Expected office', legalCase.expectedOffice),
                  _labelValue('Reference number', legalCase.referenceNumber),
                  _labelValue('Court or venue', legalCase.courtName),
                  _labelValue('Filing date', legalCase.filingDate?.dateLabel),
                  _labelValue(
                    'Next follow-up',
                    legalCase.nextFollowUpDate?.dateLabel,
                  ),
                  _labelValue(
                    'Final decision',
                    legalCase.finalDecisionDate?.dateLabel,
                  ),
                  _labelValue('Delay reason', legalCase.delayReason),
                  _labelValue('Notes', legalCase.notes),
                ],
                badges: [
                  if (legalCase.freezesAutomation) 'Freezes automation',
                  if (legalCase.requiresAdminOversight)
                    'Admin oversight required',
                ],
                actionLabel: 'Update case',
                actionIcon: Icons.rule_folder_outlined,
                onAction: _loading ? null : () => _updateLegalCase(legalCase),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _loadWorkspace() async {
    final session = _buildSession();
    if (session == null) {
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final workspace = await _api.loadWorkspace(session);
      if (!mounted) {
        return;
      }
      setState(() {
        _session = session;
        _workspace = workspace;
      });
      widget.onSessionChanged?.call(session);
      _showSnack('Workspace loaded.');
    } on ApiFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
      _showSnack(error.message, isError: true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      const fallback = 'Unable to load the assisted-lane workspace.';
      setState(() {
        _errorMessage = fallback;
      });
      _showSnack('$fallback $error', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  ApiSession? _buildSession() {
    final baseUrl = _baseUrlController.text.trim();
    final transactionId = _transactionIdController.text.trim();
    final token = _tokenController.text.trim();

    if (baseUrl.isEmpty || transactionId.isEmpty) {
      final message =
          'API base URL and transaction ID are required before the workspace can load.';
      setState(() {
        _errorMessage = message;
      });
      _showSnack(message, isError: true);
      return null;
    }

    return ApiSession(
      baseUrl: baseUrl,
      bearerToken: token,
      transactionId: transactionId,
    );
  }

  Future<void> _createOfflineStep() async {
    final draft = await showDialog<_OfflineStepDraft>(
      context: context,
      builder: (context) => const _OfflineStepDialog(),
    );
    if (draft == null || _session == null) {
      return;
    }

    await _runMutation(
      message: 'Offline step created.',
      action: () => _api.createOfflineStep(
        _session!,
        stepType: draft.stepType,
        physicalStatus: draft.status,
        expectedOffice: draft.expectedOffice,
        assignedRole: draft.assignedRole,
        notes: draft.notes,
        filingDate: draft.filingDate,
        scheduledAt: draft.scheduledAt,
        nextFollowUpDate: draft.nextFollowUpDate,
        originalRequired: draft.originalRequired,
        oversightRequired: draft.oversightRequired,
      ),
    );
  }

  Future<void> _updateOfflineStep(OfflineStepRecord step) async {
    final update = await showDialog<_OfflineStatusUpdate>(
      context: context,
      builder: (context) => _OfflineStatusDialog(step: step),
    );
    if (update == null || _session == null) {
      return;
    }

    await _runMutation(
      message: 'Offline step updated.',
      action: () => _api.updateOfflineStepStatus(
        _session!,
        stepId: step.id,
        physicalStatus: update.status,
        delayReason: update.delayReason,
        notes: update.notes,
        filingDate: update.filingDate,
        scheduledAt: update.scheduledAt,
        nextFollowUpDate: update.nextFollowUpDate,
      ),
    );
  }

  Future<void> _createLegalCase() async {
    final draft = await showDialog<_LegalCaseDraft>(
      context: context,
      builder: (context) => const _LegalCaseDialog(),
    );
    if (draft == null || _session == null) {
      return;
    }

    await _runMutation(
      message: 'Legal case created.',
      action: () => _api.createLegalCase(
        _session!,
        caseType: draft.caseType,
        status: draft.status,
        expectedOffice: draft.expectedOffice,
        referenceNumber: draft.referenceNumber,
        courtName: draft.courtName,
        notes: draft.notes,
        delayReason: draft.delayReason,
        filingDate: draft.filingDate,
        nextFollowUpDate: draft.nextFollowUpDate,
        finalDecisionDate: draft.finalDecisionDate,
        freezesAutomation: draft.freezesAutomation,
        requiresAdminOversight: draft.requiresAdminOversight,
      ),
    );
  }

  Future<void> _updateLegalCase(LegalCaseRecord legalCase) async {
    final update = await showDialog<_LegalCaseStatusUpdate>(
      context: context,
      builder: (context) => _LegalCaseStatusDialog(legalCase: legalCase),
    );
    if (update == null || _session == null) {
      return;
    }

    await _runMutation(
      message: 'Legal case updated.',
      action: () => _api.updateLegalCaseStatus(
        _session!,
        caseId: legalCase.id,
        status: update.status,
        delayReason: update.delayReason,
        referenceNumber: update.referenceNumber,
        courtName: update.courtName,
        notes: update.notes,
        filingDate: update.filingDate,
        nextFollowUpDate: update.nextFollowUpDate,
        finalDecisionDate: update.finalDecisionDate,
      ),
    );
  }

  Future<void> _runMutation({
    required String message,
    required Future<void> Function() action,
  }) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await action();
      await _loadWorkspace();
      if (!mounted) {
        return;
      }
      _showSnack(message);
    } on ApiFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
      _showSnack(error.message, isError: true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      const fallback = 'The workspace action could not be completed.';
      setState(() {
        _errorMessage = fallback;
      });
      _showSnack('$fallback $error', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFF8E2D2D) : null,
      ),
    );
  }
}

class _WorkspaceHero extends StatelessWidget {
  const _WorkspaceHero({
    required this.transactionId,
    required this.closingStage,
    required this.caseType,
    required this.settlementMode,
    required this.automationFrozen,
  });

  final String transactionId;
  final String closingStage;
  final String caseType;
  final String settlementMode;
  final bool automationFrozen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E5A43), Color(0xFF316F57), Color(0xFFB68A3D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assisted Lane Workspace',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This dashboard keeps the platform aligned with Cameroon reality: notary-led closing, evidence-based progress, and explicit handling for physical or court-linked steps.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroPill(label: 'Transaction', value: transactionId),
              _HeroPill(
                label: 'Closing stage',
                value: closingStage.humanized(),
              ),
              _HeroPill(label: 'Case type', value: caseType.humanized()),
              _HeroPill(label: 'Settlement', value: settlementMode.humanized()),
              _HeroPill(
                label: 'Automation',
                value: automationFrozen ? 'Frozen' : 'Active',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F0EA),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: const Color(0xFF1E5A43)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF5C635B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF163328),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF163328),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF5C635B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _BulletColumn extends StatelessWidget {
  const _BulletColumn({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(
        'No items currently required.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Icon(
                      Icons.circle,
                      size: 8,
                      color: Color(0xFFB68A3D),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.humanized(),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _DeskHeader extends StatelessWidget {
  const _DeskHeader({
    required this.title,
    required this.subtitle,
    required this.primaryActionLabel,
    required this.primaryActionIcon,
    required this.onPrimaryAction,
  });

  final String title;
  final String subtitle;
  final String primaryActionLabel;
  final IconData primaryActionIcon;
  final VoidCallback? onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stack = constraints.maxWidth < 720;
            final header = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF163328),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF5C635B),
                    height: 1.4,
                  ),
                ),
              ],
            );

            final action = FilledButton.icon(
              onPressed: onPrimaryAction,
              icon: Icon(primaryActionIcon),
              label: Text(primaryActionLabel),
            );

            if (stack) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [header, const SizedBox(height: 16), action],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: header),
                const SizedBox(width: 16),
                action,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WorkflowCard extends StatelessWidget {
  const _WorkflowCard({
    required this.title,
    required this.status,
    required this.statusColor,
    required this.details,
    required this.badges,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
  });

  final String title;
  final String status;
  final Color statusColor;
  final List<_DetailLine> details;
  final List<String> badges;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final filteredDetails = details
        .where((item) => item.value != null)
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF163328),
                            ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              status,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          ...badges.map(
                            (badge) => Chip(
                              label: Text(badge),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: onAction,
                  icon: Icon(actionIcon),
                  label: Text(actionLabel),
                ),
              ],
            ),
            if (filteredDetails.isNotEmpty) ...[
              const SizedBox(height: 18),
              ...filteredDetails.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: const Color(0xFF5C635B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        line.value!,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(height: 1.35),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.tone,
    required this.title,
    required this.message,
  });

  final _BannerTone tone;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      _BannerTone.warning => const Color(0xFF8E5B16),
      _BannerTone.info => const Color(0xFF1E5A43),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            tone == _BannerTone.warning
                ? Icons.warning_amber_rounded
                : Icons.info_outline_rounded,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF394239),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F0EA),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(icon, size: 32, color: const Color(0xFF1E5A43)),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF163328),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF5C635B),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineStepDialog extends StatefulWidget {
  const _OfflineStepDialog();

  @override
  State<_OfflineStepDialog> createState() => _OfflineStepDialogState();
}

class _OfflineStepDialogState extends State<_OfflineStepDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _expectedOfficeController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _filingDateController = TextEditingController();
  final TextEditingController _scheduledAtController = TextEditingController();
  final TextEditingController _nextFollowUpDateController =
      TextEditingController();

  String _stepType = _offlineStepTypes.first;
  String _status = _offlineStatuses.first;
  String _assignedRole = _workflowRoles.first;
  bool _originalRequired = false;
  bool _oversightRequired = false;

  @override
  void dispose() {
    _expectedOfficeController.dispose();
    _notesController.dispose();
    _filingDateController.dispose();
    _scheduledAtController.dispose();
    _nextFollowUpDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FormDialog(
      title: 'Add offline step',
      subtitle:
          'Use this for notary appointments, tax registration, municipal certificates, MINDCAF filing, or other physical milestones.',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _stepType,
              decoration: const InputDecoration(labelText: 'Step type'),
              items: _offlineStepTypes
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(item.humanized()),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() {
                _stepType = value ?? _stepType;
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Physical status'),
              items: _offlineStatuses
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(item.humanized()),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() {
                _status = value ?? _status;
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _assignedRole,
              decoration: const InputDecoration(labelText: 'Assigned role'),
              items: _workflowRoles
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(item.humanized()),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() {
                _assignedRole = value ?? _assignedRole;
              }),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _expectedOfficeController,
              decoration: const InputDecoration(
                labelText: 'Expected office',
                hintText: 'Notary office, municipal office, MINDCAF desk...',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _filingDateController,
              decoration: const InputDecoration(
                labelText: 'Filing date',
                hintText: 'YYYY-MM-DD',
              ),
              validator: _optionalDateValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _scheduledAtController,
              decoration: const InputDecoration(
                labelText: 'Scheduled at',
                hintText: 'YYYY-MM-DD or ISO datetime',
              ),
              validator: _optionalDateValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nextFollowUpDateController,
              decoration: const InputDecoration(
                labelText: 'Next follow-up',
                hintText: 'YYYY-MM-DD',
              ),
              validator: _optionalDateValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Operational notes for the notary or case team',
              ),
            ),
            SwitchListTile.adaptive(
              value: _originalRequired,
              contentPadding: EdgeInsets.zero,
              title: const Text('Original document required'),
              onChanged: (value) => setState(() {
                _originalRequired = value;
              }),
            ),
            SwitchListTile.adaptive(
              value: _oversightRequired,
              contentPadding: EdgeInsets.zero,
              title: const Text('Oversight required'),
              onChanged: (value) => setState(() {
                _oversightRequired = value;
              }),
            ),
          ],
        ),
      ),
      onSubmit: () {
        if (!_formKey.currentState!.validate()) {
          return;
        }

        Navigator.of(context).pop(
          _OfflineStepDraft(
            stepType: _stepType,
            status: _status,
            expectedOffice: _expectedOfficeController.text.trim(),
            assignedRole: _assignedRole,
            notes: _notesController.text.trim(),
            filingDate: _parseOptionalDate(_filingDateController.text),
            scheduledAt: _parseOptionalDate(_scheduledAtController.text),
            nextFollowUpDate: _parseOptionalDate(
              _nextFollowUpDateController.text,
            ),
            originalRequired: _originalRequired,
            oversightRequired: _oversightRequired,
          ),
        );
      },
    );
  }
}

class _OfflineStatusDialog extends StatefulWidget {
  const _OfflineStatusDialog({required this.step});

  final OfflineStepRecord step;

  @override
  State<_OfflineStatusDialog> createState() => _OfflineStatusDialogState();
}

class _OfflineStatusDialogState extends State<_OfflineStatusDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _delayReasonController =
      TextEditingController(text: widget.step.delayReason ?? '');
  late final TextEditingController _notesController = TextEditingController(
    text: widget.step.notes ?? '',
  );
  late final TextEditingController _filingDateController =
      TextEditingController(text: widget.step.filingDate?.isoDateInput ?? '');
  late final TextEditingController _scheduledAtController =
      TextEditingController(
        text: widget.step.scheduledAt?.isoDateTimeInput ?? '',
      );
  late final TextEditingController _nextFollowUpDateController =
      TextEditingController(
        text: widget.step.nextFollowUpDate?.isoDateInput ?? '',
      );

  late String _status = widget.step.physicalStatus;

  @override
  void dispose() {
    _delayReasonController.dispose();
    _notesController.dispose();
    _filingDateController.dispose();
    _scheduledAtController.dispose();
    _nextFollowUpDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FormDialog(
      title: 'Update offline step',
      subtitle: widget.step.stepType.humanized(),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Physical status'),
              items: _offlineStatuses
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(item.humanized()),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() {
                _status = value ?? _status;
              }),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _filingDateController,
              decoration: const InputDecoration(
                labelText: 'Filing date',
                hintText: 'YYYY-MM-DD',
              ),
              validator: _optionalDateValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _scheduledAtController,
              decoration: const InputDecoration(
                labelText: 'Scheduled at',
                hintText: 'YYYY-MM-DD or ISO datetime',
              ),
              validator: _optionalDateValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nextFollowUpDateController,
              decoration: const InputDecoration(
                labelText: 'Next follow-up',
                hintText: 'YYYY-MM-DD',
              ),
              validator: _optionalDateValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _delayReasonController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Delay reason',
                hintText: 'Why this filing step is delayed or blocked',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Fresh operational notes for the case team',
              ),
            ),
          ],
        ),
      ),
      onSubmit: () {
        if (!_formKey.currentState!.validate()) {
          return;
        }

        Navigator.of(context).pop(
          _OfflineStatusUpdate(
            status: _status,
            delayReason: _delayReasonController.text.trim(),
            notes: _notesController.text.trim(),
            filingDate: _parseOptionalDate(_filingDateController.text),
            scheduledAt: _parseOptionalDate(_scheduledAtController.text),
            nextFollowUpDate: _parseOptionalDate(
              _nextFollowUpDateController.text,
            ),
          ),
        );
      },
    );
  }
}

class _LegalCaseDialog extends StatefulWidget {
  const _LegalCaseDialog();

  @override
  State<_LegalCaseDialog> createState() => _LegalCaseDialogState();
}

class _LegalCaseDialogState extends State<_LegalCaseDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _expectedOfficeController =
      TextEditingController();
  final TextEditingController _referenceNumberController =
      TextEditingController();
  final TextEditingController _courtNameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _delayReasonController = TextEditingController();
  final TextEditingController _filingDateController = TextEditingController();
  final TextEditingController _nextFollowUpDateController =
      TextEditingController();
  final TextEditingController _finalDecisionDateController =
      TextEditingController();

  String _caseType = _legalCaseTypes.first;
  String _status = _legalCaseStatuses.first;
  bool _freezesAutomation = true;
  bool _requiresAdminOversight = false;

  @override
  void dispose() {
    _expectedOfficeController.dispose();
    _referenceNumberController.dispose();
    _courtNameController.dispose();
    _notesController.dispose();
    _delayReasonController.dispose();
    _filingDateController.dispose();
    _nextFollowUpDateController.dispose();
    _finalDecisionDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FormDialog(
      title: 'Add legal case',
      subtitle:
          'Create a structured record for appeal, litigation, justice execution, succession, foreign authorization, or old-title regularization.',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _caseType,
              decoration: const InputDecoration(labelText: 'Case type'),
              items: _legalCaseTypes
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(item.humanized()),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() {
                _caseType = value ?? _caseType;
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: _legalCaseStatuses
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(item.humanized()),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() {
                _status = value ?? _status;
              }),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _expectedOfficeController,
              decoration: const InputDecoration(
                labelText: 'Expected office',
                hintText: 'Ministry desk, court registry, sub-prefecture...',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _referenceNumberController,
              decoration: const InputDecoration(
                labelText: 'Reference number',
                hintText: 'Appeal or file reference',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _courtNameController,
              decoration: const InputDecoration(
                labelText: 'Court or venue',
                hintText: 'Tribunal or relevant office name',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _filingDateController,
              decoration: const InputDecoration(
                labelText: 'Filing date',
                hintText: 'YYYY-MM-DD',
              ),
              validator: _optionalDateValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nextFollowUpDateController,
              decoration: const InputDecoration(
                labelText: 'Next follow-up',
                hintText: 'YYYY-MM-DD',
              ),
              validator: _optionalDateValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _finalDecisionDateController,
              decoration: const InputDecoration(
                labelText: 'Final decision date',
                hintText: 'YYYY-MM-DD',
              ),
              validator: _optionalDateValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _delayReasonController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Delay reason',
                hintText: 'Optional blocker or delay note',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'What the oversight team needs to know',
              ),
            ),
            SwitchListTile.adaptive(
              value: _freezesAutomation,
              contentPadding: EdgeInsets.zero,
              title: const Text('Freeze automation'),
              onChanged: (value) => setState(() {
                _freezesAutomation = value;
              }),
            ),
            SwitchListTile.adaptive(
              value: _requiresAdminOversight,
              contentPadding: EdgeInsets.zero,
              title: const Text('Require admin oversight'),
              onChanged: (value) => setState(() {
                _requiresAdminOversight = value;
              }),
            ),
          ],
        ),
      ),
      onSubmit: () {
        if (!_formKey.currentState!.validate()) {
          return;
        }

        Navigator.of(context).pop(
          _LegalCaseDraft(
            caseType: _caseType,
            status: _status,
            expectedOffice: _expectedOfficeController.text.trim(),
            referenceNumber: _referenceNumberController.text.trim(),
            courtName: _courtNameController.text.trim(),
            notes: _notesController.text.trim(),
            delayReason: _delayReasonController.text.trim(),
            filingDate: _parseOptionalDate(_filingDateController.text),
            nextFollowUpDate: _parseOptionalDate(
              _nextFollowUpDateController.text,
            ),
            finalDecisionDate: _parseOptionalDate(
              _finalDecisionDateController.text,
            ),
            freezesAutomation: _freezesAutomation,
            requiresAdminOversight: _requiresAdminOversight,
          ),
        );
      },
    );
  }
}

class _LegalCaseStatusDialog extends StatefulWidget {
  const _LegalCaseStatusDialog({required this.legalCase});

  final LegalCaseRecord legalCase;

  @override
  State<_LegalCaseStatusDialog> createState() => _LegalCaseStatusDialogState();
}

class _LegalCaseStatusDialogState extends State<_LegalCaseStatusDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _delayReasonController =
      TextEditingController(text: widget.legalCase.delayReason ?? '');
  late final TextEditingController _referenceNumberController =
      TextEditingController(text: widget.legalCase.referenceNumber ?? '');
  late final TextEditingController _courtNameController = TextEditingController(
    text: widget.legalCase.courtName ?? '',
  );
  late final TextEditingController _notesController = TextEditingController(
    text: widget.legalCase.notes ?? '',
  );
  late final TextEditingController _filingDateController =
      TextEditingController(
        text: widget.legalCase.filingDate?.isoDateInput ?? '',
      );
  late final TextEditingController _nextFollowUpDateController =
      TextEditingController(
        text: widget.legalCase.nextFollowUpDate?.isoDateInput ?? '',
      );
  late final TextEditingController _finalDecisionDateController =
      TextEditingController(
        text: widget.legalCase.finalDecisionDate?.isoDateInput ?? '',
      );

  late String _status = widget.legalCase.status;

  @override
  void dispose() {
    _delayReasonController.dispose();
    _referenceNumberController.dispose();
    _courtNameController.dispose();
    _notesController.dispose();
    _filingDateController.dispose();
    _nextFollowUpDateController.dispose();
    _finalDecisionDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FormDialog(
      title: 'Update legal case',
      subtitle: widget.legalCase.caseType.humanized(),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: _legalCaseStatuses
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(item.humanized()),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() {
                _status = value ?? _status;
              }),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _referenceNumberController,
              decoration: const InputDecoration(labelText: 'Reference number'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _courtNameController,
              decoration: const InputDecoration(labelText: 'Court or venue'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _filingDateController,
              decoration: const InputDecoration(
                labelText: 'Filing date',
                hintText: 'YYYY-MM-DD',
              ),
              validator: _optionalDateValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nextFollowUpDateController,
              decoration: const InputDecoration(
                labelText: 'Next follow-up',
                hintText: 'YYYY-MM-DD',
              ),
              validator: _optionalDateValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _finalDecisionDateController,
              decoration: const InputDecoration(
                labelText: 'Final decision date',
                hintText: 'YYYY-MM-DD',
              ),
              validator: _optionalDateValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _delayReasonController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Delay reason'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
          ],
        ),
      ),
      onSubmit: () {
        if (!_formKey.currentState!.validate()) {
          return;
        }

        Navigator.of(context).pop(
          _LegalCaseStatusUpdate(
            status: _status,
            delayReason: _delayReasonController.text.trim(),
            referenceNumber: _referenceNumberController.text.trim(),
            courtName: _courtNameController.text.trim(),
            notes: _notesController.text.trim(),
            filingDate: _parseOptionalDate(_filingDateController.text),
            nextFollowUpDate: _parseOptionalDate(
              _nextFollowUpDateController.text,
            ),
            finalDecisionDate: _parseOptionalDate(
              _finalDecisionDateController.text,
            ),
          ),
        );
      },
    );
  }
}

class _FormDialog extends StatelessWidget {
  const _FormDialog({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onSubmit,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.all(16),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Text(title),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF5C635B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: onSubmit, child: const Text('Save')),
      ],
    );
  }
}

class _ComplianceNoteView {
  const _ComplianceNoteView({required this.level, required this.message});

  final String level;
  final String message;

  IconData get levelIcon => switch (level) {
    'required' => Icons.report_problem_outlined,
    'recommended' => Icons.lightbulb_outline_rounded,
    _ => Icons.info_outline_rounded,
  };

  Color get levelColor => switch (level) {
    'required' => const Color(0xFF8E5B16),
    'recommended' => const Color(0xFF1E5A43),
    _ => const Color(0xFF4E5B57),
  };
}

class _DetailLine {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String? value;
}

class _OfflineStepDraft {
  const _OfflineStepDraft({
    required this.stepType,
    required this.status,
    required this.expectedOffice,
    required this.assignedRole,
    required this.notes,
    required this.filingDate,
    required this.scheduledAt,
    required this.nextFollowUpDate,
    required this.originalRequired,
    required this.oversightRequired,
  });

  final String stepType;
  final String status;
  final String expectedOffice;
  final String assignedRole;
  final String notes;
  final DateTime? filingDate;
  final DateTime? scheduledAt;
  final DateTime? nextFollowUpDate;
  final bool originalRequired;
  final bool oversightRequired;
}

class _OfflineStatusUpdate {
  const _OfflineStatusUpdate({
    required this.status,
    required this.delayReason,
    required this.notes,
    required this.filingDate,
    required this.scheduledAt,
    required this.nextFollowUpDate,
  });

  final String status;
  final String delayReason;
  final String notes;
  final DateTime? filingDate;
  final DateTime? scheduledAt;
  final DateTime? nextFollowUpDate;
}

class _LegalCaseDraft {
  const _LegalCaseDraft({
    required this.caseType,
    required this.status,
    required this.expectedOffice,
    required this.referenceNumber,
    required this.courtName,
    required this.notes,
    required this.delayReason,
    required this.filingDate,
    required this.nextFollowUpDate,
    required this.finalDecisionDate,
    required this.freezesAutomation,
    required this.requiresAdminOversight,
  });

  final String caseType;
  final String status;
  final String expectedOffice;
  final String referenceNumber;
  final String courtName;
  final String notes;
  final String delayReason;
  final DateTime? filingDate;
  final DateTime? nextFollowUpDate;
  final DateTime? finalDecisionDate;
  final bool freezesAutomation;
  final bool requiresAdminOversight;
}

class _LegalCaseStatusUpdate {
  const _LegalCaseStatusUpdate({
    required this.status,
    required this.delayReason,
    required this.referenceNumber,
    required this.courtName,
    required this.notes,
    required this.filingDate,
    required this.nextFollowUpDate,
    required this.finalDecisionDate,
  });

  final String status;
  final String delayReason;
  final String referenceNumber;
  final String courtName;
  final String notes;
  final DateTime? filingDate;
  final DateTime? nextFollowUpDate;
  final DateTime? finalDecisionDate;
}

enum _BannerTone { warning, info }

List<String> _stringList(Object? value) => switch (value) {
  final List<dynamic> items =>
    items.map((item) => item.toString()).toList(growable: false),
  _ => const <String>[],
};

List<_ComplianceNoteView> _noteList(Object? value) {
  if (value is! List) {
    return const <_ComplianceNoteView>[];
  }

  return value
      .whereType<Map>()
      .map(
        (item) => _ComplianceNoteView(
          level: item['level']?.toString() ?? 'info',
          message: item['message']?.toString() ?? '',
        ),
      )
      .where((item) => item.message.trim().isNotEmpty)
      .toList(growable: false);
}

String? _stringValue(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text == 'null') {
    return null;
  }
  return text;
}

bool _boolValue(Object? value) => value == true;

_DetailLine _labelValue(String label, String? value) =>
    _DetailLine(label: label, value: _stringValue(value));

String? _optionalDateValidator(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return null;
  }
  if (DateTime.tryParse(trimmed) == null) {
    return 'Use YYYY-MM-DD or ISO datetime.';
  }
  return null;
}

DateTime? _parseOptionalDate(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return DateTime.tryParse(trimmed);
}

Color _statusColor(String status) => switch (status) {
  'completed' || 'resolved' || 'closed' => const Color(0xFF1E5A43),
  'blocked' || 'cancelled' => const Color(0xFF8E2D2D),
  'awaiting_decision' ||
  'awaiting_court_hearing' ||
  'awaiting_final_judgment' ||
  'awaiting_non_objection' ||
  'awaiting_commission_visit' ||
  'pending_filing' => const Color(0xFF8E5B16),
  _ => const Color(0xFF496A85),
};

extension on String {
  String humanized() {
    return split('_')
        .where((item) => item.trim().isNotEmpty)
        .map((item) => '${item[0].toUpperCase()}${item.substring(1)}')
        .join(' ');
  }
}

extension on DateTime {
  String get dateLabel =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  String get dateTimeLabel {
    final local = toLocal();
    return '${local.dateLabel} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String get isoDateInput => dateLabel;

  String get isoDateTimeInput {
    final local = toLocal();
    return '${local.dateLabel}T${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:00';
  }
}
