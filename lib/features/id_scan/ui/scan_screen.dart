import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/extracted_id.dart';
import '../services/extraction_pipeline.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _pipeline = ExtractionPipeline();
  final _picker = ImagePicker();

  File? _image;
  ExtractedId? _result;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pipeline.dispose();
    super.dispose();
  }

  Future<void> _scan(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 95);
    if (picked == null) return;

    setState(() {
      _busy = true;
      _error = null;
      _result = null;
      _image = File(picked.path);
    });

    try {
      final result = await _pipeline.run(picked.path);
      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = 'Extraction failed. Try a sharper photo.');
    } finally {
      setState(() => _busy = false);
    }
  }

  String _fmt(Object v) => v is DateTime
      ? '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}'
      : v.toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan ID')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _scan(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _scan(ImageSource.gallery),
                  icon: const Icon(Icons.photo),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_image != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(_image!, height: 200, fit: BoxFit.cover),
            ),
          const SizedBox(height: 16),
          if (_busy) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_result != null) ..._buildResult(_result!),
        ],
      ),
    );
  }

  List<Widget> _buildResult(ExtractedId r) {
    if (r.isEmpty) {
      return [
        const Text(
          'No fields found. Retake the photo (flat card, good light).',
        ),
      ];
    }
    return [
      for (final e in r.fields.entries)
        if (e.value != null)
          ListTile(
            dense: true,
            title: Text(e.key),
            subtitle: Text(_fmt(e.value!.value as Object)),
            trailing: Chip(
              avatar: Icon(
                e.value!.validated ? Icons.verified : Icons.warning_amber,
                size: 16,
              ),
              label: Text(e.value!.source.name.toUpperCase()),
            ),
          ),
    ];
  }
}
