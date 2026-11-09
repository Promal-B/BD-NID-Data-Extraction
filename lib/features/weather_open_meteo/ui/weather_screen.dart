import 'package:flutter/material.dart';
import 'package:open_meteo/open_meteo.dart';

import '../models/weather_result.dart';
import '../services/weather_service.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final _searchController = TextEditingController();
  final _service = WeatherService();
  List<WeatherLocation> _locations = const [];
  WeatherResult? _weather;
  bool _isSearching = false;
  bool _isLoadingWeather = false;
  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _locations = const [];
    });
    try {
      final locations = await _service.searchLocations(query);
      if (!mounted) return;
      setState(() => _locations = locations);
      if (locations.isEmpty) {
        setState(() => _errorMessage = 'No matching locations found.');
      }
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _loadLocation(WeatherLocation location) async {
    setState(() {
      _isLoadingWeather = true;
      _errorMessage = null;
    });
    try {
      final weather = await _service.getWeather(location);
      if (mounted) {
        setState(() {
          _weather = weather;
          _locations = const [];
        });
      }
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isLoadingWeather = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLoadingWeather = true;
      _errorMessage = null;
    });
    try {
      final location = await _service.getCurrentLocation();
      await _loadLocation(location);
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoadingWeather = false;
          _errorMessage = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weather')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Check current weather',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Search for a place or use your device location.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              labelText: 'Location',
              hintText: 'e.g. Dhaka',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      tooltip: 'Search',
                      onPressed: _search,
                      icon: const Icon(Icons.arrow_forward),
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isLoadingWeather ? null : _useCurrentLocation,
            icon: const Icon(Icons.my_location),
            label: const Text('Use current location'),
          ),
          if (_locations.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Choose a location',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ..._locations.map(
              (location) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_on_outlined),
                title: Text(location.name),
                subtitle: Text(
                  '${location.latitude.toStringAsFixed(3)}, '
                  '${location.longitude.toStringAsFixed(3)}',
                ),
                onTap: _isLoadingWeather ? null : () => _loadLocation(location),
              ),
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_isLoadingWeather) ...[
            const SizedBox(height: 32),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_weather case final weather?) ...[
            const SizedBox(height: 24),
            _WeatherCard(weather: weather),
          ],
        ],
      ),
    );
  }
}

class _WeatherCard extends StatelessWidget {
  const _WeatherCard({required this.weather});

  final WeatherResult weather;

  @override
  Widget build(BuildContext context) {
    final currentEntries = weather.currentData.entries.toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              weather.locationName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.cloud, size: 40),
                const SizedBox(width: 12),
                Text(
                  'Current weather',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(
              label: 'Coordinates',
              value:
                  '${weather.latitude.toStringAsFixed(5)}, '
                  '${weather.longitude.toStringAsFixed(5)}',
            ),
            _InfoRow(
              label: 'Elevation',
              value: '${weather.elevation.toStringAsFixed(1)} m',
            ),
            _InfoRow(
              label: 'Timezone',
              value: [
                weather.timezone,
                weather.timezoneAbbreviation,
              ].whereType<String>().join(' '),
            ),
            _InfoRow(
              label: 'UTC offset',
              value: _formatDuration(weather.utcOffset),
            ),
            _InfoRow(label: 'Model', value: weather.model.name),
            const Divider(height: 24),
            Text(
              'Current conditions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...currentEntries.map(
              (entry) => _InfoRow(
                label: _currentLabel(entry.key),
                value:
                    '${_formatValue(entry.key, entry.value.value)} '
                    '${entry.value.unit}',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Updated ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(weather.observedAt))}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(flex: 3, child: Text(value)),
        ],
      ),
    );
  }
}

String _currentLabel(WeatherCurrent variable) {
  return switch (variable) {
    WeatherCurrent.temperature_2m => 'Temperature (2 m)',
    WeatherCurrent.relative_humidity_2m => 'Relative humidity (2 m)',
    WeatherCurrent.apparent_temperature => 'Apparent temperature',
    WeatherCurrent.is_day => 'Daylight',
    WeatherCurrent.precipitation => 'Precipitation',
    WeatherCurrent.rain => 'Rain',
    WeatherCurrent.showers => 'Showers',
    WeatherCurrent.snowfall => 'Snowfall',
    WeatherCurrent.weather_code => 'Weather code',
    WeatherCurrent.cloud_cover => 'Cloud cover',
    WeatherCurrent.pressure_msl => 'Pressure (mean sea level)',
    WeatherCurrent.surface_pressure => 'Surface pressure',
    WeatherCurrent.wind_speed_10m => 'Wind speed (10 m)',
    WeatherCurrent.wind_direction_10m => 'Wind direction (10 m)',
    WeatherCurrent.wind_gusts_10m => 'Wind gusts (10 m)',
  };
}

String _formatValue(WeatherCurrent variable, double value) {
  if (variable == WeatherCurrent.is_day ||
      variable == WeatherCurrent.weather_code) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}

String _formatDuration(Duration duration) {
  final sign = duration.isNegative ? '-' : '+';
  final hours = duration.inHours.abs().toString().padLeft(2, '0');
  final minutes = duration.inMinutes.abs() % 60;
  return '$sign$hours:${minutes.toString().padLeft(2, '0')}';
}
