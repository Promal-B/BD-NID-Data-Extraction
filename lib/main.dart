import 'package:flutter/material.dart';

import 'features/face_scan/services/face_verification_service.dart';
import 'features/face_scan/ui/home_screen.dart';
import 'features/id_scan/ui/scan_screen.dart';
import 'features/weather_open_meteo/ui/weather_screen.dart';

void main() => runApp(const KycApp());

class _Feature {
  const _Feature({
    required this.title,
    required this.description,
    required this.icon,
    required this.builder,
  });

  final String title;
  final String description;
  final IconData icon;
  final WidgetBuilder builder;
}

class KycApp extends StatelessWidget {
  const KycApp({super.key});

  static final _features = <_Feature>[
    _Feature(
      title: 'ID Scan',
      description: 'Extract identity details from an ID card',
      icon: Icons.badge_outlined,
      builder: (_) => const ScanScreen(),
    ),
    _Feature(
      title: 'Face Verification',
      description: 'Verify a face with liveness detection',
      icon: Icons.face_retouching_natural,
      builder: (_) => HomeScreen(service: FaceVerificationService()),
    ),
    _Feature(
      title: 'Weather',
      description: 'Check current weather by location',
      icon: Icons.wb_sunny_outlined,
      builder: (_) => const WeatherScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KYC App',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const FeatureListScreen(),
    );
  }
}

class FeatureListScreen extends StatelessWidget {
  const FeatureListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Features')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: KycApp._features.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final feature = KycApp._features[index];
          return Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(child: Icon(feature.icon)),
              title: Text(feature.title),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(feature.description),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: feature.builder)),
            ),
          );
        },
      ),
    );
  }
}
