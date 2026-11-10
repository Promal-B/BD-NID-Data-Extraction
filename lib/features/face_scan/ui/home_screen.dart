import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/face_extraction_service.dart';
import '../services/face_liveness_service.dart';
import '../services/face_verification_service.dart';
import 'face_scan_screen.dart';
import 'verification_result_screen.dart';

enum _RefStatus { none, validating, valid, invalid }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.service});

  final FaceVerificationService service;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _picker = ImagePicker();

  // Kept in memory only.
  Uint8List? _sourceBytes; // the selected gallery image (upright)
  Uint8List? _faceBytes; // extracted face = matching reference
  _RefStatus _status = _RefStatus.none;
  String _message = '';
  bool _comparing = false;

  Future<void> _pickPhoto() async {
    final XFile? file;
    try {
      file = await _picker.pickImage(source: ImageSource.gallery);
    } catch (e) {
      _snack('Could not open the gallery: $e');
      return;
    }
    if (file == null) return;

    setState(() {
      _status = _RefStatus.validating;
      _message = 'Detecting face…';
      _sourceBytes = null;
      _faceBytes = null;
    });

    final raw = await file.readAsBytes();
    try {
      await File(file.path).delete(); // drop the picker's temporary copy
    } catch (_) {}

    final FaceExtractionResult result = await widget.service.prepareReference(
      raw,
    );
    if (!mounted) return;
    setState(() {
      _sourceBytes = result.sourceJpeg;
      _faceBytes = result.faceJpeg;
      _status = result.isSuccess ? _RefStatus.valid : _RefStatus.invalid;
      _message = result.message;
    });
  }

  Future<void> _startVerification() async {
    final reference = _faceBytes;
    if (reference == null || _status != _RefStatus.valid) return;

    final navigator = Navigator.of(context);
    while (mounted) {
      final liveness = await navigator.push<LivenessOutcome>(
        _fade(const FaceScanScreen()),
      );
      if (liveness == null || !mounted) return; // cancelled

      setState(() => _comparing = true);
      final result = await widget.service.verify(
        referenceFaceJpeg: reference,
        liveness: liveness,
      );
      if (!mounted) return;
      setState(() => _comparing = false);

      final retry = await navigator.push<bool>(
        _fade(VerificationResultScreen(result: result)),
      );
      if (retry != true) {
        if (mounted) {
          setState(() {
            _sourceBytes = null; // clear biometric data when finished
            _faceBytes = null;
            _status = _RefStatus.none;
          });
        }
        return;
      }
    }
  }

  PageRoute<T> _fade<T>(Widget page) => PageRouteBuilder<T>(
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
    transitionDuration: const Duration(milliseconds: 300),
  );

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busy = _status == _RefStatus.validating;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 48,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.verified_user_rounded,
                              color: scheme.onPrimary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Face Verification',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Verify it’s really you',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose a photo or ID card image. The face is detected and cropped automatically, '
                        'then matched against a live scan. Everything stays on this device.',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: Colors.black54, height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      _ReferenceCard(
                        source: _sourceBytes,
                        face: _faceBytes,
                        status: _status,
                        message: _message,
                        onTap: busy ? null : _pickPhoto,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: busy ? null : _pickPhoto,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(
                          _status == _RefStatus.none
                              ? 'Select from gallery'
                              : 'Choose another photo',
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _status == _RefStatus.valid
                            ? _startVerification
                            : null,
                        icon: const Icon(Icons.face_unlock_outlined),
                        label: const Text('Start Verification'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_comparing)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Comparing faces…'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReferenceCard extends StatelessWidget {
  const _ReferenceCard({
    required this.source,
    required this.face,
    required this.status,
    required this.message,
    required this.onTap,
  });

  final Uint8List? source;
  final Uint8List? face;
  final _RefStatus status;
  final String message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      _RefStatus.valid => (const Color(0xFF16A34A), Icons.check_circle_rounded),
      _RefStatus.invalid => (const Color(0xFFDC2626), Icons.error_rounded),
      _RefStatus.validating => (Colors.blueGrey, Icons.hourglass_top_rounded),
      _RefStatus.none => (Colors.black45, Icons.info_outline_rounded),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: status == _RefStatus.none
              ? Colors.black12
              : color.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            child: AspectRatio(
              aspectRatio: 1.1,
              child: source == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 56,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 8),
                        const Text('Tap to select a photo or ID image'),
                      ],
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(
                          color: const Color(0xFFF1F3F8),
                          child: Image.memory(
                            source!,
                            fit: BoxFit.contain,
                            cacheWidth: 1200,
                            gaplessPlayback: true,
                          ),
                        ),
                        if (face != null)
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFF16A34A),
                                  width: 3,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.memory(
                                face!,
                                fit: BoxFit.cover,
                                cacheWidth: 300,
                                gaplessPlayback: true,
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                if (status == _RefStatus.validating)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(icon, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    status == _RefStatus.none
                        ? 'No reference selected'
                        : message,
                    style: TextStyle(color: color, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
