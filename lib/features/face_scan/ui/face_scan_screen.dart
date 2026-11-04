import 'package:flutter/material.dart';
import 'package:human_security/human_security.dart';

import '../config/verification_config.dart';
import '../services/face_liveness_service.dart';

/// Hosts the package's guided liveness camera (front camera, oval overlay,
/// live instructions, progress, active challenges + passive anti-spoofing).
///
/// Pops with a [LivenessOutcome] (pass or fail) or `null` if cancelled.
/// There is no skip path: the only way to get a passing outcome is for the
/// package to report a verified liveness result.
///
/// NOTE: no `referenceImage` is given here on purpose – identity matching is
/// done afterwards, and only if liveness passed.
class FaceScanScreen extends StatefulWidget {
  const FaceScanScreen({super.key});

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen> {
  bool _done = false;

  void _finish(LivenessOutcome outcome) {
    if (_done || !mounted) return;
    _done = true;
    Navigator.of(context).pop(outcome);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          FaceLivenessDetector(
            challengeCount: VerificationConfig.challengeCount,
            enablePassiveLiveness: true,
            showCameraFlipButton: false,
            backgroundColor: Colors.black,
            progressColor: Colors.greenAccent,
            onSuccess: (file, report) =>
                _finish(FaceLivenessService.fromSuccess(file, report)),
            onFailure: (reason) => _finish(LivenessOutcome.failed(reason)),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                tooltip: 'Cancel',
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () {
                  if (_done) return;
                  _done = true;
                  Navigator.of(context).pop();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
