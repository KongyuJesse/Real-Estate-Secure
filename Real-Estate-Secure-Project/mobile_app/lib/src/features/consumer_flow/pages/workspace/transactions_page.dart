import 'package:flutter/material.dart';

import '../../../../ui/app_icons.dart';
import '../../../../ui/brand.dart';
import '../../../../ui/components/cards.dart';
import '../../../../ui/components/page_sections.dart';
import '../../consumer_controller.dart';
import '../../consumer_models.dart';
import 'transaction_detail_page.dart';

class ConsumerTransactionsPage extends StatefulWidget {
  const ConsumerTransactionsPage({super.key, required this.controller});

  final ConsumerController controller;

  @override
  State<ConsumerTransactionsPage> createState() =>
      _ConsumerTransactionsPageState();
}

class _ConsumerTransactionsPageState extends State<ConsumerTransactionsPage> {
  late Future<List<ConsumerTransactionSummary>> _transactionsFuture;

  @override
  void initState() {
    super.initState();
    _transactionsFuture = widget.controller.loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: FutureBuilder<List<ConsumerTransactionSummary>>(
        future: _transactionsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final transactions = snapshot.data!;
          final totalVolume = transactions.fold<double>(
            0,
            (sum, item) => sum + item.totalAmount,
          );
          final completed = transactions
              .where((item) => item.transactionStatus == 'completed')
              .length;
          final inProgress = transactions
              .where((item) => item.transactionStatus != 'completed')
              .length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              const ResPageHeader(
                eyebrow: 'Financial overview',
                title: 'Transactions',
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _VaultMetricCard(
                      icon: ResIcons.wallet,
                      title: 'Volume',
                      value: formatXaf(totalVolume),
                      tint: ResColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _VaultMetricCard(
                      icon: ResIcons.receipt,
                      title: 'Closed',
                      value: '$completed',
                      tint: ResColors.tertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const ResSectionHeader(title: 'File history'),
              const SizedBox(height: 12),
              if (transactions.isEmpty)
                ResSurfaceCard(
                  radius: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No active files yet',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Opened files will appear here.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                )
              else
                ...transactions.map(
                  (transaction) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _HistoryCard(
                      transaction: transaction,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ConsumerTransactionDetailPage(
                            controller: widget.controller,
                            transactionId: transaction.uuid,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (inProgress > 0) ...[
                const SizedBox(height: 12),
                Text(
                  '$inProgress still need attention.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ResColors.mutedForeground,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _VaultMetricCard extends StatelessWidget {
  const _VaultMetricCard({
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
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: tint, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: ResColors.primary),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.transaction, required this.onTap});

  final ConsumerTransactionSummary transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(transaction.transactionStatus);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: ResSurfaceCard(
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
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            transaction.transactionNumber,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        ResInfoChip(
                          label: startCase(transaction.transactionStatus),
                          color: statusColor,
                          icon: ResIcons.receipt,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      transaction.createdAt == null
                          ? 'Date unavailable'
                          : _formatDate(transaction.createdAt!),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatXaf(transaction.totalAmount),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: ResColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.chevron_right_rounded,
                color: ResColors.softForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'completed':
      return ResColors.secondary;
    case 'cancelled':
    case 'disputed':
      return ResColors.destructive;
    default:
      return ResColors.tertiary;
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
