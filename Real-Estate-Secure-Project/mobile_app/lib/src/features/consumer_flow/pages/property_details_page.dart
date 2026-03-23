import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../consumer_controller.dart';
import '../consumer_models.dart';
import '../widgets/guest_access_sheet.dart';
import '../../../ui/app_icons.dart';
import '../../../ui/brand.dart';
import '../../../ui/components/buttons.dart';
import '../../../ui/components/cards.dart';
import '../../../ui/components/location_map.dart';
import '../../../ui/components/page_sections.dart';
import '../../../ui/components/property_gallery.dart';

class ConsumerPropertyDetailsPage extends StatefulWidget {
  const ConsumerPropertyDetailsPage({
    super.key,
    required this.controller,
    required this.propertyId,
  });

  final ConsumerController controller;
  final String propertyId;

  @override
  State<ConsumerPropertyDetailsPage> createState() =>
      _ConsumerPropertyDetailsPageState();
}

class _ConsumerPropertyDetailsPageState
    extends State<ConsumerPropertyDetailsPage> {
  bool _isSavingFavorite = false;
  bool _isStartingTransaction = false;
  late final Future<
    (
      ConsumerPropertyDetail,
      List<ConsumerPropertyDocument>,
      List<ConsumerPropertyImage>,
    )
  >
  _bundleFuture;

  @override
  void initState() {
    super.initState();
    _bundleFuture = _loadBundle();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
      (
        ConsumerPropertyDetail,
        List<ConsumerPropertyDocument>,
        List<ConsumerPropertyImage>,
      )
    >(
      future: _bundleFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Property details')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      size: 42,
                      color: ResColors.mutedForeground,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'We could not load this property right now.',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check your connection and try again from the marketplace.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ResColors.mutedForeground,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final detail = snapshot.data!.$1;
        final documents = snapshot.data!.$2;
        final images = snapshot.data!.$3;
        final locationLabel =
            detail.location != null && detail.location!.label.isNotEmpty
            ? detail.location!.label
            : 'Exact location shared after a secure viewing request.';
        final isSaved = widget.controller.isPropertySaved(detail.id);
        final trustChips = _trustSignalChips(detail);

        return Scaffold(
          extendBody: true,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 360,
                pinned: true,
                backgroundColor: ResColors.foreground,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ResCircleIconButton(
                    icon: ResIcons.back,
                    backgroundColor: Colors.black.withValues(alpha: 0.24),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                actions: [
                  ResCircleIconButton(
                    icon: ResIcons.share,
                    backgroundColor: Colors.black.withValues(alpha: 0.24),
                    foregroundColor: Colors.white,
                    onPressed: () =>
                        _copyPropertySummary(detail, locationLabel),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: ResCircleIconButton(
                      icon: isSaved
                          ? Icons.favorite_rounded
                          : ResIcons.favorite,
                      backgroundColor: Colors.black.withValues(alpha: 0.24),
                      foregroundColor: Colors.white,
                      onPressed: _isSavingFavorite
                          ? null
                          : () => _toggleSaved(detail.id, !isSaved),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    children: [
                      Positioned.fill(
                        child: ResPropertyGallery(
                          images: images,
                          propertyType: detail.propertyType,
                          title: detail.title,
                          height: 360,
                        ),
                      ),
                      Positioned(
                        top: 106,
                        left: 20,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ResInfoChip(
                              label: detail.isFeatured
                                  ? 'Featured'
                                  : 'Verified file',
                              color: detail.isFeatured
                                  ? ResColors.accent
                                  : ResColors.secondary,
                              icon: detail.isFeatured
                                  ? ResIcons.crown
                                  : Icons.verified_rounded,
                            ),
                            ResInfoChip(
                              label: startCase(detail.listingType),
                              color: Colors.white,
                              icon: ResIcons.listingType(detail.listingType),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 18,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            images.isEmpty ? 3 : images.length.clamp(1, 4),
                            (index) => Container(
                              width: index == 0 ? 24 : 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(
                                  alpha: index == 0 ? 1 : 0.4,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -20),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: ResColors.background,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 140),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              ResIcons.location,
                              size: 18,
                              color: ResColors.mutedForeground,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                locationLabel,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: ResColors.mutedForeground,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                formatXaf(detail.price),
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(color: ResColors.primary),
                              ),
                            ),
                            ResInfoChip(
                              label: startCase(detail.verificationStatus),
                              color: ResColors.secondary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            ResMetricCard(
                              icon: ResIcons.propertyType(detail.propertyType),
                              value: startCase(detail.propertyType),
                              caption: 'Asset type',
                            ),
                            const SizedBox(width: 10),
                            ResMetricCard(
                              icon: ResIcons.listingType(detail.listingType),
                              value: startCase(detail.listingType),
                              caption: 'Listing mode',
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        ResSurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const ResSectionHeader(title: 'Price breakdown'),
                              const SizedBox(height: 14),
                              _priceRow(
                                context,
                                'Asking',
                                formatXaf(detail.price),
                              ),
                              _priceRow(context, 'Platform', 'Included'),
                              _priceRow(context, 'Notary', 'Varies'),
                              const SizedBox(height: 12),
                              _priceRow(
                                context,
                                'Estimate',
                                formatXaf(detail.price),
                                emphasized: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        ResSurfaceCard(
                          child: Row(
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  color: ResColors.muted,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  ResIcons.profile,
                                  color: ResColors.primary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      detail.ownerName?.trim().isNotEmpty ==
                                              true
                                          ? detail.ownerName!
                                          : 'Verified seller',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    const ResInfoChip(
                                      label: 'Seller ready',
                                      color: ResColors.secondary,
                                      icon: ResIcons.profile,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: ResColors.primary.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  ResIcons.phone,
                                  color: ResColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        ResSurfaceCard(
                          color: ResColors.muted,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const ResSectionHeader(title: 'Trust signals'),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: trustChips,
                              ),
                              if (trustChips.length <= 2) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Key review signals are attached to this file.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: ResColors.mutedForeground,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        ResSurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Closing lane',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ),
                                  ResInfoChip(
                                    label: _closingLaneLabel(detail),
                                    color: _isAssistedLane(detail)
                                        ? ResColors.accent
                                        : ResColors.secondary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _closingPathSummary(detail),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: ResColors.mutedForeground,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        ResSurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const ResSectionHeader(title: 'Overview'),
                              const SizedBox(height: 12),
                              Text(
                                detail.description,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: ResColors.mutedForeground,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        ResSurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const ResSectionHeader(title: 'Location'),
                              const SizedBox(height: 14),
                              ResStaticLocationMap(
                                latitude: detail.location?.latitude,
                                longitude: detail.location?.longitude,
                                title: detail.title,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                locationLabel,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: ResColors.mutedForeground,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        ResSurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const ResSectionHeader(
                                title: 'Verified documents',
                              ),
                              const SizedBox(height: 12),
                              if (documents.isEmpty)
                                Text(
                                  'No public document previews yet.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: ResColors.mutedForeground,
                                      ),
                                )
                              else
                                ...documents
                                    .take(4)
                                    .map(
                                      (document) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: ResColors.muted,
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 44,
                                                height: 44,
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                                child: const Icon(
                                                  Icons.description_outlined,
                                                  color: ResColors.primary,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      document.documentTitle,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.w800,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      document.documentNumber,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: ResColors
                                                                .mutedForeground,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              ResInfoChip(
                                                label: document.isVerified
                                                    ? 'Verified'
                                                    : 'Pending',
                                                color: document.isVerified
                                                    ? ResColors.secondary
                                                    : ResColors.info,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: const BoxDecoration(
                color: ResColors.card,
                boxShadow: [
                  BoxShadow(
                    color: Color.fromRGBO(25, 28, 32, 0.05),
                    blurRadius: 22,
                    offset: Offset(0, -8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ResOutlineButton(
                      label: 'Review evidence',
                      icon: Icons.description_outlined,
                      onPressed: () => _showDocumentsSheet(documents),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ResPrimaryButton(
                      label: _isStartingTransaction
                          ? 'Opening file...'
                          : 'Open secure file',
                      icon: ResIcons.secure,
                      isBusy: _isStartingTransaction,
                      onPressed: () => _startTransaction(detail),
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

  Future<
    (
      ConsumerPropertyDetail,
      List<ConsumerPropertyDocument>,
      List<ConsumerPropertyImage>,
    )
  >
  _loadBundle() async {
    final detail = await widget.controller.loadPropertyDetail(
      widget.propertyId,
    );
    final documents = await widget.controller.loadPropertyDocuments(
      widget.propertyId,
    );
    final images = await widget.controller.loadPropertyImages(
      widget.propertyId,
    );
    return (detail, documents, images);
  }

  Future<void> _toggleSaved(String propertyId, bool shouldSave) async {
    final allowed = await ensureConsumerAuthenticatedAccess(
      context,
      controller: widget.controller,
      title: 'Save this property to your shortlist',
      message:
          'Sign in or register to keep shortlisted properties synced across your secure workspace.',
    );
    if (!allowed || !mounted) {
      return;
    }

    setState(() => _isSavingFavorite = true);
    try {
      await widget.controller.setFavoriteStatus(
        propertyId: propertyId,
        isFavorite: shouldSave,
      );
      if (mounted) {
        setState(() {});
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingFavorite = false);
      }
    }
  }

  Future<void> _copyPropertySummary(
    ConsumerPropertyDetail detail,
    String locationLabel,
  ) async {
    final summary = StringBuffer()
      ..writeln(detail.title)
      ..writeln(locationLabel)
      ..writeln('Price: ${formatXaf(detail.price)}')
      ..writeln(
        'Type: ${startCase(detail.propertyType)} • ${startCase(detail.listingType)}',
      )
      ..writeln('Trust: ${startCase(detail.verificationStatus)}');

    await Clipboard.setData(ClipboardData(text: summary.toString().trim()));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Property summary copied.')));
  }

  Future<void> _showDocumentsSheet(
    List<ConsumerPropertyDocument> documents,
  ) async {
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Property documents',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (documents.isEmpty)
                ResSurfaceCard(
                  child: Text(
                    'No public preview documents are available yet.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ResColors.mutedForeground,
                    ),
                  ),
                )
              else
                ...documents
                    .take(6)
                    .map(
                      (document) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ResMenuTile(
                          icon: Icons.description_outlined,
                          title: document.documentTitle,
                          subtitle: document.documentNumber,
                          trailingLabel: document.isVerified
                              ? 'Verified'
                              : 'Pending',
                          tint: document.isVerified
                              ? ResColors.secondary
                              : ResColors.info,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startTransaction(ConsumerPropertyDetail detail) async {
    final allowed = await ensureConsumerAuthenticatedAccess(
      context,
      controller: widget.controller,
      title: 'Open a secure transaction file',
      message:
          'Sign in or register before opening escrow-backed transaction work for this property.',
    );
    if (!allowed || !mounted) {
      return;
    }
    if ((detail.ownerUuid ?? '').isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This listing does not yet have a ready seller profile for transactions.',
          ),
        ),
      );
      return;
    }

    setState(() => _isStartingTransaction = true);
    try {
      final transaction = await widget.controller.initiateTransaction(
        propertyId: detail.id,
        sellerId: detail.ownerUuid!,
        transactionType: detail.listingType == 'rent'
            ? 'rent'
            : detail.listingType == 'lease'
            ? 'lease'
            : 'sale',
        propertyPrice: detail.price,
      );
      await widget.controller.refreshMarketplace();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Secure file ${transaction.transactionNumber} has been opened.',
          ),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isStartingTransaction = false);
      }
    }
  }

  Widget _priceRow(
    BuildContext context,
    String label,
    String value, {
    bool emphasized = false,
  }) {
    final style = emphasized
        ? Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: ResColors.primary,
            fontWeight: FontWeight.w800,
          )
        : Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
          Text(value, style: style),
        ],
      ),
    );
  }

  bool _isAssistedLane(ConsumerPropertyDetail detail) {
    return detail.foreignPartyExpected ||
        detail.oldTitleRisk ||
        detail.courtLinked ||
        detail.declaredDispute ||
        detail.declaredEncumbrance ||
        detail.ministryFilingRequired ||
        detail.municipalCertificateRequired;
  }

  String _closingPathSummary(ConsumerPropertyDetail detail) {
    if (_isAssistedLane(detail)) {
      return 'Extra legal, municipal, or dispute review is likely before closing.';
    }
    return 'This file looks ready for the standard secure close lane.';
  }

  String _closingLaneLabel(ConsumerPropertyDetail detail) {
    return _isAssistedLane(detail) ? 'Assisted close' : 'Standard close';
  }

  List<Widget> _trustSignalChips(ConsumerPropertyDetail detail) {
    final chips = <Widget>[
      if (detail.riskLane != null)
        ResInfoChip(
          label: startCase(detail.riskLane!),
          color: ResColors.primary,
        ),
      if (detail.admissionStatus != null)
        ResInfoChip(
          label: startCase(detail.admissionStatus!),
          color: ResColors.info,
        ),
      if (detail.sellerIdentityVerifiedSnapshot)
        const ResInfoChip(label: 'ID checked', color: ResColors.secondary),
      if (detail.foreignPartyExpected)
        const ResInfoChip(label: 'Foreign party', color: ResColors.accent),
      if (detail.municipalCertificateRequired)
        const ResInfoChip(label: 'Municipal cert', color: ResColors.tertiary),
      if (detail.ministryFilingRequired)
        const ResInfoChip(label: 'Ministry filing', color: ResColors.tertiary),
      if (detail.declaredEncumbrance)
        const ResInfoChip(label: 'Encumbrance', color: ResColors.info),
      if (detail.courtLinked || detail.declaredDispute)
        const ResInfoChip(label: 'Dispute watch', color: ResColors.destructive),
      if (detail.oldTitleRisk)
        const ResInfoChip(label: 'Legacy title', color: ResColors.accent),
    ];
    if (chips.isEmpty) {
      return const [
        ResInfoChip(label: 'Standard checks', color: ResColors.secondary),
      ];
    }
    return chips;
  }
}
