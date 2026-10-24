import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../domain/stats.dart';
import 'theme.dart';

/// Dark grade tile used in lists and headers.
class GradeBadge extends StatelessWidget {
  const GradeBadge(this.grade, {super.key, this.size = 44});

  final String grade;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 1.2,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        grade,
        style: TextStyle(
          color: AppColors.ground,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Small pill naming an ascent style; sends are tinted with the accent.
class StylePill extends StatelessWidget {
  const StylePill(this.style, {super.key});

  final AscentStyle style;

  @override
  Widget build(BuildContext context) {
    final send = isSend(style);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: send ? AppColors.accentTint : AppColors.chip,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        styleLabel(style),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: send ? AppColors.accent : const Color(0xFF3D423F),
        ),
      ),
    );
  }
}

/// Shown at the top of every screen in the demo build.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.ink,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: const Text(
        'Demo · sample data, nothing is saved after reload',
        textAlign: TextAlign.center,
        style: TextStyle(
            color: AppColors.ground, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Uppercase section label.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppColors.quiet,
      ),
    );
  }
}
