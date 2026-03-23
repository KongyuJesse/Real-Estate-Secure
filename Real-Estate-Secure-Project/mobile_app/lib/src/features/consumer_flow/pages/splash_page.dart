import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../ui/app_icons.dart';
import '../../../ui/brand.dart';

class ConsumerSplashPage extends StatefulWidget {
  const ConsumerSplashPage({super.key});

  @override
  State<ConsumerSplashPage> createState() => _ConsumerSplashPageState();
}

class _ConsumerSplashPageState extends State<ConsumerSplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: ResColors.primary,
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final viewport = MediaQuery.sizeOf(context);
            final padding = MediaQuery.paddingOf(context);
            final oscillation = math.sin(_controller.value * math.pi * 2);
            final progress = 0.28 + (0.54 * _controller.value);

            return Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(gradient: ResGradients.heroPanel),
                ),
                Positioned(
                  top: -viewport.width * 0.24,
                  right: -viewport.width * 0.08,
                  child: _GlowOrb(
                    size: viewport.width * 0.72,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                Positioned(
                  bottom: -viewport.width * 0.42,
                  left: -viewport.width * 0.14,
                  child: _GlowOrb(
                    size: viewport.width * 0.86,
                    color: const Color(0xFF11C7B5).withValues(alpha: 0.20),
                  ),
                ),
                Positioned(
                  top: padding.top + 72 + (oscillation * 10),
                  left: 34,
                  child: _PulseDot(
                    color: Colors.white.withValues(alpha: 0.12),
                    size: 12,
                  ),
                ),
                Positioned(
                  right: 54,
                  bottom: padding.bottom + 156 - (oscillation * 12),
                  child: _PulseDot(
                    color: const Color(0xFFFFE16D).withValues(alpha: 0.26),
                    size: 18,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    28,
                    padding.top + 28,
                    28,
                    padding.bottom + 28,
                  ),
                  child: Column(
                    children: [
                      const Spacer(flex: 7),
                      Transform.translate(
                        offset: Offset(0, oscillation * 8),
                        child: Container(
                          width: 112,
                          height: 112,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.11),
                            borderRadius: BorderRadius.circular(34),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 30,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: const Icon(
                            ResIcons.secure,
                            size: 46,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Real Estate Secure',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _statusLabel(_controller.value),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Colors.white.withValues(alpha: 0.72),
                              letterSpacing: 2.2,
                            ),
                      ),
                      const SizedBox(height: 28),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 7,
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFFFE16D),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Preparing your secure workspace',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.68),
                        ),
                      ),
                      const Spacer(flex: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
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
                              color: Color(0xFFFFE16D),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Powered by Secure Escrow',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
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
          },
        ),
      ),
    );
  }

  String _statusLabel(double value) {
    if (value < 0.33) {
      return 'AUTHENTICATING';
    }
    if (value < 0.66) {
      return 'RESTORING SESSION';
    }
    return 'SECURING ACCESS';
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _PulseDot extends StatelessWidget {
  const _PulseDot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
