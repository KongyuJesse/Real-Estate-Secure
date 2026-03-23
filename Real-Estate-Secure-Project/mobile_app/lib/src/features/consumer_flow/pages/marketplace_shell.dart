import 'dart:async';

import 'package:flutter/material.dart';

import '../consumer_controller.dart';
import '../consumer_models.dart';
import '../widgets/free_tier_interstitial_gate.dart';
import '../widgets/guest_access_sheet.dart';
import 'profile/account_information_page.dart';
import 'profile/verification_status_page.dart';
import 'notification_sheet.dart';
import 'property_details_page.dart';
import 'tabs/finance_tab.dart';
import 'tabs/home_tab.dart';
import 'tabs/listings_tab.dart';
import 'tabs/map_tab.dart';
import 'tabs/profile_tab.dart';
import 'workspace/listing_studio_page.dart';
import 'workspace/subscription_center_page.dart';
import 'workspace/transaction_detail_page.dart';
import 'workspace/transactions_page.dart';
import '../../../ui/components/navigation.dart';

class ConsumerMarketplaceShell extends StatefulWidget {
  const ConsumerMarketplaceShell({super.key, required this.controller});

  final ConsumerController controller;

  @override
  State<ConsumerMarketplaceShell> createState() =>
      _ConsumerMarketplaceShellState();
}

class _ConsumerMarketplaceShellState extends State<ConsumerMarketplaceShell>
    with WidgetsBindingObserver {
  static const Duration _resumeRefreshCooldown = Duration(seconds: 20);

  late final TextEditingController _searchController;
  DateTime? _lastAutomaticRefreshAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController = TextEditingController(
      text: widget.controller.searchQuery,
    );
    unawaited(ConsumerFreeTierInterstitialGate.instance.warmUp());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }

    final now = DateTime.now();
    if (_lastAutomaticRefreshAt != null &&
        now.difference(_lastAutomaticRefreshAt!) < _resumeRefreshCooldown) {
      return;
    }

    _lastAutomaticRefreshAt = now;
    unawaited(widget.controller.refreshMarketplace());
  }

  @override
  void didUpdateWidget(covariant ConsumerMarketplaceShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_searchController.text != widget.controller.searchQuery) {
      _searchController.text = widget.controller.searchQuery;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Scaffold(
          extendBody: true,
          body: SafeArea(
            bottom: false,
            child: IndexedStack(
              index: widget.controller.currentTab.index,
              children: [
                ConsumerHomeTab(
                  controller: widget.controller,
                  searchController: _searchController,
                  onOpenNotifications: _openNotifications,
                  onOpenProperty: _openProperty,
                  onOpenListingStudio: _openListingStudio,
                  onOpenSubscriptionCenter: _openSubscriptionCenter,
                  onOpenTask: _openTask,
                ),
                ConsumerMapTab(
                  controller: widget.controller,
                  onOpenProperty: _openProperty,
                ),
                ConsumerListingsTab(
                  controller: widget.controller,
                  onOpenProperty: _openProperty,
                  onOpenListingStudio: _openListingStudio,
                ),
                ConsumerFinanceTab(controller: widget.controller),
                ConsumerProfileTab(controller: widget.controller),
              ],
            ),
          ),
          bottomNavigationBar: ConsumerBottomNavigationBar(
            role: widget.controller.primaryRole,
            currentTab: widget.controller.currentTab,
            onTabSelected: widget.controller.setTab,
          ),
        );
      },
    );
  }

  Future<void> _openNotifications() async {
    final allowed = await ensureConsumerAuthenticatedAccess(
      context,
      controller: widget.controller,
      title: 'Notifications need an account',
      message:
          'Sign in or register to sync transaction alerts, trust updates, and workspace notifications.',
    );
    if (!allowed || !mounted) {
      return;
    }

    await widget.controller.loadNotifications();
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          ConsumerNotificationSheet(controller: widget.controller),
    );
  }

  Future<void> _openProperty(String propertyId) async {
    await ConsumerFreeTierInterstitialGate.instance.maybeShow(
      controller: widget.controller,
      placement: 'property detail',
    );
    if (!mounted) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConsumerPropertyDetailsPage(
          controller: widget.controller,
          propertyId: propertyId,
        ),
      ),
    );
  }

  Future<void> _openListingStudio() async {
    final allowed = await ensureConsumerAuthenticatedAccess(
      context,
      controller: widget.controller,
      title: 'Seller studio needs a signed-in account',
      message:
          'Create listings, upload evidence, and submit inventory only after signing in or registering.',
    );
    if (!allowed || !mounted) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ConsumerListingStudioPage(controller: widget.controller),
      ),
    );
  }

  Future<void> _openSubscriptionCenter() async {
    if (!mounted) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ConsumerSubscriptionCenterPage(controller: widget.controller),
      ),
    );
  }

  Future<void> _openTask(ConsumerTask task) async {
    final allowed = await ensureConsumerAuthenticatedAccess(
      context,
      controller: widget.controller,
      title: 'This workspace action needs a signed-in account',
      message:
          'Sign in or register to continue with trust reviews, profile setup, and transaction work.',
    );
    if (!allowed || !mounted) {
      return;
    }

    final path = task.actionPath.trim();
    if (path.startsWith('/users/kyc')) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              ConsumerVerificationStatusPage(controller: widget.controller),
        ),
      );
      return;
    }

    if (path == '/properties') {
      _openListingStudio();
      return;
    }

    if (path == '/users/profile' && widget.controller.profile != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ConsumerAccountInformationPage(
            controller: widget.controller,
            profile: widget.controller.profile!,
          ),
        ),
      );
      return;
    }

    if (path.startsWith('/transactions/')) {
      final transactionId = path.split('/').last.trim();
      if (transactionId.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ConsumerTransactionDetailPage(
              controller: widget.controller,
              transactionId: transactionId,
            ),
          ),
        );
        return;
      }
    }

    if (task.resourceType == 'transaction') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              ConsumerTransactionsPage(controller: widget.controller),
        ),
      );
      return;
    }

    widget.controller.setTab(ConsumerTab.finance);
  }
}
