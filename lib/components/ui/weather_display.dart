import 'package:flutter/material.dart';
import 'package:lovenest_valley/models/mood_weather_model.dart';

class WeatherDisplay extends StatelessWidget {
  final WeatherType weatherType;
  final VoidCallback? onTap;

  const WeatherDisplay({
    super.key,
    required this.weatherType,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Weather Icon
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _getWeatherColor().withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _getWeatherEmoji(),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Weather Text
            Text(
              MoodWeatherMapping.getWeatherDisplayName(weatherType),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getWeatherEmoji() {
    switch (weatherType) {
      case WeatherType.sunny:
        return '☀️';
      case WeatherType.rainy:
        return '🌧️';
      case WeatherType.cloudy:
        return '☁️';
      case WeatherType.stormy:
        return '⛈️';
      case WeatherType.foggy:
        return '🌫️';
      case WeatherType.clearNight:
        return '🌙';
    }
  }

  Color _getWeatherColor() {
    switch (weatherType) {
      case WeatherType.sunny:
        return Colors.orange;
      case WeatherType.rainy:
        return Colors.blue;
      case WeatherType.cloudy:
        return Colors.grey;
      case WeatherType.stormy:
        return Colors.purple;
      case WeatherType.foggy:
        return Colors.grey.shade400;
      case WeatherType.clearNight:
        return Colors.indigo;
    }
  }
}

class WeatherInfoDialog extends StatelessWidget {
  final WeatherType weatherType;
  final String moodCombination;

  const WeatherInfoDialog({
    super.key,
    required this.weatherType,
    required this.moodCombination,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Text(
            _getWeatherEmoji(),
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  MoodWeatherMapping.getWeatherDisplayName(weatherType),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Today\'s Weather',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            MoodWeatherMapping.getWeatherDescription(weatherType),
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.pink.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.pink.shade200,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mood Combination',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.pink.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatMoodCombination(moodCombination),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.pink.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  String _getWeatherEmoji() {
    switch (weatherType) {
      case WeatherType.sunny:
        return '☀️';
      case WeatherType.rainy:
        return '🌧️';
      case WeatherType.cloudy:
        return '☁️';
      case WeatherType.stormy:
        return '⛈️';
      case WeatherType.foggy:
        return '🌫️';
      case WeatherType.clearNight:
        return '🌙';
    }
  }

  String _formatMoodCombination(String combination) {
    final moods = combination.split('_');
    if (moods.length == 2) {
      final mood1 = MoodType.values.firstWhere(
        (e) => e.name == moods[0],
        orElse: () => MoodType.happy,
      );
      final mood2 = MoodType.values.firstWhere(
        (e) => e.name == moods[1],
        orElse: () => MoodType.happy,
      );
      
      return '${MoodWeatherMapping.getMoodDisplayName(mood1)} + ${MoodWeatherMapping.getMoodDisplayName(mood2)}';
    }
    return combination;
  }
} 
