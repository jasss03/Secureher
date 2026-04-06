import 'dart:ui';
import 'package:flutter/material.dart';

class PastelBackground extends StatelessWidget {
  final Widget child;
  final List<Color> colors;
  const PastelBackground({
    super.key,
    required this.child,
    this.colors = const [
      Color(0xFFEAE6FF), // lavender
      Color(0xFFD5F5F2), // teal
      Color(0xFFFFE6F1), // blush
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
          // soft icon silhouettes
          Positioned(
            top: -60,
            right: -40,
            child: _Bubble(
              size: 220,
              color: Colors.white.withValues(alpha: 0.20),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -40,
            child: _Bubble(
              size: 260,
              color: Colors.white.withValues(alpha: 0.14),
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
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class PillTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final bool obscure;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  const PillTextField({
    super.key,
    required this.controller,
    required this.label,
    this.keyboardType,
    this.obscure = false,
    this.validator,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      textInputAction: textInputAction,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class PrimaryPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  const PrimaryPillButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        shape: const StadiumBorder(),
      ),
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class SegmentedPills extends StatelessWidget {
  final bool leftSelected;
  final String leftLabel;
  final String rightLabel;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  const SegmentedPills({
    super.key,
    required this.leftSelected,
    required this.leftLabel,
    required this.rightLabel,
    required this.onLeft,
    required this.onRight,
  });

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _seg(context, leftLabel, leftSelected, onLeft),
          _seg(context, rightLabel, !leftSelected, onRight),
        ],
      ),
    );
  }

  Widget _seg(
    BuildContext context,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
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
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
