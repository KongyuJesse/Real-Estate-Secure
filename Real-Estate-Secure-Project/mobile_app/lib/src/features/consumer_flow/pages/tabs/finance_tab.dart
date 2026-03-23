import 'package:flutter/material.dart';

import '../../../../ui/app_icons.dart';
import '../../../../ui/brand.dart';
import '../../../../ui/components/cards.dart';
import '../../../../ui/components/page_sections.dart';
import '../../widgets/free_tier_ad_slot.dart';
import '../workspace/subscription_center_page.dart';
import '../workspace/transactions_page.dart';
import '../../consumer_controller.dart';
import '../../consumer_models.dart';

class ConsumerFinanceTab extends StatefulWidget {
  const ConsumerFinanceTab({super.key, required this.controller});

  final ConsumerController controller;

  @override
  State<ConsumerFinanceTab> createState() => _ConsumerFinanceTabState();
}

class _ConsumerFinanceTabState extends State<ConsumerFinanceTab>
    with WidgetsBindingObserver {
  late Future<
    (
      List<ConsumerTransactionSummary>,
      ConsumerCurrentSubscription?,
      List<ConsumerServiceCatalogItem>,
    )
  >
  _workspaceFuture;
  late String _workspaceRefreshKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_handleControllerChanged);
    _workspaceRefreshKey = _buildWorkspaceRefreshKey();
    _workspaceFuture = _loadWorkspace();
  }

  @override
  void didUpdateWidget(covariant ConsumerFinanceTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }
    oldWidget.controller.removeListener(_handleControllerChanged);
    widget.controller.addListener(_handleControllerChanged);
    _workspaceRefreshKey = _buildWorkspaceRefreshKey();
    _workspaceFuture = _loadWorkspace();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {
        _workspaceRefreshKey = _buildWorkspaceRefreshKey();
        _workspaceFuture = _loadWorkspace();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
      (
        List<ConsumerTransactionSummary>,
        ConsumerCurrentSubscription?,
        List<ConsumerServiceCatalogItem>,
      )
    >(
      future: _workspaceFuture,
      builder: (context, snapshot) {
        final transactions =
            snapshot.data?.$1 ?? const <ConsumerTransactionSummary>[];
        final currentSubscription = snapshot.data?.$2;
        final services =
            snapshot.data?.$3 ?? const <ConsumerServiceCatalogItem>[];
        if (!widget.controller.isAuthenticated) {
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _workspaceFuture = _loadWorkspace();
              });
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 140),
              children: [
                const ResPageHeader(
                  eyebrow: 'Workspace',
                  title: 'Plans & tools',
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _VaultActionButton(
                        label: 'Login',
                        icon: ResIcons.arrowRight,
                        filled: true,
                        onTap: widget.controller.openLogin,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _VaultActionButton(
                        label: 'Register',
                        icon: ResIcons.personAdd,
                        onTap: widget.controller.openRegister,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ConsumerFreeTierAdSlot(
                  controller: widget.controller,
                  placement: 'workspace guest preview',
                ),
                const SizedBox(height: 24),
                const ResSectionHeader(title: 'Public services'),
                const SizedBox(height: 12),
                if (!snapshot.hasData)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (services.isEmpty)
                  const _EmptyVaultCard(
                    title: 'No public services yet',
                    body: 'Published services will appear here.',
                  )
                else
                  ...services
                      .take(4)
                      .map(
                        (service) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ResSurfaceCard(
                            radius: 24,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        service.serviceName,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall,
                                      ),
                                    ),
                                    ResInfoChip(
                                      label: startCase(service.billingModel),
                                      color: ResColors.tertiary,
                                      icon: ResIcons.wallet,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  formatXaf(service.priceXaf),
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(color: ResColors.primary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _workspaceFuture = _loadWorkspace();
            });
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 140),
            children: [
              ResPageHeader(
                eyebrow: 'Workspace',
                title: widget.controller.isProfessionalUser
                    ? 'Cases & billing'
                    : widget.controller.isSellerLike
                    ? 'Seller workspace'
                    : 'Plans & activity',
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _VaultActionButton(
                      label: 'Transactions',
                      icon: ResIcons.receipt,
                      filled: true,
                      onTap: () => _openPage(
                        ConsumerTransactionsPage(controller: widget.controller),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _VaultActionButton(
                      label: 'Plans',
                      icon: ResIcons.wallet,
                      onTap: () => _openPage(
                        ConsumerSubscriptionCenterPage(
                          controller: widget.controller,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ResSectionHeader(
                title: 'Recent transactions',
                action: TextButton(
                  onPressed: () => _openPage(
                    ConsumerTransactionsPage(controller: widget.controller),
                  ),
                  child: const Text('View all'),
                ),
              ),
              const SizedBox(height: 12),
              if (transactions.isEmpty)
                const _EmptyVaultCard()
              else
                ...transactions
                    .take(4)
                    .map(
                      (transaction) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _FinanceTransactionCard(
                          transaction: transaction,
                        ),
                      ),
                    ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _InsightTile(
                      icon: ResIcons.analytics,
                      title: 'Service lines',
                      value: '${services.length}',
                      tint: ResColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InsightTile(
                      icon: ResIcons.secure,
                      title: 'Plan status',
                      value:
                          currentSubscription?.subscriptionStatus
                                  .trim()
                                  .isNotEmpty ==
                              true
                          ? startCase(currentSubscription!.subscriptionStatus)
                          : 'Starter',
                      tint: ResColors.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ConsumerFreeTierAdSlot(
                controller: widget.controller,
                placement: 'workspace feed',
              ),
              const SizedBox(height: 24),
              const ResSectionHeader(title: 'Service catalog'),
              const SizedBox(height: 12),
              if (!snapshot.hasData)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (services.isEmpty)
                ResSurfaceCard(
                  radius: 24,
                  child: Text(
                    'No additional services right now.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              else
                ...services
                    .take(4)
                    .map(
                      (service) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ResSurfaceCard(
                          radius: 24,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      service.serviceName,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                  ),
                                  ResInfoChip(
                                    label: startCase(service.billingModel),
                                    color: ResColors.tertiary,
                                    icon: ResIcons.wallet,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                formatXaf(service.priceXaf),
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(color: ResColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  Future<
    (
      List<ConsumerTransactionSummary>,
      ConsumerCurrentSubscription?,
      List<ConsumerServiceCatalogItem>,
    )
  >
  _loadWorkspace() async {
    final results = await Future.wait<Object?>([
      widget.controller.loadTransactions(),
      widget.controller.loadCurrentSubscription(),
      widget.controller.loadServiceCatalog(),
    ]);
    return (
      results[0] as List<ConsumerTransactionSummary>,
      results[1] as ConsumerCurrentSubscription?,
      results[2] as List<ConsumerServiceCatalogItem>,
    );
  }

  void _openPage(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  String _buildWorkspaceRefreshKey() {
    return [
      widget.controller.isAuthenticated,
      widget.controller.session.userUuid,
      widget.controller.primaryRole,
    ].join('|');
  }

  void _handleControllerChanged() {
    final nextKey = _buildWorkspaceRefreshKey();
    if (_workspaceRefreshKey == nextKey || !mounted) {
      return;
    }
    setState(() {
      _workspaceRefreshKey = nextKey;
      _workspaceFuture = _loadWorkspace();
    });
  }
}

class _VaultActionButton extends StatelessWidget {
  const _VaultActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: filled
                ? ResColors.primary
                : ResColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: filled
                  ? ResColors.primary
                  : ResColors.outlineVariant.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: filled ? Colors.white : ResColors.foreground,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: filled ? Colors.white : ResColors.foreground,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinanceTransactionCard extends StatelessWidget {
  const _FinanceTransactionCard({required this.transaction});

  final ConsumerTransactionSummary transaction;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (transaction.transactionStatus) {
      'completed' => ResColors.secondary,
      'cancelled' || 'disputed' => ResColors.destructive,
      _ => ResColors.tertiary,
    };

    return ResSurfaceCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              transaction.transactionStatus == 'completed'
                  ? ResIcons.check
                  : ResIcons.receipt,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.transactionNumber,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  transaction.createdAt == null
                      ? startCase(transaction.transactionStatus)
                      : _formatDate(transaction.createdAt!),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatXaf(transaction.totalAmount),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: ResColors.primary),
              ),
              const SizedBox(height: 4),
              Text(
                startCase(transaction.transactionStatus).toUpperCase(),
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: statusColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.tint,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return ResSurfaceCard(
      color: ResColors.surfaceContainerLow,
      radius: 24,
      shadow: const [],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tint, size: 22),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: ResColors.mutedForeground),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: ResColors.foreground),
          ),
        ],
      ),
    );
  }
}

class _EmptyVaultCard extends StatelessWidget {
  const _EmptyVaultCard({
    this.title = 'No active files yet',
    this.body = 'Transactions and workspace items will appear here.',
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ResSurfaceCard(
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(body, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
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
  return '$month ${value.day}, ${value.year}';
}
