import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../data/consumer_api.dart';
import '../../../../ui/app_icons.dart';
import '../../../../ui/brand.dart';
import '../../../../ui/components/buttons.dart';
import '../../../../ui/components/cards.dart';
import '../../../../ui/components/page_sections.dart';
import '../../consumer_controller.dart';
import '../../consumer_models.dart';

class ConsumerSubscriptionCenterPage extends StatefulWidget {
  const ConsumerSubscriptionCenterPage({super.key, required this.controller});

  final ConsumerController controller;

  @override
  State<ConsumerSubscriptionCenterPage> createState() =>
      _ConsumerSubscriptionCenterPageState();
}

class _ConsumerSubscriptionCenterPageState
    extends State<ConsumerSubscriptionCenterPage>
    with WidgetsBindingObserver {
  late Future<_SubscriptionBundle> _bundleFuture;
  ConsumerPaymentGatewaySummary? _gatewaySummary;
  ConsumerSubscriptionCheckoutState? _latestCheckout;
  List<ConsumerSubscriptionPlan> _resolvedPlans = const [];
  String _billingCycle = 'monthly';
  bool _isSubmitting = false;
  bool _isRefreshingCheckout = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bundleFuture = _loadBundle();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _shouldRefreshLatestCheckout) {
      _refreshLatestCheckout(silent: true);
    }
  }

  bool get _shouldRefreshLatestCheckout =>
      widget.controller.isAuthenticated &&
      (_latestCheckout?.isAwaitingConfirmation ?? false) &&
      !_isRefreshingCheckout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plans & Billing')),
      body: FutureBuilder<_SubscriptionBundle>(
        future: _bundleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final bundle = snapshot.data;
          final current = bundle?.current;
          final plans =
              bundle?.plans ?? widget.controller.fallbackSubscriptionPlans;
          final gateway = bundle?.gateway;
          final accountNotice = snapshot.hasError
              ? null
              : bundle?.accountNotice;
          final recommendedPlanCode = _recommendedPlanCodeForRole(
            widget.controller.primaryRole,
          );
          final checkoutReady = gateway?.configured ?? false;
          final railLabels = gateway == null
              ? const []
              : {
                  ...gateway.collectionRails.map(startCase),
                  ...gateway.payoutRails.map(startCase),
                }.toList(growable: false);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              const ResPageHeader(
                eyebrow: 'Subscriptions',
                title: 'Choose the right plan',
                subtitle:
                    'Compare limits, switch billing, and upgrade when you are ready.',
              ),
              const SizedBox(height: 18),
              if (accountNotice != null) ...[
                _SubscriptionNoticePanel(
                  icon: Icons.lock_outline_rounded,
                  title: 'Plans are ready',
                  message: accountNotice,
                ),
                const SizedBox(height: 18),
              ] else if (!widget.controller.isAuthenticated) ...[
                const _SubscriptionNoticePanel(
                  icon: ResIcons.membership,
                  title: 'Browse first',
                  message:
                      'Compare every tier now. Sign in only when you are ready to activate a plan.',
                ),
                const SizedBox(height: 18),
              ],
              ResSurfaceCard(
                color: ResColors.surfaceContainerLowest,
                radius: 24,
                shadow: const [],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ResInfoChip(
                          label: current?.planName ?? 'No active paid plan',
                          color: current == null
                              ? ResColors.info
                              : ResColors.primary,
                          icon: ResIcons.membership,
                        ),
                        ResInfoChip(
                          label: _billingCycle == 'yearly'
                              ? 'Yearly billing'
                              : 'Monthly billing',
                          color: ResColors.secondary,
                          icon: ResIcons.wallet,
                        ),
                        if (current != null)
                          ResInfoChip(
                            label: '${current.maxListings} listings',
                            color: ResColors.tertiary,
                            icon: ResIcons.listings,
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      current == null
                          ? 'Compare before you choose'
                          : 'Current plan',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      current == null
                          ? 'Pick a billing cycle first, then review the plan details below.'
                          : 'You are currently on ${current.planName}. Switch plans anytime from this screen.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ResColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment<String>(
                          value: 'monthly',
                          icon: Icon(ResIcons.wallet),
                          label: Text('Monthly'),
                        ),
                        ButtonSegment<String>(
                          value: 'yearly',
                          icon: Icon(Icons.calendar_month_outlined),
                          label: Text('Yearly'),
                        ),
                      ],
                      selected: {_billingCycle},
                      onSelectionChanged: (selection) {
                        setState(() => _billingCycle = selection.first);
                      },
                    ),
                    if (current != null) ...[
                      const SizedBox(height: 16),
                      ResFeatureRow(
                        icon: ResIcons.listings,
                        label: 'Listing capacity',
                        value: '${current.maxListings} active listings',
                        tint: ResColors.primary,
                      ),
                      const SizedBox(height: 12),
                      ResFeatureRow(
                        icon: Icons.calendar_month_outlined,
                        label: 'Access until',
                        value: current.endDate == null
                            ? 'Open'
                            : _formatDateTime(current.endDate!),
                        tint: ResColors.secondary,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (_latestCheckout != null) ...[
                _CheckoutStatusCard(
                  checkout: _latestCheckout!,
                  isRefreshing: _isRefreshingCheckout || _isSubmitting,
                  onResumeCheckout:
                      _latestCheckout!.canResumeCheckout &&
                          _latestCheckout!.checkoutUrl.trim().isNotEmpty
                      ? () => _resumeHostedCheckout(_latestCheckout!)
                      : null,
                  onRefreshStatus: widget.controller.isAuthenticated
                      ? () => _refreshLatestCheckout()
                      : null,
                ),
                const SizedBox(height: 18),
              ],
              if (gateway != null) ...[
                _SubscriptionNoticePanel(
                  icon: checkoutReady
                      ? ResIcons.secure
                      : Icons.schedule_rounded,
                  title: checkoutReady
                      ? 'Secure checkout is ready'
                      : 'Paid checkout is coming soon',
                  message: checkoutReady
                      ? 'Choose a paid plan, complete checkout, and we will confirm the change when you return.'
                      : 'You can still compare every tier now. Paid upgrades will appear here once checkout is live.',
                  footer: railLabels.isEmpty
                      ? null
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: railLabels
                              .take(4)
                              .map(
                                (label) => ResInfoChip(
                                  label: label,
                                  color: checkoutReady
                                      ? ResColors.secondary
                                      : ResColors.info,
                                  icon: checkoutReady
                                      ? ResIcons.wallet
                                      : Icons.info_outline_rounded,
                                ),
                              )
                              .toList(growable: false),
                        ),
                ),
                const SizedBox(height: 18),
              ],
              Text(
                'Plan comparison',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                widget.controller.isAuthenticated
                    ? 'Upgrade, downgrade, or stay on your current plan.'
                    : 'Review each tier now. Sign in when you are ready to activate one.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ResColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 18),
              if (plans.isEmpty)
                const _SubscriptionNoticePanel(
                  icon: Icons.layers_clear_outlined,
                  title: 'No plans published yet',
                  message:
                      'Plan tiers have not been published on this server yet.',
                ),
              ...plans.map(
                (plan) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _PlanCard(
                    plan: plan,
                    billingCycle: _billingCycle,
                    isCurrent: current?.planCode == plan.planCode,
                    isRecommended: plan.planCode == recommendedPlanCode,
                    isSubmitting: _isSubmitting,
                    canSelect: _canSelectPlan(plan, gateway),
                    ctaLabel: _planCtaLabel(plan, gateway),
                    onSelect: () =>
                        _applyPlan(plan: plan, alreadyActive: current != null),
                  ),
                ),
              ),
              if (current != null) ...[
                const SizedBox(height: 18),
                ResOutlineButton(
                  label: 'Cancel current plan',
                  icon: Icons.cancel_outlined,
                  isPill: true,
                  onPressed: _isSubmitting ? null : _cancelCurrent,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<_SubscriptionBundle> _loadBundle() async {
    ConsumerPaymentGatewaySummary? gateway;
    try {
      gateway = await widget.controller.loadPaymentGatewaySummary();
    } catch (_) {
      gateway = null;
    }

    ConsumerSubscriptionCheckoutState? latestCheckout;
    ConsumerCurrentSubscription? current;
    String? accountNotice;
    if (widget.controller.isAuthenticated) {
      try {
        latestCheckout = await widget.controller
            .loadLatestSubscriptionCheckout();
        current = await widget.controller.loadCurrentSubscription();
      } on ConsumerApiFailure catch (error) {
        if (error.statusCode == 401 || error.statusCode == 403) {
          accountNotice =
              'Sign in again to manage billing and activate a plan. You can still compare every tier below.';
        } else {
          accountNotice =
              'We could not refresh your billing status. You can still compare every tier below.';
        }
      } on StateError {
        accountNotice =
            'Sign in again to manage billing and activate a plan. You can still compare every tier below.';
      }
    }

    final plans = await widget.controller.loadSubscriptionPlans();
    _gatewaySummary = gateway;
    _latestCheckout = latestCheckout;
    _resolvedPlans = plans;
    return _SubscriptionBundle(
      current: current,
      plans: plans,
      gateway: gateway,
      accountNotice: accountNotice,
    );
  }

  Future<void> _applyPlan({
    required ConsumerSubscriptionPlan plan,
    required bool alreadyActive,
  }) async {
    if (!widget.controller.isAuthenticated) {
      _showNotice('Sign in to start secure subscription checkout.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final gateway = _gatewaySummary ?? await _loadGatewaySummary();
      final price = _priceForPlan(plan);
      if (price <= 0) {
        await widget.controller.activateSubscription(
          plan: plan,
          billingCycle: _billingCycle,
          alreadyActive: alreadyActive,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _bundleFuture = _loadBundle();
        });
        _showNotice('Subscription updated successfully.');
        return;
      }

      if (!(gateway?.configured ?? false)) {
        _showNotice(
          'Secure checkout is not configured yet for paid plans. Free plans remain available until the payment rail is live.',
        );
        return;
      }

      if (_shouldUseHostedCheckout(plan, gateway)) {
        final checkout = await widget.controller.startSubscriptionCheckout(
          plan: plan,
          billingCycle: _billingCycle,
        );
        await _refreshLatestCheckout(reference: checkout.txRef, silent: true);
        if (!mounted) {
          return;
        }

        await _resumeHostedCheckout(
          _latestCheckout ??
              ConsumerSubscriptionCheckoutState(
                id: 0,
                reference: checkout.txRef,
                provider: checkout.provider,
                planId: checkout.planId,
                planName: '',
                planCode: checkout.planCode,
                billingCycle: checkout.billingCycle,
                sessionStatus: 'pending',
                providerStatus: 'pending',
                checkoutUrl: checkout.checkoutUrl,
                callbackUrl: '',
                amount: checkout.amount,
                currency: checkout.currency,
                errorMessage: '',
                canResumeCheckout: true,
                needsAttention: true,
                returnHint:
                    'Complete the hosted checkout, then return to this page to confirm the result.',
              ),
        );
        return;
      }
    } catch (error) {
      _showNotice(_humanizeError(error));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _cancelCurrent() async {
    setState(() => _isSubmitting = true);
    try {
      await widget.controller.cancelSubscription(
        reason: 'Cancelled from mobile subscription center.',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _bundleFuture = _loadBundle();
      });
      _showNotice('Current plan cancelled.');
    } catch (error) {
      _showNotice(_humanizeError(error));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<ConsumerPaymentGatewaySummary?> _loadGatewaySummary() async {
    try {
      final gateway = await widget.controller.loadPaymentGatewaySummary();
      _gatewaySummary = gateway;
      return gateway;
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshLatestCheckout({
    String? reference,
    bool silent = false,
  }) async {
    if (!widget.controller.isAuthenticated || _isRefreshingCheckout) {
      return;
    }

    if (mounted) {
      setState(() => _isRefreshingCheckout = true);
    }

    try {
      final latest = await widget.controller.loadLatestSubscriptionCheckout(
        reference: reference,
      );
      final current = await widget.controller.loadCurrentSubscription();
      if (!mounted) {
        return;
      }
      setState(() {
        _latestCheckout = latest;
        _bundleFuture = Future.value(
          _SubscriptionBundle(
            current: current,
            plans: _resolvedPlans,
            gateway: _gatewaySummary,
          ),
        );
      });
      if (!silent && latest != null) {
        _showNotice(latest.returnHint);
      }
    } catch (error) {
      if (!silent) {
        _showNotice(_humanizeError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshingCheckout = false);
      }
    }
  }

  Future<void> _resumeHostedCheckout(
    ConsumerSubscriptionCheckoutState checkout,
  ) async {
    final uri = Uri.tryParse(checkout.checkoutUrl);
    if (uri == null || checkout.checkoutUrl.trim().isEmpty) {
      throw StateError(
        'The payment gateway did not return a usable checkout link.',
      );
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw StateError('The hosted checkout page could not be opened.');
    }

    _showNotice(
      'Secure checkout opened in your browser. We will try to confirm the result when you return to the app.',
    );
  }

  bool _shouldUseHostedCheckout(
    ConsumerSubscriptionPlan plan,
    ConsumerPaymentGatewaySummary? gateway,
  ) {
    final price = _priceForPlan(plan);
    return price > 0 && (gateway?.configured ?? false);
  }

  bool _canSelectPlan(
    ConsumerSubscriptionPlan plan,
    ConsumerPaymentGatewaySummary? gateway,
  ) {
    if (!widget.controller.isAuthenticated) {
      return false;
    }
    return _priceForPlan(plan) <= 0 || (gateway?.configured ?? false);
  }

  double _priceForPlan(ConsumerSubscriptionPlan plan) {
    if (_billingCycle == 'yearly' && plan.priceYearly != null) {
      return plan.priceYearly!;
    }
    return plan.priceMonthly;
  }

  String _planCtaLabel(
    ConsumerSubscriptionPlan plan,
    ConsumerPaymentGatewaySummary? gateway,
  ) {
    if (!widget.controller.isAuthenticated) {
      return 'Sign in to upgrade';
    }
    if (_priceForPlan(plan) <= 0) {
      return 'Use this plan';
    }
    if (!(gateway?.configured ?? false)) {
      return 'Paid checkout soon';
    }
    if (_shouldUseHostedCheckout(plan, gateway)) {
      return 'Upgrade securely';
    }
    return 'Choose plan';
  }

  void _showNotice(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _humanizeError(Object error) {
    final raw = error.toString();
    final message = raw.startsWith('Exception: ') ? raw.substring(11) : raw;
    final normalizedMessage = message.trim().toLowerCase();
    if (normalizedMessage == 'authentication required.' ||
        normalizedMessage.contains('session') ||
        normalizedMessage.contains('token') ||
        normalizedMessage.contains('expired')) {
      return 'Live billing could not confirm account access just yet.';
    }
    return message;
  }
}

class _SubscriptionBundle {
  const _SubscriptionBundle({
    required this.current,
    required this.plans,
    required this.gateway,
    this.accountNotice,
  });

  final ConsumerCurrentSubscription? current;
  final List<ConsumerSubscriptionPlan> plans;
  final ConsumerPaymentGatewaySummary? gateway;
  final String? accountNotice;
}

class _SubscriptionNoticePanel extends StatelessWidget {
  const _SubscriptionNoticePanel({
    required this.icon,
    required this.title,
    required this.message,
    this.footer,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ResColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: ResColors.outlineVariant.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: ResColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: ResColors.foreground, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ResColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (footer != null) ...[const SizedBox(height: 14), footer!],
        ],
      ),
    );
  }
}

class _CheckoutStatusCard extends StatelessWidget {
  const _CheckoutStatusCard({
    required this.checkout,
    required this.isRefreshing,
    this.onResumeCheckout,
    this.onRefreshStatus,
  });

  final ConsumerSubscriptionCheckoutState checkout;
  final bool isRefreshing;
  final VoidCallback? onResumeCheckout;
  final VoidCallback? onRefreshStatus;

  @override
  Widget build(BuildContext context) {
    final title = checkout.isPaid
        ? 'Payment confirmed'
        : checkout.isFailed
        ? 'Checkout needs attention'
        : checkout.isProcessing
        ? 'Payment is processing'
        : 'Checkout in progress';
    final planLabel = checkout.planName.trim().isNotEmpty
        ? checkout.planName
        : startCase(checkout.planCode);

    return ResSurfaceCard(
      radius: 24,
      color: _checkoutBackground(checkout),
      shadow: const [],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ResInfoChip(
                label: title,
                color: _checkoutAccent(checkout),
                icon: checkout.isPaid
                    ? ResIcons.check
                    : checkout.isFailed
                    ? Icons.warning_amber_rounded
                    : ResIcons.wallet,
              ),
              ResInfoChip(
                label: startCase(checkout.provider),
                color: ResColors.primary,
                icon: ResIcons.wallet,
              ),
              ResInfoChip(
                label: planLabel,
                color: Colors.white,
                icon: ResIcons.membership,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            checkout.returnHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ResInfoChip(
                label: '${startCase(checkout.billingCycle)} billing',
                color: ResColors.secondary,
                icon: Icons.calendar_month_outlined,
              ),
              ResInfoChip(
                label: formatXaf(checkout.amount),
                color: ResColors.tertiary,
                icon: ResIcons.receipt,
              ),
              if (checkout.updatedAt != null)
                ResInfoChip(
                  label: 'Updated ${_formatDateTime(checkout.updatedAt!)}',
                  color: ResColors.info,
                  icon: ResIcons.analytics,
                ),
            ],
          ),
          if (checkout.errorMessage.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ResColors.destructive.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                checkout.errorMessage.trim(),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: ResColors.destructive),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (onRefreshStatus != null)
                Expanded(
                  child: ResOutlineButton(
                    label: isRefreshing ? 'Checking...' : 'Confirm status',
                    icon: Icons.refresh_rounded,
                    isPill: true,
                    onPressed: isRefreshing ? null : onRefreshStatus,
                  ),
                ),
              if (onRefreshStatus != null && onResumeCheckout != null)
                const SizedBox(width: 10),
              if (onResumeCheckout != null)
                Expanded(
                  child: ResPrimaryButton(
                    label: checkout.isFailed
                        ? 'Try checkout again'
                        : 'Resume checkout',
                    icon: ResIcons.secure,
                    onPressed: isRefreshing ? null : onResumeCheckout,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Reference: ${checkout.reference}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: ResColors.mutedForeground),
          ),
        ],
      ),
    );
  }
}

Color _checkoutAccent(ConsumerSubscriptionCheckoutState checkout) {
  if (checkout.isPaid) {
    return ResColors.secondary;
  }
  if (checkout.isFailed) {
    return ResColors.destructive;
  }
  if (checkout.isProcessing) {
    return ResColors.tertiary;
  }
  return ResColors.primary;
}

Color _checkoutBackground(ConsumerSubscriptionCheckoutState checkout) {
  if (checkout.isPaid) {
    return ResColors.surfaceContainerLow;
  }
  if (checkout.isFailed) {
    return ResColors.destructive.withValues(alpha: 0.06);
  }
  if (checkout.isProcessing) {
    return ResColors.tertiaryFixed.withValues(alpha: 0.35);
  }
  return ResColors.surfaceContainerLowest;
}

String _formatDateTime(DateTime value) {
  final month = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][value.month - 1];
  final hour = value.hour == 0
      ? 12
      : (value.hour > 12 ? value.hour - 12 : value.hour);
  final minute = value.minute.toString().padLeft(2, '0');
  final meridiem = value.hour >= 12 ? 'PM' : 'AM';
  return '${value.day} $month, $hour:$minute $meridiem';
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.billingCycle,
    required this.isCurrent,
    required this.isRecommended,
    required this.isSubmitting,
    required this.canSelect,
    required this.ctaLabel,
    required this.onSelect,
  });

  final ConsumerSubscriptionPlan plan;
  final String billingCycle;
  final bool isCurrent;
  final bool isRecommended;
  final bool isSubmitting;
  final bool canSelect;
  final String ctaLabel;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final planTone = _planTone(
      plan,
      isCurrent: isCurrent,
      isRecommended: isRecommended,
    );
    final price = billingCycle == 'yearly' && plan.priceYearly != null
        ? plan.priceYearly!
        : plan.priceMonthly;
    final priceCaption = billingCycle == 'yearly' ? '/ year' : '/ month';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ResColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isCurrent
              ? ResColors.secondary.withValues(alpha: 0.34)
              : isRecommended
              ? ResColors.outlineVariant.withValues(alpha: 0.34)
              : ResColors.outlineVariant.withValues(alpha: 0.22),
        ),
      ),
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (isRecommended)
                          const ResInfoChip(
                            label: 'Recommended',
                            color: ResColors.info,
                            icon: Icons.auto_awesome_rounded,
                          ),
                        if (plan.badgeDisplay.isNotEmpty)
                          ResInfoChip(
                            label: startCase(plan.badgeDisplay),
                            color: planTone,
                            icon: ResIcons.crown,
                          ),
                        if (isCurrent)
                          const ResInfoChip(
                            label: 'Current plan',
                            color: ResColors.secondary,
                            icon: ResIcons.check,
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      plan.planName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      plan.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ResColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatXaf(price),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    priceCaption,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: ResColors.softForeground,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ResInfoChip(
                label: '${plan.maxListings} listings',
                color: ResColors.primary,
                icon: ResIcons.listings,
              ),
              ResInfoChip(
                label: '${plan.maxPhotosPerListing} photos',
                color: ResColors.secondary,
                icon: ResIcons.photo,
              ),
              if (plan.maxVideosPerListing > 0)
                ResInfoChip(
                  label: '${plan.maxVideosPerListing} videos',
                  color: ResColors.tertiary,
                  icon: ResIcons.video,
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...plan.features
              .take(4)
              .map(
                (feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Icon(ResIcons.check, color: planTone, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          feature,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: ResColors.foreground),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 8),
          ResPrimaryButton(
            label: isCurrent ? 'Current plan' : ctaLabel,
            icon: isCurrent ? ResIcons.check : ResIcons.arrowRight,
            isPill: true,
            isBusy: isSubmitting,
            onPressed: isCurrent || isSubmitting || !canSelect
                ? null
                : onSelect,
          ),
          if (billingCycle == 'yearly' && plan.yearlySavings != null) ...[
            const SizedBox(height: 10),
            Text(
              'Save ${formatXaf(plan.yearlySavings!)} with yearly billing.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ResColors.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _recommendedPlanCodeForRole(String role) {
  if (isProfessionalRole(role)) {
    return 'professional';
  }
  if (isSellerLikeRole(role)) {
    return 'professional';
  }
  return 'basic';
}

Color _planTone(
  ConsumerSubscriptionPlan plan, {
  required bool isCurrent,
  required bool isRecommended,
}) {
  if (isCurrent) {
    return ResColors.secondary;
  }
  if (isRecommended) {
    return ResColors.primary;
  }
  if (plan.planCode.toLowerCase().contains('enterprise')) {
    return ResColors.tertiary;
  }
  return ResColors.primary;
}
