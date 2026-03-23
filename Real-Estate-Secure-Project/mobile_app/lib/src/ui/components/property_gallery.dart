import 'package:flutter/material.dart';

import '../../features/consumer_flow/consumer_models.dart';
import '../app_icons.dart';
import '../brand.dart';
import 'property_media.dart';

class ResPropertyGallery extends StatefulWidget {
  const ResPropertyGallery({
    super.key,
    required this.images,
    required this.propertyType,
    required this.title,
    this.height = 340,
  });

  final List<ConsumerPropertyImage> images;
  final String propertyType;
  final String title;
  final double height;

  @override
  State<ResPropertyGallery> createState() => _ResPropertyGalleryState();
}

class _ResPropertyGalleryState extends State<ResPropertyGallery> {
  late final PageController _pageController;
  int _currentPage = 0;

  List<ConsumerPropertyImage> get _sortedImages {
    final cloned = [...widget.images];
    cloned.sort((left, right) {
      if (left.isPrimary != right.isPrimary) {
        return left.isPrimary ? -1 : 1;
      }
      return left.sortOrder.compareTo(right.sortOrder);
    });
    return cloned;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = _sortedImages;

    if (images.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: SizedBox(
          height: widget.height,
          child: ResPropertyMedia(
            propertyType: widget.propertyType,
            title: widget.title,
            borderRadius: BorderRadius.circular(30),
            showLabel: false,
          ),
        ),
      );
    }

    final selected = images[_currentPage.clamp(0, images.length - 1)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: SizedBox(
            height: widget.height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: images.length,
                    onPageChanged: (value) {
                      setState(() => _currentPage = value);
                    },
                    itemBuilder: (context, index) {
                      final image = images[index];
                      return ResPropertyMedia(
                        propertyType: widget.propertyType,
                        title: image.title ?? widget.title,
                        imageUrl: image.filePathOriginal,
                        borderRadius: BorderRadius.circular(30),
                        showLabel: false,
                      );
                    },
                  ),
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x7A000000),
                          Colors.transparent,
                          Color(0xB8000000),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          ResIcons.photo,
                          size: 16,
                          color: ResColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_currentPage + 1} / ${images.length}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
                if ((selected.title ?? '').trim().isNotEmpty)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 18,
                    child: Text(
                      selected.title!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final image = images[index];
                final isSelected = index == _currentPage;
                return GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 96,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? ResColors.primary
                            : ResColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected ? ResShadows.card : const [],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ResPropertyMedia(
                      propertyType: widget.propertyType,
                      title: image.title ?? widget.title,
                      imageUrl: image.filePathOriginal,
                      borderRadius: BorderRadius.circular(20),
                      showLabel: false,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
