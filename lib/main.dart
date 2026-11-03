import 'package:flutter/material.dart';

import 'features/id_scan/ui/scan_screen.dart';

void main() => runApp(const KycApp());

class KycApp extends StatelessWidget {
  const KycApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KYC App',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const ScanScreen(),
    );
  }
}
