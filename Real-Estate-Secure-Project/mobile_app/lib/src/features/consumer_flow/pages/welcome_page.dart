import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../ui/app_icons.dart';
import '../../../ui/brand.dart';
import '../../../ui/components/buttons.dart';

class ConsumerWelcomePage extends StatelessWidget {
  const ConsumerWelcomePage({
    super.key,
    required this.onRegister,
    required this.onLogin,
    required this.onExploreGuest,
  });

  final VoidCallback onRegister;
  final VoidCallback onLogin;
  final VoidCallback onExploreGuest;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?auto=format&fit=crop&w=1400&q=80',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
              errorBuilder: (_, _, _) => const DecoratedBox(
                decoration: BoxDecoration(gradient: ResGradients.heroPanel),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(gradient: ResGradients.darkHeroOverlay),
            ),
            Positioned(
              top: -120,
              right: -80,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -140,
              left: -80,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  color: const Color(0xFF11C7B5).withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final heroSpacing = (constraints.maxHeight * 0.15)
                      .clamp(28.0, 108.0)
                      .toDouble();
                  return SingleChildScrollView(
                    padding: EdgeInsets.zero,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.08,
                                      ),
                                    ),
                                  ),
                                  child: const Icon(
                                    ResIcons.secure,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Real Estate Secure',
                                  style: textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: heroSpacing),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    ResIcons.trust,
                                    size: 16,
                                    color: Color(0xFFFFE16D),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'SECURE DISCOVERY',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Secure property transactions built for Cameroon.',
                              style: textTheme.headlineLarge?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 14),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 360),
                              child: Text(
                                'Discover verified listings, complete trust checks, and move into escrow-backed transactions in one mobile workspace.',
                                style: textTheme.bodyLarge?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.80),
                                ),
                              ),
                            ),
                            const SizedBox(height: 26),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: const [
                                _HeroPill(
                                  icon: ResIcons.secure,
                                  label: 'Verified escrow',
                                ),
                                _HeroPill(
                                  icon: ResIcons.trust,
                                  label: 'Live KYC ready',
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            ResPrimaryButton(
                              label: 'Login',
                              icon: ResIcons.arrowRight,
                              isPill: true,
                              onPressed: onLogin,
                            ),
                            const SizedBox(height: 12),
                            ResOutlineButton(
                              label: 'Register',
                              isPill: true,
                              onPressed: onRegister,
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: ResGhostButton(
                                label: 'Explore as Guest',
                                onPressed: onExploreGuest,
                              ),
                            ),
                            SizedBox(height: heroSpacing * 0.45),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFFFE16D)),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
