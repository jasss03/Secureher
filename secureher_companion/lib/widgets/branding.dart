import 'dart:ui';

import 'package:flutter/material.dart';

class PastelBackground extends StatelessWidget {
  final Widget child;
  final List<Color> colors;

  const PastelBackground({
    super.key,
    required this.child,
    this.colors = const [
      Color(0xFFEAE6FF),
      Color(0xFFD5F5F2),
      Color(0xFFFFE6F1),
    ],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -70,
            right: -30,
            child: _Bubble(
              size: 220,
              color: Colors.white.withValues(alpha: 0.22),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -40,
            child: _Bubble(
              size: 260,
              color: Colors.white.withValues(alpha: 0.16),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 28,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final double size;
  final Color color;

  const _Bubble({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
