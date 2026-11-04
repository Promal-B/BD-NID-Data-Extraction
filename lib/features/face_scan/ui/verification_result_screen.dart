import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/face_verification_result.dart';

/// Pops `true` when the user taps "Try Again", otherwise `false`.
class VerificationResultScreen extends StatelessWidget {
  const VerificationResultScreen({super.key, required this.result});

  final FaceVerificationResult result;

  (Color, IconData, String) get _headline => switch (result.outcome) {
    VerificationOutcome.verified => (
      const Color(0xFF16A34A),
      Icons.verified_rounded,
      'Identity verified',
    ),
    VerificationOutcome.mismatch => (
      const Color(0xFFDC2626),
      Icons.person_off_rounded,
      'Face does not match',
    ),
    VerificationOutcome.livenessFailed => (
      const Color(0xFFDC2626),
      Icons.gpp_bad_rounded,
      'Liveness failed',
    ),
    VerificationOutcome.referenceInvalid => (
      const Color(0xFFD97706),
      Icons.image_not_supported_rounded,
      'Reference photo invalid',
    ),
    VerificationOutcome.error => (
      const Color(0xFFD97706),
      Icons.error_outline_rounded,
      'Processing error',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (color, icon, title) = _headline;
    final matchText = switch (result.outcome) {
      VerificationOutcome.verified => 'Matched',
      VerificationOutcome.mismatch => 'Not matched',
      _ => 'Not performed',
    };

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.6, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                  builder: (_, s, child) =>
                      Transform.scale(scale: s, child: child),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 64, color: color),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800, color: color),
              ),
              const SizedBox(height: 6),
              Text(
                result.message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _Photo(
                      label: 'Reference',
                      bytes: result.referenceJpeg,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Photo(
                      label: 'Live capture',
                      bytes: result.liveJpeg,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      _Row(
                        label: 'Liveness',
                        value: result.livenessPassed ? 'Passed' : 'Failed',
                        good: result.livenessPassed,
                      ),
                      if (result.passiveScore != null) ...[
                        const Divider(height: 1),
                        _Row(
                          label: 'Active / passive score',
                          value:
                              '${(result.activeScore ?? 0).toStringAsFixed(2)} / ${result.passiveScore!.toStringAsFixed(2)}',
                          neutral: true,
                        ),
                      ],
                      const Divider(height: 1),
                      _Row(
                        label: 'Face match',
                        value: matchText,
                        good: result.matched,
                        neutral: matchText == 'Not performed',
                      ),
                      const Divider(height: 1),
                      _Row(
                        label: 'Similarity',
                        value: result.similarity == null
                            ? '—'
                            : '${result.similarity!.toStringAsFixed(3)}  (threshold ${result.threshold!.toStringAsFixed(2)})',
                        neutral: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.label, required this.bytes});

  final String label;
  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 0.8,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: bytes == null
                ? const ColoredBox(
                    color: Color(0xFFE5E7EB),
                    child: Center(
                      child: Icon(
                        Icons.no_photography_outlined,
                        color: Colors.black38,
                        size: 36,
                      ),
                    ),
                  )
                : Image.memory(
                    bytes!,
                    fit: BoxFit.cover,
                    cacheWidth: 600,
                    gaplessPlayback: true,
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.good = false,
    this.neutral = false,
  });

  final String label;
  final String value;
  final bool good;
  final bool neutral;

  @override
  Widget build(BuildContext context) {
    final color = neutral
        ? Colors.black87
        : (good ? const Color(0xFF16A34A) : const Color(0xFFDC2626));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
